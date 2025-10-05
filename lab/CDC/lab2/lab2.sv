
module tb_sync_pulse;
  logic clk = 0, rst_n = 0, toggle_in = 0;
  logic pulse_out0, pulse_out1, pulse_out2;



  always #5 clk = ~clk; // 100 MHz

  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_sync_pulse);
    #10 rst_n = 1;
    #50 toggle_in = 1;   // Toggle high
    #50 toggle_in = 0;   // Toggle low
    #100 $finish;
  end
  
  sync_pulse     dut  (.clk(clk), .rst_n(rst_n), .toggle_in(toggle_in), .pulse_out(pulse_out0));
  sync_pulse_pos dut1 (.clk(clk), .rst_n(rst_n), .toggle_in(toggle_in), .pulse_out(pulse_out1));
  sync_pulse_neg dut2 (.clk(clk), .rst_n(rst_n), .toggle_in(toggle_in), .pulse_out(pulse_out2));

endmodule




module sync_pulse (
  input  logic clk, rst_n,
  input  logic toggle_in,
  output logic pulse_out
);
  logic q1, q2, q3;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      {q1, q2, q3} <= '0;
    else
      {q1, q2, q3} <= {toggle_in, q1, q2};
  end

  // Pulse when q2 and q3 differ
  assign pulse_out = q2 ^ q3;
  
endmodule

module sync_pulse_pos (
  input  logic clk, rst_n,
  input  logic toggle_in,
  output logic pulse_out
);
  logic q1, q2, q3;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      {q1, q2, q3} <= '0;
    else
      {q1, q2, q3} <= {toggle_in, q1, q2};
  end

  assign pulse_out = ~q2 & q3;
  
endmodule

module sync_pulse_neg (
  input  logic clk, rst_n,
  input  logic toggle_in,
  output logic pulse_out
);
  logic q1, q2, q3;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      {q1, q2, q3} <= '0;
    else
      {q1, q2, q3} <= {toggle_in, q1, q2};
  end

  assign pulse_out = q2 & ~q3;
  
endmodule

