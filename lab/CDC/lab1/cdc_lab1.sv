// ============================================================
//  LAB 1: Basic Clock-Domain Crossing (CDC) Synchronizers
// ============================================================
//
//  Goal:
//  ------
//  Implement and understand three fundamental synchronizer types
//  used to safely transfer signals between asynchronous clock domains:
//
//    1. sync           – level synchronizer (two flip-flops)
//    2. edge_det_sync  – edge detector for asynchronous level inputs
//    3. pulse_sync     – toggle-based pulse synchronizer
//
//  Description:
//  -------------
//  This lab introduces how to safely cross signals between different
//  clock domains in digital designs. A direct connection between
//  asynchronous clocks can lead to metastability and unpredictable
//  behavior. The modules in this lab progressively solve this issue:
//
//   • sync:
//       Transfers a *level* from clk_src to clk_dst by using two
//       cascaded flip-flops in the destination domain.
//
//   • edge_det_sync:
//       Synchronizes a level, then detects a *rising edge* in the
//       destination clock domain, producing a 1-cycle pulse.
//
//   • pulse_sync:
//       Safely transfers a *1-cycle pulse* between asynchronous
//       clock domains by converting it to a toggle and resynchronizing.
//
//  Tasks:
//  -------
//   1. Complete the module "sync":
//        - Use two flip-flops in the destination clock domain.
//        - Asynchronous, active-low reset.
//        - Output = value of second stage.
//
//   2. Complete the module "edge_det_sync":
//        - Reuse your sync module inside.
//        - Generate a 1-cycle pulse in clk_dst on each rising edge of
//          the synchronized input.
//
//   3. Complete the module "pulse_sync":
//        - In clk_src domain: convert pulse_in into a toggle signal.
//        - Synchronize this toggle into clk_dst using sync.
//        - Detect toggle change (XOR current vs previous) to generate
//          a 1-cycle pulse in clk_dst.
//
//  Deliverable:
//  --------------
//   You must complete:
//     - sync
//     - edge_det_sync
//     - pulse_sync
//
//   The testbench will verify all three automatically.
//

