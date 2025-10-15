`timescale 1ns/1ps

module tb_gray_bin_cntr;
  localparam SIZE = 5;

  // Signals for conversion test
  logic [SIZE-1:0] bin, gray, bin_back;

  // DUTs for conversion
  bin2gray #(SIZE) u_bin2gray (.gray(gray), .bin(bin));
  gray2bin #(SIZE) u_gray2bin (.bin(bin_back), .gray(gray));

  // Signals for gray counter test
  logic clk, rst_n, inc;
  logic [SIZE-1:0] gray_cnt;

  // DUT for gray counter
  graycntr #(SIZE) u_graycntr (
    .gray(gray_cnt),
    .clk(clk),
    .inc(inc),
    .rst_n(rst_n)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk; // 100 MHz

  // VCD dump
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_gray_bin_cntr);
  end

  // Gray/Binary conversion test
  initial begin
    $display("\n=== Gray/Binary Conversion Test ===");
    $display("BIN -> GRAY -> BIN_back");
    for (int i = 0; i < (1 << SIZE); i++) begin
      bin = i;
      #1;
      $display("%b -> %b -> %b", bin, gray, bin_back);
      if (bin_back !== bin)
        $error("Mismatch! bin=%b gray=%b bin_back=%b", bin, gray, bin_back);
    end
    $display("All Gray/Binary conversions verified OK!\n");
  end

  // Gray counter test
  initial begin
    $display("=== Gray Counter Test ===");
    rst_n = 0;
    inc   = 0;
    @(negedge clk);
    rst_n = 1;
    repeat (20) begin
      @(negedge clk);
      inc = 1;
      @(negedge clk);
      inc = 0;
      @(posedge clk);
      #1;
      $display("Time=%4t | Gray count = %b", $time, gray_cnt);
    end

    $display("Gray counter simulation finished.\n");
    $finish;
  end

endmodule



module gray2bin #(
  parameter SIZE = 4
)(
  input logic [SIZE-1:0] gray,
  output logic [SIZE-1:0] bin
);

  always_comb
	for (int i=0; i<SIZE; i++)
		bin[i] = ^(gray>>i);
endmodule

module bin2gray #(
  parameter SIZE = 4
)(
  input logic [SIZE-1:0] bin,
  output logic [SIZE-1:0] gray	
);
	assign gray = (bin>>1) ^ bin;
endmodule

module graycntr #(
  parameter SIZE = 5
)(
  input logic clk, inc, rst_n,
  output logic [SIZE-1:0] gray
 );
  logic [SIZE-1:0] gnext, bnext, bin;

  always_ff @(posedge clk or negedge rst_n)
	if (!rst_n) gray <= '0;
	else gray <= gnext;

  always_comb begin
	for (int i=0; i<SIZE; i++)
		bin[i] = ^(gray>>i);
	bnext = bin + inc;
	gnext = (bnext>>1) ^ bnext;
	end
endmodule


// This is used in the async FIFO
module graycntr #(
  parameter SIZE = 5)
(
  output logic [SIZE-1:0] gray,
  input logic clk, full, inc, rst_n
);
  logic [SIZE-1:0] gnext, bnext, bin;

  always_ff @(posedge clk or negedge rst_n)
    if (!wrst_n) begin 
      {bin, gray} <= '0;
    end else begin 
      bin  <= bnext;
      gray <= gnext;
    end

  assign bnext = !full ? bin + inc : bin;
  assign gnext = (bnext>>1) ^ bnext;
endmodule