`timescale 1ns/1ps

// =======================================
// Counter with ASYNC reset (active-low)
// Includes $recovery/$removal checks.
// =======================================
module ctr8_async (
  input  logic        clk,
  input  logic        rst_n,   // async, active-low
  output logic [7:0]  q
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= '0;       // immediate assert
    else        q <= q + 8'd1; // count
  end

  // Recovery/removal timing checks for safe deassertion
  specify
    specparam TREC = 1.0, TREM = 1.0; // 1 ns window
    $recovery( posedge rst_n, posedge clk, TREC );
    $removal ( posedge rst_n, posedge clk, TREM );
  endspecify
endmodule

// ==================
// TESTBENCH (TOP)
// ==================
module tb_lab2;
  // VCD dump
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_lab2);
  end

  // 100 MHz clock
  logic clk = 1;
  always #5 clk = ~clk;

  // External reset: low at t=0, high at 49.5 ns (danger zone)
  logic rst_n_ext;
  initial begin
    rst_n_ext = 0;
    #49.5 rst_n_ext = 1;  // 0.5 ns before 50 ns edge
  end

  // Two reset paths with different delay
  wire rst_n_a = rst_n_ext;  // 0 ns
  wire rst_n_b; 
  assign #1 rst_n_b = rst_n_ext; // 1 ns

  logic [7:0] q_a, q_b;
  ctr8_async u_a (.clk(clk), .rst_n(rst_n_a), .q(q_a));
  ctr8_async u_b (.clk(clk), .rst_n(rst_n_b), .q(q_b));

  initial #200 $finish;
endmodule
