`include "axi4_lite_if.svh"

module axi4_lite_dw_translator
#(
    parameter AW = 32
)
(
    axi4_lite_if.s  m,
    axi4_lite_if.m s
);
`timescale 1ns / 1ps

localparam L = 8'h0F;
localparam H = 8'hF0;

typedef logic [AW-1:0] addr_t;
typedef logic [   7:0] mask_t;
typedef logic [  31:0] data_t;  

data_t data_l;
data_t data_h;

assign data_l = m.wdata[31:0];
assign data_h = m.wdata[63:32];

always_comb begin
    s.awaddr  = m.wstrb == L ? m.awaddr : (m.awaddr | addr_t'(3'b100));
    s.awprot  = m.awprot;
    s.awvalid = m.awvalid;
    m.awready = s.awready;
    s.wdata   = m.wstrb == L ? data_l : data_h;
    s.wstrb   = 4'hF;
    s.wvalid  = m.wvalid;
    m.wready  = s.wready;
    m.bresp   = s.bresp;
    m.bvalid  = s.bvalid;
    s.bready  = m.bready;
    s.araddr  = m.araddr;
    s.arprot  = m.arprot;
    s.arvalid = m.arvalid;
    m.arready = s.arready;
    m.rdata[31:0]   = s.rdata;
    m.rdata[63:32]   = s.rdata;
    m.rresp   = s.rresp;
    m.rvalid  = s.rvalid;
    s.rready  = m.rready;
end

endmodule 