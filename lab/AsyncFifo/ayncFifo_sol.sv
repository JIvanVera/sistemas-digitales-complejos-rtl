module fifo #(parameter DSIZE = 8,
parameter ASIZE = 4)
(
    input logic wclk,
    input logic wrst_n,

    input logic winc,
    input logic [DSIZE-1:0] wdata,
    output logic wfull,

    input logic rclk,
    input logic rrst_n,

    input logic rinc,
    output logic [DSIZE-1:0] rdata,
    output logic rempty
);
    wire [ASIZE-1:0] waddr, raddr;
    wire [ASIZE:0] wptr, rptr, wq2_rptr, rq2_wptr;

    wptr_full #(ASIZE) wptr_full
    (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .winc(winc), 

        .wq2_rptr(wq2_rptr),
        .waddr(waddr),
        .wptr(wptr), 
        .wfull(wfull)
    );

  sync sync_r2w (.clk(wclk), .rst_n(wrst_n), .sync_data_out(wq2_rptr), .data_in(rptr));

    fifomem #(DSIZE, ASIZE) fifomem 
    (
        .wclk(wclk),
        .wclken(winc && !wfull),
        .waddr(waddr), 
        .wdata(wdata),
        
        .raddr(raddr),
        .rdata(rdata)        
    );

  sync sync_w2r (.clk(rclk), .rst_n(rrst_n), .sync_data_out(rq2_wptr), .data_in(wptr));

    rptr_empty #(ASIZE) rptr_empty
    (
        .rclk(rclk),
        .rrst_n(rrst_n),
        .rinc(rinc),

        .rq2_wptr(rq2_wptr),
        .raddr(raddr),
        .rptr(rptr), 
        .rempty(rempty)
    );
endmodule


module fifomem #(
    parameter DATASIZE = 8, // Memory data word width
    parameter ADDRSIZE = 4) // Number of mem address bits
(
    input logic wclk,
    input logic wclken, 
    input [ADDRSIZE-1:0] waddr,
    input [DATASIZE-1:0] wdata,
    input [ADDRSIZE-1:0] raddr,
    output [DATASIZE-1:0] rdata
);
    localparam DEPTH = 1<<ADDRSIZE;
    reg [DATASIZE-1:0] mem [0:DEPTH-1];

    always_ff @(posedge wclk)
        if (wclken) mem[waddr] <= wdata;

    assign rdata = mem[raddr];
endmodule

module sync #(
    parameter ADDRSIZE = 4
) (
    input logic clk, 
    input logic rst_n,
    input logic [ADDRSIZE:0] data_in,
    output logic [ADDRSIZE:0] sync_data_out
);
    reg [ADDRSIZE:0] sync_reg1, sync_reg2;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) 
            {sync_reg2,sync_reg1} <= 0;
        else 
            {sync_reg2,sync_reg1} <= {sync_reg1,data_in};

    assign sync_data_out = sync_reg2;
endmodule

module rptr_empty #(
    parameter ADDRSIZE = 4
) (
    input logic rclk,
    input logic rrst_n,
    input logic rinc,
    input logic [ADDRSIZE :0] rq2_wptr,

    output logic [ADDRSIZE-1:0] raddr,
    output logic [ADDRSIZE :0] rptr,
    output logic rempty
);
    logic [ADDRSIZE:0] rbin;
    wire [ADDRSIZE:0] rgraynext, rbinnext;
    // pointers
    always_ff @(posedge rclk or negedge rrst_n)
        if (!rrst_n) begin 
            {rbin, rptr} <= 0; 
        end else begin 
            rbin <= rbinnext;
            rptr <= rgraynext;
        end

  	assign rbinnext = rbin + (rinc & ~rempty);
	assign rgraynext = (rbinnext>>1) ^ rbinnext;
    assign raddr = rbin[ADDRSIZE-1:0];
    //---------------------------------------------------------------
    // FIFO empty when the next rptr == synchronized wptr or on reset
    //---------------------------------------------------------------
    assign rempty_val = (rgraynext == rq2_wptr);
    always_ff @(posedge rclk or negedge rrst_n)
        if (!rrst_n) rempty <= 1'b1;
        else rempty <= rempty_val;
endmodule

module wptr_full #(parameter ADDRSIZE = 4)
(
    input logic wclk, 
    input logic wrst_n,
    input logic winc,
    input logic [ADDRSIZE :0] wq2_rptr,

    output logic [ADDRSIZE-1:0] waddr,
    output logic [ADDRSIZE :0] wptr,
    output logic wfull
);
    logic [ADDRSIZE:0] wbin;
    wire [ADDRSIZE:0] wgraynext, wbinnext;
    // pointers
    always_ff @(posedge wclk or negedge wrst_n)
        if (!wrst_n) begin 
            {wbin, wptr} <= 0; 
        end else begin
             wbin <= wbinnext;
             wptr <= wgraynext;
        end

  	assign wbinnext = wbin + (winc & ~wfull);
	assign wgraynext = (wbinnext>>1) ^ wbinnext;
  
    // Memory write-address pointer (okay to use binary to address memory)
    assign waddr = wbin[ADDRSIZE-1:0];

    //------------------------------------------------------------------
    // Simplified version of the three necessary full-tests:
    // assign wfull_val=((wgnext[ADDRSIZE] !=wq2_rptr[ADDRSIZE] ) &&
    // (wgnext[ADDRSIZE-1] !=wq2_rptr[ADDRSIZE-1]) &&
    // (wgnext[ADDRSIZE-2:0]==wq2_rptr[ADDRSIZE-2:0]));
    //------------------------------------------------------------------
    assign wfull_val = (wgraynext=={~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});

    always_ff @(posedge wclk or negedge wrst_n)
        if (!wrst_n) wfull <= 1'b0;
        else wfull <= wfull_val;
endmodule