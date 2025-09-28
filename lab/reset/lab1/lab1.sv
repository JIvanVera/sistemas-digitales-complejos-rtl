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
  /*
  logic [N-1:0] rst_n_stage;
  always_ff @(posedge clk or negedge rst_n_in) begin
    if (!rst_n_in) 
      rst_n_stage <= 3'b000;
    else 
      rst_n_stage <= {rst_n_stage[1:0], 1'b1};
  end
      
  assign rst_n_out = rst_n_stage[2];
  */
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

  // Short reset "glitch" (4 ns) between clock edges
  logic rst_n_glitch = 1;
  initial begin
    // Pulse at t = 43..47 ns (between 40 and 50 ns edges)
    #43 rst_n_glitch = 0;
    #4  rst_n_glitch = 1;
  end

  // Stretcher (3 cycles)
  logic rst_n_stretched;
  rst_pulse_stretcher #(.N(3)) u_stretcher (
    .clk       (clk),
    .rst_n_in  (rst_n_glitch),
    .rst_n_out (rst_n_stretched)
  );

  // Two counters: direct vs stretched
  logic [7:0] q_direct, q_str;
  logic       co_direct, co_str;

  ctr8_sync u_cnt_direct (
    .clk(clk), .rst_n(rst_n_glitch),
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
