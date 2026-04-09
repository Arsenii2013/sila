module xadc_wrapper (
    input  logic                                 app_clk,
    input  logic                                 app_aresetn,
    axi4_lite_if.s                               mmr
);

    xadc_wizard xadc_inst (
        .s_axi_aclk(app_clk),        // input wire s_axi_aclk
        .s_axi_aresetn(app_aresetn),  // input wire s_axi_aresetn
        .s_axi_awaddr(mmr.awaddr),    // input wire [10 : 0] s_axi_awaddr
        .s_axi_awvalid(mmr.awvalid),  // input wire s_axi_awvalid
        .s_axi_awready(mmr.awready),  // output wire s_axi_awready
        .s_axi_wdata(mmr.wdata),      // input wire [31 : 0] s_axi_wdata
        .s_axi_wstrb(mmr.wstrb),      // input wire [3 : 0] s_axi_wstrb
        .s_axi_wvalid(mmr.wvalid),    // input wire s_axi_wvalid
        .s_axi_wready(mmr.wready),    // output wire s_axi_wready
        .s_axi_bresp(mmr.bresp),      // output wire [1 : 0] s_axi_bresp
        .s_axi_bvalid(mmr.bvalid),    // output wire s_axi_bvalid
        .s_axi_bready(mmr.bready),    // input wire s_axi_bready
        .s_axi_araddr(mmr.araddr),    // input wire [10 : 0] s_axi_araddr
        .s_axi_arvalid(mmr.arvalid),  // input wire s_axi_arvalid
        .s_axi_arready(mmr.arready),  // output wire s_axi_arready
        .s_axi_rdata(mmr.rdata),      // output wire [31 : 0] s_axi_rdata
        .s_axi_rresp(mmr.rresp),      // output wire [1 : 0] s_axi_rresp
        .s_axi_rvalid(mmr.rvalid),    // output wire s_axi_rvalid
        .s_axi_rready(mmr.rready),    // input wire s_axi_rready
        .ip2intc_irpt(),
        .vp_in(0),
        .vn_in(0),
        .channel_out(),
        .eoc_out(),
        .alarm_out(),
        .eos_out(),
        .busy_out()
    );
endmodule