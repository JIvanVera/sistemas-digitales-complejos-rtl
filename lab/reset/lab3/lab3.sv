`timescale 1ns/1ps

module ctr8_async (
  input  wire       clk,
  input  wire       rst_n,   // async, active-low
  output reg  [7:0] q
);
  reg notifier = 0; // pulsed by timing checks

  // Include notifier event in sensitivity list (library-style)
  always @(posedge clk or negedge rst_n or posedge notifier) begin
    if (!rst_n)
      q <= 8'h00;
    else if (notifier)
      q <= 8'hxx; // drive X when recovery/removal is violated
    else
      q <= q + 8'd1;
  end

  // Timing checks with notifier
  specify
    specparam TREC = 1.0, TREM = 1.0; // 1 ns window
    $recovery( posedge rst_n, posedge clk, TREC, notifier );
    $removal ( posedge rst_n, posedge clk, TREM, notifier );
  endspecify
endmodule



// ==================================
// Reset synchronizer, active-low.
// Async assert, synchronous release.
// ==================================
module reset_sync #(
  int STAGES = 2
)(
  input  logic clk,
  input  logic ext_rst_n,   // active-low
  output logic sync_rst_n   // active-low
);
  logic [STAGES-1:0] shreg;

  always_ff @(posedge clk or negedge ext_rst_n) begin
    if (!ext_rst_n) shreg <= '0;                         // hold in reset
    else            shreg <= {shreg[STAGES-2:0], 1'b1};  // shift-in ones
  end

  assign #2 sync_rst_n =  shreg[STAGES-1]; // goes high after STAGES clocks
endmodule


// ==================
// TESTBENCH (TOP)
// ==================
module tb_lab3;
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_lab3);
  end

  // 100 MHz clock
  logic clk = 1;
  always #5 clk = ~clk;

  // External reset with risky deassertion time
  logic ext_rst_n;
  initial begin
    ext_rst_n = 0;
    #49.5 ext_rst_n = 1;
  end

  // Shared synchronizer
  logic mrst_n;
  reset_sync #(.STAGES(2)) u_sync (.clk(clk), .ext_rst_n(ext_rst_n), .sync_rst_n(mrst_n));

  // Two counters using synchronized reset
  logic [7:0] q0, q1;
  ctr8_async u0 (.clk(clk), .rst_n(mrst_n), .q(q0));
  ctr8_async u1 (.clk(clk), .rst_n(mrst_n), .q(q1));

  initial #200 $finish;
endmodule
