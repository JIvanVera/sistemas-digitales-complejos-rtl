// Code your testbench here
// or browse Examples

// ==================
// TESTBENCH (TOP)
// ==================
`timescale 1ns/1ps

module tb_lab3;
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_lab3);
  end

  // clocks
  logic clk0 = 1;
  always #5 clk0 = ~clk0;
  logic clk1 = 1;
  always #3 clk1 = ~clk1;
  
  // External reset
  logic ext_rst_n;
  logic U0_din=0, U1_din;
  logic U0_dout, U1_dout;
  initial begin
    ext_rst_n = 0;
    #20 ext_rst_n = 1;
  end
  
  always_ff@(negedge clk0)
    begin
    	U0_din <= ~U0_din;
    end
  
  logic rstn_0;
  reset_sync reset_sync0(.clk (clk0), .ext_rst_n(ext_rst_n), .sync_rst_n(rstn_0));
   logic rstn_1;
  reset_sync reset_sync1(.clk (clk1), .ext_rst_n(ext_rst_n), .sync_rst_n(rstn_1));
  // Two counters using synchronized reset
  logic [7:0] q0, q1;
  flipflop u0 (.clk(clk0), .rst_n(rstn_0), .din(U0_din), .dout(U0_dout));
  
  logic data_sync;
  sync sync0  (.clk(clk1), .ext_rst_n(rstn_1), .din(U0_dout), .syn_out(data_sync));
  flipflop u1 (.clk(clk1), .rst_n(rstn_1), .din(data_sync), .dout(U1_dout));

  initial #200 $finish;
endmodule

// Code your design here
`timescale 1ns/1ps
module flipflop (
  input  wire       clk,
  input  wire       rst_n,   // async, active-low
  input  wire       din,
  output reg        dout
);
  reg notifier = 0; // pulsed by timing checks

  // Include notifier event in sensitivity list (library-style)
  always @(posedge clk or negedge rst_n or posedge notifier) begin
    if (!rst_n)
      dout <= 1'b0;
    else if (notifier) begin
      dout <= 1'bx; // drive X when recovery/removal is violated
      notifier <= 1'b0;
     end else
      dout <= din;
  end

  // Timing checks with notifier
  specify
    specparam TREC = 1.0, TREM = 1.0, TSET = 1.0, THOL = 1.0; // 1 ns window
    $setup ( posedge din, posedge clk, TSET, notifier );
    $hold  ( posedge din, posedge clk, THOL, notifier );
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

  assign #1.1 sync_rst_n =  shreg[STAGES-1]; // goes high after STAGES clocks
endmodule

module sync #(
  int STAGES = 2
)(
  input  logic clk,
  input  logic ext_rst_n,   // active-low
  input  logic din,   // active-low
  output logic syn_out   // active-low
);
  logic [STAGES-1:0] shreg;

  always_ff @(posedge clk or negedge ext_rst_n) begin
    if (!ext_rst_n) shreg <= '0;                         // hold in reset
    else            shreg <= {shreg[STAGES-2:0], din};  // shift-in ones
  end

  assign #1.1 syn_out =  shreg[STAGES-1]; // goes high after STAGES clocks
endmodule
