// =======================================================
// Reset pulse stretcher: async capture, release after N cycles
// =======================================================
module rst_pulse_stretcher #(
  int N = 3
)(
  input  logic clk,
  input  logic rst_n_in,     // short pulse (active-low)
  output logic rst_n_out     // active-low, guaranteed >= N cycles
);
  
  logic [N-1:0] rst_n_stage;
  
  always_ff @(posedge clk or negedge rst_n_in) begin
    if (!rst_n_in)  begin
    	rst_n_stage <= '0;
    end else begin
      rst_n_stage <= {rst_n_stage[N-2:0], 1'b1};
    end
  end
  
  assign rst_n_out = rst_n_stage[N-1];
  
endmodule
