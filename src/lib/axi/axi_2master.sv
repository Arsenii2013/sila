`include "axi4_lite_if.svh"

module axi_2master( 
    input logic    aclk,
    input logic    aresetn,

    axi4_lite_if.s m1,
    axi4_lite_if.s m2,
    axi4_lite_if.m s
);

    qspi_crossbar spi_crossbar_m(
        .aclk(aclk),
        .aresetn(aresetn),

        .s_axi_awaddr({m1.awaddr, m2.awaddr}),
        .s_axi_awprot({m1.awprot, m2.awprot}),
        .s_axi_awvalid({m1.awvalid, m2.awvalid}),
        .s_axi_awready({m1.awready, m2.awready}),
        .s_axi_wdata({m1.wdata, m2.wdata}),
        .s_axi_wstrb({m1.wstrb, m2.wstrb}),
        .s_axi_wvalid({m1.wvalid, m2.wvalid}),
        .s_axi_wready({m1.wready, m2.wready}),
        .s_axi_bresp({m1.bresp, m2.bresp}),
        .s_axi_bvalid({m1.bvalid, m2.bvalid}),
        .s_axi_bready({m1.bready, m2.bready}),
        .s_axi_araddr({m1.araddr, m2.araddr}),
        .s_axi_arprot({m1.arprot, m2.arprot}),
        .s_axi_arvalid({m1.arvalid, m2.arvalid}),
        .s_axi_arready({m1.arready, m2.arready}),
        .s_axi_rdata({m1.rdata, m2.rdata}),
        .s_axi_rresp({m1.rresp, m2.rresp}),
        .s_axi_rvalid({m1.rvalid, m2.rvalid}),
        .s_axi_rready({m1.rready, m2.rready}),

        .m_axi_awaddr(s.awaddr),
        .m_axi_awprot(s.awprot),
        .m_axi_awvalid(s.awvalid),
        .m_axi_awready(s.awready),
        .m_axi_wdata(s.wdata),
        .m_axi_wstrb(s.wstrb),
        .m_axi_wvalid(s.wvalid),
        .m_axi_wready(s.wready),
        .m_axi_bresp(s.bresp),
        .m_axi_bvalid(s.bvalid),
        .m_axi_bready(s.bready),
        .m_axi_araddr(s.araddr),
        .m_axi_arprot(s.arprot),
        .m_axi_arvalid(s.arvalid),
        .m_axi_arready(s.arready),
        .m_axi_rdata(s.rdata),
        .m_axi_rresp(s.rresp),
        .m_axi_rvalid(s.rvalid),
        .m_axi_rready(s.rready)
    );

endmodule