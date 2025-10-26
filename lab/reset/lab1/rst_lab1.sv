// ============================================================
//  LAB 1: Synchronous Reset and Reset Pulse Stretching
// ============================================================
//
//  Goal:
//  ------
//  Understand the behavior of a synchronous reset signal that
//  may be too short to be detected by sequential logic, and
//  learn how to extend ("stretch") a short asynchronous reset
//  pulse so that it remains active for a guaranteed number of
//  clock cycles.
//

`timescale 1ns/1ps

// =======================
// DUT: synchronous counter
// =======================
module ctr8_sync (
  input  logic        clk,
  input  logic        rst_n,   // synchronous reset, active-low
  input  logic        load,
  input  logic [7:0]  d,
  output logic [7:0]  q,
  output logic        co
);
  always_ff @(posedge clk) begin
    if (!rst_n)         {co,q} <= '0;        // sync reset
    else if (load)      {co,q} <= d;         // load
    else                {co,q} <= q + 8'd1;  // increment
  end
endmodule

// =======================================================
// Reset pulse stretcher: async capture, release after N cycles
// =======================================================
module rst_pulse_stretcher #(
  int N = 3
)(
  input  logic clk,
  input  logic rst_n_in,     // short pulse (active-low)
  output logic rst_n_out     // active-low, guaranteed >= N cycles
);
  assign rst_n_out = rst_n_in;
endmodule

// ==================
// TESTBENCH (TOP)
// ==================
module tb_lab1;
  // VCD dump for EPWave
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_lab1);
  end

  // 100 MHz clock (10 ns period)
  logic clk = 0;
  always #5 clk = ~clk;

  // Short reset between clock edges
  logic rst_n;
  initial begin
    rst_n <= 1;
    @(negedge clk) rst_n = 0; // rst_n low for one cycle
    #4 rst_n = 1;
  end

  // Stretcher (3 cycles)
  logic rst_n_stretched;
  rst_pulse_stretcher #(.N(3)) u_stretcher (
    .clk       (clk),
    .rst_n_in  (rst_n),
    .rst_n_out (rst_n_stretched)
  );

  // Two counters: direct vs stretched
  logic [7:0] q_direct, q_str;
  logic       co_direct, co_str;

  ctr8_sync u_cnt_direct (
    .clk(clk), .rst_n(rst_n),
    .load(1'b0), .d('0),
    .q(q_direct), .co(co_direct)
  );

  ctr8_sync u_cnt_stretched (
    .clk(clk), .rst_n(rst_n_stretched),
    .load(1'b0), .d('0),
    .q(q_str), .co(co_str)
  );

  initial begin
    #200 $finish;
  end
endmodule
