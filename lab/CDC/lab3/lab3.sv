// ==============================================
// Testbench
// ==============================================
module tb_mcp_lab3;
  logic clk_tx = 0, clk_rx = 0, rst_n = 0;
  logic next_data_pulse;
  logic [7:0] data_tx, data_rx;
  logic toggle_flag, load_pulse;

  tx_domain u_tx (.clk_tx(clk_tx), .rst_n(rst_n),
                  .next_data_pulse(next_data_pulse),
                  .toggle_flag(toggle_flag),
                  .data_out(data_tx));

  rx_domain u_rx (.clk_rx(clk_rx), .rst_n(rst_n),
                  .toggle_in(toggle_flag),
                  .data_in(data_tx),
                  .data_reg(data_rx),
                  .load_pulse(load_pulse));

  // Clocks
  always #5  clk_tx = ~clk_tx;   
  always #7  clk_rx = ~clk_rx;   // TODO: CHANGE to #8

  // Stimulus
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_mcp_lab3);
    rst_n = 0;
    next_data_pulse = 0;
    #30 rst_n = 1;
    repeat (5) begin
      #37 next_data_pulse = 1;
      #10 next_data_pulse = 0;
    end
    #200 $finish;
  end
endmodule


// timescale for simulation
`timescale 1ns/1ps

// ==============================================
// Transmit (TX) Clock Domain
// ==============================================
module tx_domain (
  input  logic        clk_tx, rst_n,
  input  logic        next_data_pulse,
  output logic        toggle_flag,
  output logic [7:0]  data_out
);
  logic last_pulse;

  // Toggle flag when there is an input pulse
  always_ff @(posedge clk_tx or negedge rst_n) begin
    if (!rst_n)
      toggle_flag <= 0;
    else if (next_data_pulse)
      toggle_flag <= ~toggle_flag;
  end

  // Example data pattern
  always_ff @(posedge clk_tx or negedge rst_n) begin
    if (!rst_n)
      data_out <= 8'h00;
    else if (next_data_pulse)
      data_out <= data_out + 1;
  end
endmodule


// ==============================================
// Receive (RX) Clock Domain
// ==============================================
module rx_domain (
  input  logic        clk_rx, rst_n,
  input  logic        toggle_in,
  input  logic [7:0]  data_in,
  output logic [7:0]  data_reg,
  output logic        load_pulse
);
  logic q1, q2, q3;

  // 3-flop synchronizer
  always_ff @(posedge clk_rx or negedge rst_n) begin
    if (!rst_n)
    {q3,q2,q1} <= 3'b000;
    else
    {q3,q2,q1} <= {q2, q1, toggle_in};
  end

  assign load_pulse = q3 ^ q2;

  // Capture data when synchronized pulse arrives
  always_ff @(posedge clk_rx or negedge rst_n) begin
    if (!rst_n)
      data_reg <= '0;
    else if (load_pulse)
      data_reg <= data_in;
  end
endmodule
