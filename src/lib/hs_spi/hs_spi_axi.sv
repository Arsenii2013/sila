`include "axi4_lite_if.svh"

module hs_spi_master_axi_m
#(
    parameter AW           = 10,
    parameter DW           = 32,
    parameter SPI_W        = 4,
    parameter DUMMY_CYCLES = 4
)
(
    input  logic              aclk,
    input  logic              aresetn,
    input  logic              oclk,
    output logic              idle,

    axi4_lite_if.s            bus_axi,    
    
    output logic              SCK,
    output logic              CSn,
    input  logic  [SPI_W-1:0] MISO,
    output logic  [SPI_W-1:0] MOSI

);

    avmm_if #(.AW(AW), .DW(DW), .MAX_BURST(1)) bus_avmm();

    axi2avmm axi2avmm_m(
        .s_axi_aclk(aclk),
        .s_axi_aresetn(aresetn),

        .s_axi_awaddr(bus_axi.awaddr),
        .s_axi_awvalid(bus_axi.awvalid),
        .s_axi_awready(bus_axi.awready),
        .s_axi_wdata(bus_axi.wdata),
        .s_axi_wstrb(bus_axi.wstrb),
        .s_axi_wvalid(bus_axi.wvalid),
        .s_axi_wready(bus_axi.wready),
        .s_axi_bresp(bus_axi.bresp),
        .s_axi_bvalid(bus_axi.bvalid),
        .s_axi_bready(bus_axi.bready),
        .s_axi_araddr(bus_axi.araddr),
        .s_axi_arvalid(bus_axi.arvalid),
        .s_axi_arready(bus_axi.arready),
        .s_axi_rdata(bus_axi.rdata),
        .s_axi_rresp(bus_axi.rresp),
        .s_axi_rvalid(bus_axi.rvalid),
        .s_axi_rready(bus_axi.rready),

        .avm_address(bus_avmm.address),
        .avm_write(bus_avmm.write),
        .avm_read(bus_avmm.read),
        .avm_byteenable(bus_avmm.byteenable),
        .avm_writedata(bus_avmm.writedata),
        .avm_readdata(bus_avmm.readdata),
        .avm_readdatavalid(bus_avmm.readdatavalid),
        .avm_burstcount(bus_avmm.burstcount),
        .avm_waitrequest(bus_avmm.waitrequest)
    );

    hs_spi_master_avmm_m #(
        .AW(AW),
        .DW(DW),
        .MAX_BURST(1),
        .SPI_W(SPI_W),
        .DUMMY_CYCLES(DUMMY_CYCLES)
    )
    hs_spi_master_m
    (
        .clk(aclk),
        .oclk(oclk),
        .rst(~aresetn),
        .idle(idle),
        .bus(bus_avmm),
        .SCK(SCK),
        .CSn(CSn),
        .MISO(MISO),
        .MOSI(MOSI)
    );

endmodule 