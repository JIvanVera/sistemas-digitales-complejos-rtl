
// ==============================================
// Testbench
// ==============================================
`timescale 1ns/1ps

module tb_mcp_with_feedback;

  localparam int WIDTH = 8;

  // Clocks and resets
  logic src_clk = 0;
  logic dst_clk = 0;
  logic src_rst_n = 0;
  logic dst_rst_n = 0;

  // DUT signals
  logic [WIDTH-1:0] data_in;
  logic valid_in;
  logic [WIDTH-1:0] data_out;
  logic valid_out;
  logic ready_out;

  // Instantiate DUT
  mcp_ack #(.WIDTH(WIDTH)) dut (
    .src_clk(src_clk),
    .src_rst_n(src_rst_n),
    .dst_clk(dst_clk),
    .dst_rst_n(dst_rst_n),
    .data_in(data_in),
    .valid_in(valid_in),
    .ready_out(ready_out),
    .data_out(data_out),
    .valid_out(valid_out)
  );

  // Generate two asynchronous clocks
  always #5  src_clk = ~src_clk;  // 100 MHz
  always #7  dst_clk = ~dst_clk;  // ~71 MHz

  // Reset sequence
  initial begin
    src_rst_n = 0;
    dst_rst_n = 0;
    valid_in   = 0;
    data_in   = 0;

    // Dump signals for waveform viewer
    $dumpfile("tb_mcp_with_feedback.vcd");
    $dumpvars(0, tb_mcp_with_feedback);

    #30;
    src_rst_n = 1;
    dst_rst_n = 1;
  end

  // Stimulus: send several pulses from the source domain
  initial begin
    wait(src_rst_n && dst_rst_n);
    @(posedge src_clk);

    repeat (5) begin
      // Wait until DUT is ready
      wait(ready_out);
      data_in = $urandom_range(0, 255);
      $display("[%0t] SRC: Sending data = 0x%0h", $time, data_in);
      valid_in = 1'b1;
      @(posedge src_clk);
      valid_in = 1'b0;
      @(posedge src_clk);
    end

    // Wait for last data to propagate
    #200;
    $finish;
  end

  initial begin
  	#50000; // 50 us sim time (más que suficiente aquí)
  	$fatal(1, "[TB] TIMEOUT");
	end
  
  // Monitor in destination domain
  always_ff @(posedge dst_clk) begin
    if (valid_out)
      $display("[%0t] DST: Received data = 0x%0h", $time, data_out);
  end

endmodule


// ==============================================
// Modules
// ==============================================

// timescale for simulation
`timescale 1ns/1ps

module sync (
  input  logic clk_dst,
  input  logic rst_n,      // async active-low reset
  input  logic async_in,
  output logic sync_out
);
  logic ff0_q, ff1_q;

  // Stage 0 (metastability catcher)
  always_ff @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) ff0_q <= 1'b0;
    else        ff0_q <= async_in;
  end

  // Stage 1
  always_ff @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) ff1_q <= 1'b0;
    else        ff1_q <= ff0_q;
  end

  assign sync_out = ff1_q;
endmodule

module pulse_sync (
  input  logic clk_src,
  input  logic rst_src_n,   // async, active-low
  input  logic pulse_in,

  input  logic clk_dst,
  input  logic rst_dst_n,   // async, active-low
  output logic q,
  output logic pulse_out
);
  // Sync toggle into destination domain
  logic toggle_dst;
  sync u_sync_toggle (
    .clk_dst (clk_dst),
    .rst_n   (rst_dst_n),
    .async_in(pulse_in),
    .sync_out(toggle_dst)
  );

  // Edge detect in destination domain -> 1-cycle pulse
  logic toggle_dst_d;
  always_ff @(posedge clk_dst or negedge rst_dst_n) begin
    if (!rst_dst_n) toggle_dst_d <= 1'b0;
    else            toggle_dst_d <= toggle_dst;
  end
  assign q = toggle_dst;
  assign pulse_out = toggle_dst ^ toggle_dst_d;
endmodule

module mcp_ack #(
  parameter int WIDTH = 32
) (
  // Source clock and reset
  input  logic              src_clk,
  input  logic              src_rst_n,

  // Destination clock and reset
  input  logic              dst_clk,
  input  logic              dst_rst_n,

  // Source domain inputs
  input  logic [WIDTH-1:0]  data_in,
  input  logic              valid_in,
  output logic              ready_out,

  // Destination domain outputs
  output logic [WIDTH-1:0]  data_out,
  output logic              valid_out
);

  // Source domain registers
  logic [WIDTH-1:0] data_buf_src;
  logic req_tog_src;
  logic load_pulse_dst;
  logic ready;

  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
    	data_buf_src <= '0;
        req_tog_src <= 1'b0;
    end else begin
      if (valid_in && ready_out) begin
        data_buf_src <= data_in;
        req_tog_src <= ~req_tog_src;
      end
    end
  end

  pulse_sync pulse_sync_u1(
    .clk_src(src_clk),
    .rst_src_n(src_rst_n), 
    .pulse_in(req_tog_src),

    .clk_dst(dst_clk),
    .rst_dst_n(dst_rst_n),
    .pulse_out(load_pulse_dst)
  );

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      data_out <= '0;
      valid_out <= 1'b0;
    end else if (load_pulse_dst) begin
      data_out <= data_buf_src;
      valid_out <=1'b1;
    end else begin
      //data_out <= '0;
      valid_out <= 1'b0;
    end
  end

  // Acknowledgment pulse back to source domain and ready_out logic


endmodule

