

module toggle_pulse_sync #(
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
  input  logic              load_in,

  // Destination domain outputs
  output logic [WIDTH-1:0]  data_out,
  output logic              valid_out
);

  // Source domain registers
  logic [WIDTH-1:0] data_buf_src;
  logic req_tog_src;
  logic load_pulse_dst;

  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
    	data_buf_src <= '0;
        req_tog_src <= 1'b0;
    end else begin
      if (load_in) begin
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

endmodule