// tb_cdc_sync.sv
// ------------------------------------------------------------
// Testbench for: sync, edge_det_sync, pulse_sync
// ------------------------------------------------------------
// - All input signals are generated in the clk_src domain
//   (no #delays — everything happens on @posedge clk_src).
// - clk_src = 100 MHz (10 ns period)
// - clk_dst = 40 MHz  (25 ns period)
// - Resets are asynchronous, active-low.
// - Waveforms show the behavior of each synchronizer type.
//
// Expected observations:
//   * sync:     output follows input level with latency of 1–2 clk_dst cycles
//   * edge_det: 1-cycle pulse in clk_dst domain per rising edge
//   * pulse_sync: single-cycle pulse in clk_dst domain per src pulse
`timescale 1ns/1ps

module tb_cdc_sync;

  // ----------------------------------------------------------
  // Clock generation
  // ----------------------------------------------------------
  logic clk_src; initial begin clk_src=0; forever #5    clk_src=~clk_src; end // 100 MHz (10 ns)
  logic clk_dst; initial begin clk_dst=0; forever #12.5 clk_dst=~clk_dst; end // 40 MHz (25 ns)

  // ----------------------------------------------------------
  // Asynchronous resets (active-low)
  // ----------------------------------------------------------
  logic rst_src_n, rst_dst_n;
  initial begin
    rst_src_n = 0; rst_dst_n = 0;
    repeat (12) @(posedge clk_src); // hold reset for ~120 ns
    rst_src_n = 1; rst_dst_n = 1;
  end

  // ----------------------------------------------------------
  // DUT signals
  // ----------------------------------------------------------
  logic async_level, level_synced;
  logic async_level_for_edge, edge_pulse_dst;
  logic pulse_src, pulse_dst;

  // ----------------------------------------------------------
  // DUT instances
  // ----------------------------------------------------------
  sync u_sync_level (
    .clk_dst   (clk_dst),
    .rst_n     (rst_dst_n),
    .async_in  (async_level),
    .sync_out  (level_synced)
  );

  edge_det_sync u_edge (
    .clk_dst    (clk_dst),
    .rst_n      (rst_dst_n),
    .async_in   (async_level_for_edge),
    .edge_pulse (edge_pulse_dst)
  );

  pulse_sync u_pulse (
    .clk_src   (clk_src),
    .rst_src_n (rst_src_n),
    .pulse_in  (pulse_src),
    .clk_dst   (clk_dst),
    .rst_dst_n (rst_dst_n),
    .pulse_out (pulse_dst)
  );


  // ----------------------------------------------------------
  // Utility tasks in clk_src domain
  // ----------------------------------------------------------
  task automatic wait_src_cycles(input int n);
    repeat (n) @(posedge clk_src);
  endtask

  task automatic pulse_one_src_cycle();
    pulse_src <= 1'b1;
    @(posedge clk_src);
    pulse_src <= 1'b0;
  endtask

  task automatic pulse_n_src_cycles(input int n);
    pulse_src <= 1'b1;
    wait_src_cycles(n);
    pulse_src <= 1'b0;
  endtask

  // ----------------------------------------------------------
  // Stimulus: async_level (for sync)
  // ----------------------------------------------------------
  // Changes at different rates but always synchronous to clk_src
  initial begin
    async_level = 1'b0;
    @(posedge rst_src_n);
    wait_src_cycles(3);

    // Slow toggles (every 7 src cycles)
    repeat (4) begin
      wait_src_cycles(7);
      async_level <= ~async_level;
    end

    // Medium toggles (every 3 src cycles)
    repeat (6) begin
      wait_src_cycles(3);
      async_level <= ~async_level;
    end

    // Fast toggles (every 2 src cycles)
    repeat (8) begin
      wait_src_cycles(2);
      async_level <= ~async_level;
    end
  end

  // ----------------------------------------------------------
  // Stimulus: async_level_for_edge (for edge_det_sync)
  // ----------------------------------------------------------
  // Generates rising edges and short bursts in clk_src domain
  initial begin
    async_level_for_edge = 1'b0;
    @(posedge rst_src_n);
    wait_src_cycles(5);

    repeat (4) begin
      // short 1-cycle pulse
      async_level_for_edge <= 1'b1;
      wait_src_cycles(1);
      async_level_for_edge <= 1'b0;

      // longer pulse
      wait_src_cycles(4);
      async_level_for_edge <= 1'b1;
      wait_src_cycles(2);
      async_level_for_edge <= 1'b0;

      // idle period
      wait_src_cycles(7);
    end

    // Continuous toggle sequence (not aligned to clk_dst)
    repeat (8) begin
      wait_src_cycles(5);
      async_level_for_edge <= ~async_level_for_edge;
    end

    async_level_for_edge <= 1'b0;
  end

  // ----------------------------------------------------------
  // Stimulus: pulse_src (for pulse_sync)
  // ----------------------------------------------------------
  // Generates pulses of different widths in clk_src domain
  initial begin
    pulse_src = 1'b0;
    @(posedge rst_src_n);
    wait_src_cycles(2);

    // Long pulse
    repeat (1) begin
      pulse_n_src_cycles(2);
      wait_src_cycles(10);
    end
    
    // Burst of short pulses (1 cycle each)
    repeat (5) begin
      pulse_one_src_cycle();
      wait_src_cycles(4);
    end

    // Simulation end
    wait_src_cycles(40);
    $display("[%0t] End of simulation", $time);
    $finish;
  end

  // ----------------------------------------------------------
  // Naive comparator: edge detection without synchronization
  // ----------------------------------------------------------
  logic naive_edge_pulse, naive_d_q;
  always_ff @(posedge clk_dst or negedge rst_dst_n) begin
    if (!rst_dst_n) naive_d_q <= 1'b0;
    else            naive_d_q <= async_level_for_edge;
  end
  assign naive_edge_pulse = async_level_for_edge & ~naive_d_q;

  // ----------------------------------------------------------
  // Waveform dump
  // ----------------------------------------------------------
  initial begin
    $dumpfile("cdc_sync.vcd");
    $dumpvars(0, tb_cdc_sync);
  end

endmodule


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

endmodule


