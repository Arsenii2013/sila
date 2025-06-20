`timescale 1 ns / 1 ps

`include "axi4_lite_if.svh"
`include "top.svh"

module mem_wrapper 
(
    input logic         aclk,
    input logic         aresetn,
    axi4_lite_if.s      axi,
    input logic [31:0]  offset
);
    typedef logic [12:0] addr_t;
    axi_memory mem(
        .s_axi_aclk(aclk),
        .s_axi_aresetn(aresetn),
        .s_axi_awaddr(addr_t'(axi.awaddr) + addr_t'(offset)),
        .s_axi_awprot(axi.awprot),
        .s_axi_awvalid(axi.awvalid),
        .s_axi_awready(axi.awready),
        .s_axi_wdata(axi.wdata),
        .s_axi_wstrb(axi.wstrb),
        .s_axi_wvalid(axi.wvalid),
        .s_axi_wready(axi.wready),
        .s_axi_bresp(axi.bresp[1:0]),
        .s_axi_bvalid(axi.bvalid),
        .s_axi_bready(axi.bready),
        .s_axi_araddr(addr_t'(axi.araddr) + addr_t'(offset)),
        .s_axi_arprot(axi.arprot),
        .s_axi_arvalid(axi.arvalid),
        .s_axi_arready(axi.arready),
        .s_axi_rdata(axi.rdata),
        .s_axi_rresp(axi.rresp),
        .s_axi_rvalid(axi.rvalid),
        .s_axi_rready(axi.rready)
    );

endmodule
