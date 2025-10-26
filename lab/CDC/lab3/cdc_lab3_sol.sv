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

  logic [WIDTH-1:0] data_buf_src;
  logic             busy;

  wire accept_src = valid_in && !busy;

  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
      data_buf_src <= '0;
    end else if (accept_src) begin
      data_buf_src <= data_in;
    end
  end

  logic dst_pulse;
  pulse_sync u_req_to_dst (
    .clk_src   (src_clk),
    .rst_src_n (src_rst_n),
    .pulse_in  (accept_src),
    .clk_dst   (dst_clk),
    .rst_dst_n (dst_rst_n),
    .pulse_out (dst_pulse)
  );

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      data_out  <= '0;
      valid_out <= 1'b0;
    end else begin
      valid_out <= dst_pulse;
      if (dst_pulse)
        data_out <= data_buf_src;
    end
  end

  // Acknowledgment pulse back to source domain and busy logic

  logic ack_src_pulse;
  pulse_sync u_ack_to_src (
    .clk_src   (dst_clk),
    .rst_src_n (dst_rst_n),
    .pulse_in  (dst_pulse),
    .clk_dst   (src_clk),
    .rst_dst_n (src_rst_n),
    .pulse_out (ack_src_pulse)
  );

  // Busy/Ready en origen: set con aceptación, clear con ack
  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
      busy <= 1'b0;
    end else begin
      if (accept_src)         busy <= 1'b1;
      else if (ack_src_pulse) busy <= 1'b0;
    end
  end

  assign ready_out = !busy;

endmodule