// Code your design here
module valid_ready_cdc #(
		parameter	W = 32
	) (
		input	wire		i_a_clk,
		input	wire		i_a_reset_n,
		input	wire		i_a_valid,
		output	wire		o_a_ready,
		input	wire	[W-1:0]	i_a_data,
		//
		input	wire		i_b_clk,
		input	wire		i_b_reset_n,
		output	reg		    o_b_valid,
		input	wire		i_b_ready,
		output	reg	[W-1:0]	o_b_data
	);

	// Register declarations
	localparam	NFF = 2;
	reg			a_req, a_ack;
	reg	[W-1:0]		a_data;
	reg	[NFF-2:0]	a_pipe;

	reg			b_req, b_last, b_stb;
	reg	[NFF-2:0]	b_pipe;
  
	always @(posedge i_a_clk, negedge i_a_reset_n)
	if (!i_a_reset_n)
		a_req <= 1'b0;
	else if (i_a_valid && o_a_ready)
		a_req  <= !a_req;
  
  	always @(posedge i_a_clk)
	if (i_a_valid && o_a_ready)
		a_data <= i_a_data;
  
	always @(posedge i_b_clk, negedge i_b_reset_n)
	if (!i_b_reset_n)
		{ b_last, b_req, b_pipe } <= 0;
	else begin
		{ b_last, b_req, b_pipe } <= { b_req, b_pipe, a_req };
		if (o_b_valid && !i_b_ready)
			b_last <= b_last;
	end
  
  	always @(posedge i_a_clk, negedge i_a_reset_n)
	if (!i_a_reset_n)
		{ a_ack, a_pipe } <= 2'b00;
	else
		{ a_ack, a_pipe } <= { a_pipe, b_last };
  
  	assign	o_a_ready = (a_ack == a_req);

  
  	always @(*)
		b_stb = (b_last != b_req);
  
	always @(posedge i_b_clk)
	if (b_stb && (!o_b_valid || i_b_ready))
		o_b_data <= a_data;
  
	always @(posedge i_b_clk, negedge i_b_reset_n)
	if (!i_b_reset_n)
		o_b_valid <= 1'b0;
	else if (!o_b_valid || i_b_ready)
      
     o_b_valid <= b_stb;
endmodule