// sync.sv
// ------------------------------------------------------------
// Generic N-stage level synchronizer (N ≥ 2).
// Designed for clean CDC constraints: each stage has predictable
// hierarchical names and optional vendor attributes.
//
// Parameters:
//   int  STAGES         = 2    // synchronization stages (≥2 recommended)
//   bit  RESET_VALUE    = 0    // reset value for all stage flops
//   bit  ASYNC_RESET    = 1    // 1: async reset, 0: sync reset
//   bit  RST_ACTIVE_LOW = 1    // 1: reset is active-low, 0: active-high
//
// Ports:
//   clk_dst   : destination clock
//   rst_dst_n : reset (polarity per RST_ACTIVE_LOW)
//   async_in  : asynchronous input (level)
//   sync_out  : synchronized output (to clk_dst)
// ------------------------------------------------------------
`timescale 1ns/1ps

module sync #(
  parameter int STAGES = 2,
  parameter bit RESET_VALUE = 1'b0,
  parameter bit ASYNC_RESET = 1'b1,
  parameter bit RST_ACTIVE_LOW = 1'b1
)(
  input  logic clk_dst,
  input  logic rst_dst_n,
  input  logic async_in,
  output logic sync_out
);

  // Sanity check
  initial assert (STAGES >= 2)
    else $error("sync: STAGES must be >= 2");

  // Active-high reset (internal)
  wire rst_ah = RST_ACTIVE_LOW ? ~rst_dst_n : rst_dst_n;

  // ----------------------------------------------------------------
  // Stage flops with stable hierarchical names:
  //   g_stage[0].ff_q is the FIRST metastability-catching flop
  //   g_stage[STAGES-1].ff_q drives sync_out
  //
  // CDC attributes (Xilinx/Intel/Generic) are attached per stage.
  // Define one of:
  //   +define+CDC_ATTR_XILINX   -> ASYNC_REG, SHREG_EXTRACT=NO, DONT_TOUCH
  //   +define+CDC_ATTR_INTEL    -> SYNCHRONIZER_IDENTIFICATION, PRESERVE
  //   +define+CDC_ATTR_GENERIC  -> syn_keep/preserve (fallback)
  // ----------------------------------------------------------------
  genvar i;
  logic [STAGES-1:0] stage_d, stage_q;

  // Drive first stage input from async signal; others from previous q
  assign stage_d[0] = async_in;
  generate
    for (i = 1; i < STAGES; i++) begin : g_chain
      assign stage_d[i] = stage_q[i-1];
    end
  endgenerate

  // Flops
  generate
    for (i = 0; i < STAGES; i++) begin : g_stage
      // ---- Attribute macros per-tool ----
      `ifdef CDC_ATTR_XILINX
        (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO", DONT_TOUCH = "TRUE" *)
      `elsif CDC_ATTR_INTEL
        (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED; -name PRESERVE_REGISTER ON" *)
      `elsif CDC_ATTR_GENERIC
        (* syn_keep = 1, preserve = 1 *)
      `endif
      logic ff_q;

      if (ASYNC_RESET) begin : g_async
        always_ff @(posedge clk_dst or posedge rst_ah) begin
          if (rst_ah) ff_q <= RESET_VALUE;
          else        ff_q <= stage_d[i];
        end
      end else begin : g_sync
        always_ff @(posedge clk_dst) begin
          if (rst_ah) ff_q <= RESET_VALUE;
          else        ff_q <= stage_d[i];
        end
      end

      assign stage_q[i] = ff_q;
    end
  endgenerate

  assign sync_out = stage_q[STAGES-1];

endmodule



// edge_det_sync.sv
`timescale 1ns/1ps

module edge_det_sync #(
  parameter int    STAGES         = 2,
  parameter bit    RESET_VALUE    = 1'b0,
  parameter bit    ASYNC_RESET    = 1'b1,
  parameter bit    RST_ACTIVE_LOW = 1'b1,
  parameter string EDGE           = "RISE"   // "RISE", "FALL", "BOTH"
)(
  input  logic clk_dst,
  input  logic rst_dst_n,
  input  logic async_in,
  output logic edge_pulse
);

  logic sync_q;
  sync #(
    .STAGES(STAGES),
    .RESET_VALUE(RESET_VALUE),
    .ASYNC_RESET(ASYNC_RESET),
    .RST_ACTIVE_LOW(RST_ACTIVE_LOW)
  ) u_sync (
    .clk_dst   (clk_dst),
    .rst_dst_n (rst_dst_n),
    .async_in  (async_in),
    .sync_out  (sync_q)
  );

  wire rst_ah = RST_ACTIVE_LOW ? ~rst_dst_n : rst_dst_n;
  logic sync_q_d;

  generate
    if (ASYNC_RESET) begin
      always_ff @(posedge clk_dst or posedge rst_ah) begin
        if (rst_ah) sync_q_d <= RESET_VALUE;
        else        sync_q_d <= sync_q;
      end
    end else begin
      always_ff @(posedge clk_dst) begin
        if (rst_ah) sync_q_d <= RESET_VALUE;
        else        sync_q_d <= sync_q;
      end
    end
  endgenerate

  always_comb begin
    unique case (EDGE)
      "RISE": edge_pulse =  ( sync_q & ~sync_q_d );
      "FALL": edge_pulse =  (~sync_q &  sync_q_d );
      "BOTH": edge_pulse =  ( sync_q ^  sync_q_d );
      default: edge_pulse = ( sync_q & ~sync_q_d );
    endcase
  end

