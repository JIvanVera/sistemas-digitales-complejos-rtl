
// sync.sv
// ------------------------------------------------------------
// Two-flop level synchronizer (CDC).
// - Asynchronous reset, active-low (rst_n)
// - Reset value = 0
// - Stable names (ff0_q, ff1_q) for constraints
`timescale 1ns/1ps

module sync (
  input  logic clk_dst,
  input  logic rst_n,      // async active-low reset
  input  logic async_in,
  output logic sync_out
);
  logic ff0_q, ff1_q;

  // Stage 0 (metastability catcher)
  always_ff @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) ff0_q <= 1'b0;
    else        ff0_q <= async_in;
  end

  // Stage 1
  always_ff @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) ff1_q <= 1'b0;
    else        ff1_q <= ff0_q;
  end

  assign sync_out = ff1_q;
endmodule

// edge_det_sync.sv
// ------------------------------------------------------------
// Synchronize an async level, then emit a 1-cycle pulse on rising edge.
`timescale 1ns/1ps

module edge_det_sync (
  input  logic clk_dst,
  input  logic rst_n,       // async, active-low
  input  logic async_in,
  output logic edge_pulse
);
  logic sync_q, sync_q_d;

  // Synchronizer
  sync u_sync (
    .clk_dst (clk_dst),
    .rst_n   (rst_n),
    .async_in(async_in),
    .sync_out(sync_q)
  );

  // Rising-edge detect
  always_ff @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) sync_q_d <= 1'b0;
    else        sync_q_d <= sync_q;
  end

  assign edge_pulse = sync_q & ~sync_q_d;
endmodule

// pulse_sync.sv
// ------------------------------------------------------------
// Toggle-based pulse synchronizer:
// - Converts a pulse in clk_src into a 1-cycle pulse in clk_dst.
`timescale 1ns/1ps

module pulse_sync (
  input  logic clk_src,
  input  logic rst_src_n,   // async, active-low
  input  logic pulse_in,

  input  logic clk_dst,
  input  logic rst_dst_n,   // async, active-low

  output logic pulse_out
);
  // Source toggle
  logic toggle_src;
  always_ff @(posedge clk_src or negedge rst_src_n) begin
    if (!rst_src_n)     toggle_src <= 1'b0;
    else if (pulse_in)  toggle_src <= ~toggle_src;
  end

  // Sync toggle into destination domain
  logic toggle_dst;
  sync u_sync_toggle (
    .clk_dst (clk_dst),
    .rst_n   (rst_dst_n),
    .async_in(toggle_src),
    .sync_out(toggle_dst)
  );

  // Edge detect in destination domain -> 1-cycle pulse
  logic toggle_dst_d;
  always_ff @(posedge clk_dst or negedge rst_dst_n) begin
    if (!rst_dst_n) toggle_dst_d <= 1'b0;
    else            toggle_dst_d <= toggle_dst;
  end

  assign pulse_out = toggle_dst ^ toggle_dst_d;
endmodule

