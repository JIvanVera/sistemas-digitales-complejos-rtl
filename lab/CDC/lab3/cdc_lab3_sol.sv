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

  // Acknowledgment pulse back to source domain and busy logic
  logic ack_src_pulse;
  pulse_sync u_ack_to_src (
    .clk_src   (dst_clk),
    .rst_src_n (dst_rst_n),
    .pulse_in  (load_pulse_dst),
    .clk_dst   (src_clk),
    .rst_dst_n (src_rst_n),
    .q (ack_src_pulse)
  );

  always_ff @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n) begin
      ready_out <= 1'b1;
    end else begin 
      if (valid_in)	 ready_out <= 1'b0;
      else if (ack_src_pulse) ready_out <= 1'b1;
    end
  
  
/*
  enum logic {READY = '1,
              BUSY = '0} state, next;

  always_ff @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n) state <= READY;
    else state <= next;

  always_comb begin
    case (state)
      READY: if (valid_in) next = BUSY;
             else next = READY;
      BUSY : if (ack_src_pulse) next = READY; 
             else next = BUSY;
     endcase
  end
  
 assign ready_out = state;
*/

endmodule