endmodule



// pulse_sync.sv
`timescale 1ns/1ps

module pulse_sync #(
  // Source domain reset
  parameter bit SRC_ASYNC_RESET     = 1'b1,
  parameter bit SRC_RST_ACTIVE_LOW  = 1'b1,
  parameter bit SRC_RESET_VALUE     = 1'b0,
  // Destination domain reset
  parameter bit DST_ASYNC_RESET     = 1'b1,
  parameter bit DST_RST_ACTIVE_LOW  = 1'b1,
  parameter bit DST_RESET_VALUE     = 1'b0,
  // Synchronizer stages for toggle transfer
  parameter int SYNC_STAGES         = 2
)(
  input  logic clk_src,
  input  logic rst_src_n,
  input  logic pulse_in,

  input  logic clk_dst,
  input  logic rst_dst_n,

  output logic pulse_out
);

  wire rst_src_ah = SRC_RST_ACTIVE_LOW ? ~rst_src_n : rst_src_n;
  wire rst_dst_ah = DST_RST_ACTIVE_LOW ? ~rst_dst_n : rst_dst_n;

  // Source toggle
  logic toggle_src;
  generate
    if (SRC_ASYNC_RESET) begin
      always_ff @(posedge clk_src or posedge rst_src_ah) begin
        if (rst_src_ah) toggle_src <= SRC_RESET_VALUE;
        else if (pulse_in) toggle_src <= ~toggle_src;
      end
    end else begin
      always_ff @(posedge clk_src) begin
        if (rst_src_ah) toggle_src <= SRC_RESET_VALUE;
        else if (pulse_in) toggle_src <= ~toggle_src;
      end
    end
  endgenerate

  // Synchronize toggle into destination domain
  logic toggle_dst;
  sync #(
    .STAGES(SYNC_STAGES),
    .RESET_VALUE(DST_RESET_VALUE),
    .ASYNC_RESET(DST_ASYNC_RESET),
    .RST_ACTIVE_LOW(DST_RST_ACTIVE_LOW)
  ) u_sync_toggle (
    .clk_dst   (clk_dst),
    .rst_dst_n (rst_dst_n),
    .async_in  (toggle_src),
    .sync_out  (toggle_dst)
  );

  // Edge detect in destination domain -> 1-cycle pulse
  logic toggle_dst_d;
  generate
    if (DST_ASYNC_RESET) begin
      always_ff @(posedge clk_dst or posedge rst_dst_ah) begin
        if (rst_dst_ah) toggle_dst_d <= DST_RESET_VALUE;
        else            toggle_dst_d <= toggle_dst;
      end
    end else begin
      always_ff @(posedge clk_dst) begin
        if (rst_dst_ah) toggle_dst_d <= DST_RESET_VALUE;
        else            toggle_dst_d <= toggle_dst;
      end
    end
  endgenerate

  assign pulse_out = toggle_dst ^ toggle_dst_d;

endmodule
