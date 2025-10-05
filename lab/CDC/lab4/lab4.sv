`timescale 1ns/1ps

module tb_mcp_blk;
  // ======================================================
  // Clocks
  // ======================================================
  logic aclk = 0, bclk = 0;
  always #5  aclk = ~aclk;   // 100 MHz
  always #7  bclk = ~bclk;   // ~71 MHz

  // ======================================================
  // Resets
  // ======================================================
  logic arst_n = 0, brst_n = 0;
  initial begin
    arst_n = 0;
    brst_n = 0;
    #20;
    arst_n = 1;
    #30;
    brst_n = 1;
  end

  // ======================================================
  // DUT connections
  // ======================================================
  logic [7:0] adatain, bdata;
  logic asend, aready, bvalid, bload;

  mcp_blk dut (
    .aready(aready),
    .adatain(adatain),
    .asend(asend),
    .aclk(aclk),
    .arst_n(arst_n),
    .bdata(bdata),
    .bvalid(bvalid),
    .bload(bload),
    .bclk(bclk),
    .brst_n(brst_n)
  );

  // ======================================================
  // Stimulus (domain A)
  // ======================================================
  initial begin
    asend   = 0;
    adatain = 0;
    bload   = 0;

    wait (arst_n && brst_n);
    #40;

    repeat (5) begin
      @(posedge aclk iff aready);
      adatain = $urandom_range(0,255);
      asend   = 1;
      @(posedge aclk);
      asend   = 0;
      $display("[%0t] A-domain SEND: 0x%0h", $time, adatain);
      #40;
    end
  end

  // ======================================================
  // Receiver behavior (domain B)
  // ======================================================
  always @(posedge bclk) begin
    if (bvalid) begin
      bload <= 1;
      $display("[%0t] B-domain RECV: 0x%0h", $time, bdata);
    end else begin
      bload <= 0;
    end
  end

  // ======================================================
  // Simulation control
  // ======================================================
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_mcp_blk);
    #2000 $finish;
  end

endmodule



module sync2 (
  output logic q,
  input logic d, clk, rst_n
);
  logic q1; // 1st stage ff output
	
  always_ff @(posedge clk or negedge rst_n)
	if (!rst_n) {q,q1} <= '0;
	else {q,q1} <= {q1,d};
endmodule

module plsgen (
  output logic pulse, q,
  input logic d,
  input logic clk, rst_n
);

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) q <= '0;
    else q <= d;

  assign pulse = q ^ d;
endmodule


module asend_fsm (
  input logic aclk, arst_n,
  input logic asend, // send adata
  input logic aack, // acknowledge receipt of adata
  output logic aready // ready to send next data
  );

  enum logic {READY = '1, BUSY = '0} state, next;

  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) state <= READY;
    else state <= next;

  always_comb begin
    case (state)
    READY: if (asend) next = BUSY;
           else next = READY;
    BUSY : if (aack) next = READY;
           else next = BUSY;
    endcase
  end
  
  assign aready = state;
endmodule

module back_fsm (
  output logic bvalid, // data valid / ready to load
  input logic bload, // load data / send acknowledge
  input logic b_en, // enable receipt of adata
  input logic bclk, brst_n);

  enum logic {READY = '1, WAIT = '0} state, next;

  always_ff @(posedge bclk or negedge brst_n)
    if (!brst_n) state <= WAIT;
	else state <= next;

  always_comb begin
	case (state)
	READY: if (bload) next = WAIT;
		   else next = READY;
	WAIT : if (b_en) next = READY;
		   else next = WAIT;
	endcase
  end

  assign bvalid = state;
endmodule

module amcp_send (
  output logic [7:0] adata,
  output logic a_en, aready,
  input logic [7:0] adatain,
  input logic asend,
  input logic aq2_ack,
  input logic aclk, arst_n);

  logic aack; // acknowledge pulse from pulse generator

  // Pulse Generator
  plsgen pg1 (.pulse(aack), .q(), .d(aq2_ack),
              .clk(aclk), .rst_n(arst_n));

  // data ready/acknowledge FSM
  asend_fsm fsm (.*);

  // send next data word
  assign anxt_data = aready & asend;

  // toggle-flop controlled by anxt_data
  always_ff @(posedge aclk or negedge arst_n)
    if ( !arst_n) a_en <= '0;
    else if (anxt_data) a_en <= ~a_en;

  always_ff @(posedge aclk or negedge arst_n)
    if ( !arst_n) adata <= '0;
    else if (anxt_data) adata <= adatain;
endmodule

module bmcp_recv (
  output logic [7:0] bdata,
  output logic bvalid, // bdata valid
  output logic b_ack, // acknowledge signal
  input logic [7:0] adata, // unsynchronized adata
  input logic bload, // load data and acknowledge receipt
  input logic bq2_en, // synchornized enable input
  input logic bclk, brst_n
);

  logic b_en; // enable pulse from pulse generator
  
  // Pulse Generator
  plsgen pg1 (.pulse(b_en), .q(), .d(bq2_en),
               .clk(bclk), .rst_n(brst_n), .*);

  // data ready/acknowledge FSM
  back_fsm fsm (.*);

  // load next data word
  assign bload_data = bvalid & bload;

  // toggle-flop controlled by bload_data
  always_ff @(posedge bclk or negedge brst_n)
    if ( !brst_n) b_ack <= '0;
    else if (bload_data) b_ack <= ~b_ack;

  always_ff @(posedge bclk or negedge brst_n)
    if ( !brst_n) bdata <= '0;
    else if (bload_data) bdata <= adata;
endmodule

module mcp_blk #(parameter type dat_t = logic [7:0]) (
  output logic aready, // ready to receive next data
  input logic [7:0] adatain,
  input logic asend,
  input logic aclk, arst_n,
  output logic [7:0] bdata,
  output logic bvalid, // bdata valid (ready)
  input logic bload,
  input logic bclk, brst_n
);

  logic [7:0] adata; // internal data bus
  logic b_ack; // acknowledge enable signal
  logic a_en; // control enable signal
  logic bq2_en; // control - sync output
  logic aq2_ack; // feedback - sync output

  sync2 async (.q(aq2_ack), .d(b_ack), .clk(aclk), .rst_n(arst_n));

  sync2 bsync (.q(bq2_en), .d(a_en), .clk(bclk), .rst_n(brst_n));

  amcp_send alogic (.*);

  bmcp_recv blogic (.*);
endmodule