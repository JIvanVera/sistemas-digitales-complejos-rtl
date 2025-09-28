`timescale 1ns/1ps

module reset_sync #(int STAGES=2)(
  input  logic clk,
  input  logic ext_rst_n,
  output logic sync_rst_n
);
  logic [STAGES-1:0] shreg;
  always_ff @(posedge clk or negedge ext_rst_n) begin
    if (!ext_rst_n) shreg <= '0;
    else            shreg <= {shreg[STAGES-2:0], 1'b1};
  end
  assign sync_rst_n = shreg[STAGES-1];
endmodule

module ctr_async #(int W=4)(
  input  logic clk,
  input  logic rst_n,
  output logic [W-1:0] q
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= '0;
    else        q <= q + 1;
  end
endmodule



module tb_lab4_independent;
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_lab4_independent);
  end

  // Two clocks: A=10 ns, B=14 ns
  logic clkA=0, clkB=0;
  always #5   clkA = ~clkA;   // 100 MHz
  always #7   clkB = ~clkB;   // ~71.4 MHz

  // External reset
  logic ext_rst_n;
  initial begin
    ext_rst_n = 0;
    #10 ext_rst_n = 1;
    #35 ext_rst_n = 0;
    #60.2 ext_rst_n = 1; // deassert with skew vs both clocks
  end

  // One synchronizer per domain (independent releases)
  logic mrstA_n, mrstB_n;
  reset_sync uA (.clk(clkA), .ext_rst_n(ext_rst_n), .sync_rst_n(mrstA_n));
  reset_sync uB (.clk(clkB), .ext_rst_n(ext_rst_n), .sync_rst_n(mrstB_n));

  logic [3:0] qA, qB;
  ctr_async u_cntA (.clk(clkA), .rst_n(mrstA_n), .q(qA));
  ctr_async u_cntB (.clk(clkB), .rst_n(mrstB_n), .q(qB));

  initial #300 $finish;
endmodule
