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

endmodule