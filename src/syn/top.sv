`timescale 1ns/1ns

`include "axi4_lite_if.svh"
`include "top.svh"

module top(
        //-------Processing System-------\\
    `ifdef SYNTHESIS
    inout wire [14:0]   DDR_addr,
    inout wire [2:0]    DDR_ba,
    inout wire          DDR_cas_n,
    inout wire          DDR_ck_n,
    inout wire          DDR_ck_p,
    inout wire          DDR_cke,
    inout wire          DDR_cs_n,
    inout wire [3:0]    DDR_dm,
    inout wire [31:0]   DDR_dq,
    inout wire [3:0]    DDR_dqs_n,
    inout wire [3:0]    DDR_dqs_p,
    inout wire          DDR_odt,
    inout wire          DDR_ras_n,
    inout wire          DDR_reset_n,
    inout wire          DDR_we_n,
    inout wire          FIXED_IO_ddr_vrn,
    inout wire          FIXED_IO_ddr_vrp,
    inout wire [53:0]   FIXED_IO_mio,
    inout wire          FIXED_IO_ps_clk,
    inout wire          FIXED_IO_ps_porb,
    inout wire          FIXED_IO_ps_srstb,
    `endif //SYNTHESIS 

    input  logic       sysclk_n,
    input  logic       sysclk_p,
    output logic [3:0] led
);
    logic sysclk;
    IBUFDS sysclk_ibuf_i (.O(sysclk), .I(sysclk_p), .IB(sysclk_n));


    logic PS_clk, PS_aresetn, PS_reset;
    axi4_lite_if #(.DW(GP0_DATA_W), .AW(GP0_ADDR_W)) GP_0();

    PS_wrapper_sv
    PS_wrapper_i (
        `ifdef SYNTHESIS
        .DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        `endif // SYNTHESIS

        .GP_0(GP_0),
        
        .peripheral_clock(PS_clk),
        .peripheral_aresetn(PS_aresetn),
        .peripheral_reset(PS_reset)
    );

    mem_wrapper
    mem_wrapper_i (
        .aclk(PS_clk),
        .aresetn(PS_aresetn),
        .axi(GP_0),
        .offset('0)
    );

    blink #(
        .FREQ_HZ(200000000),
        .LED_PERIOD_NS(500000000)
    ) blink1 (
        .reset(PS_reset),
        .clk(PS_clk),
        .led(led[0])
    );
    blink #(
        .FREQ_HZ(200000000),
        .LED_PERIOD_NS(1000000000)
    ) blink2 (
        .reset(PS_reset),
        .clk(PS_clk),
        .led(led[1])
    );
    blink #(
        .FREQ_HZ(200000000),
        .LED_PERIOD_NS(1500000000)
    ) blink3 (
        .reset(PS_reset),
        .clk(PS_clk),
        .led(led[2])
    );
    blink #(
        .FREQ_HZ(200000000),
        .LED_PERIOD_NS(2000000000)
    ) blink4 (
        .reset(PS_reset),
        .clk(PS_clk),
        .led(led[3])
    );

endmodule
