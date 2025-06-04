`timescale 1ns/1ns

`include "axi4_lite_if.svh"
`include "top.svh"
`include "cfg_params.svh"

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

        //-------------SFP---------------\\
    input  logic       REFCLK_SFP_n,
    input  logic       REFCLK_SFP_p,

    input  logic       sfp_rx_n[4],
    input  logic       sfp_rx_p[4],
    output logic       sfp_tx_n[4],
    output logic       sfp_tx_p[4],
    output logic [1:0] sfp_tx_disable,

    input  logic       sysclk_n,
    input  logic       sysclk_p,
    output logic [3:0] led
);
    logic app_clk;
    logic app_aresetn;
    logic app_reset;

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

    assign app_clk     = PS_clk;

    logic POR_reset;

    pf_m #(
        .WIDTH(1000),
        .POR("ON")
    ) pf_i (
        .clk(app_clk),
        .in(0),
        .out(POR_reset)
    );

    assign app_aresetn = PS_aresetn && ~POR_reset;
    assign app_reset   = PS_reset || POR_reset;

    mem_wrapper
    mem_wrapper_i (
        .aclk(app_clk),
        .aresetn(app_aresetn),
        .axi(GP_0),
        .offset('0)
    );

    blink #(
        .FREQ_HZ(125000000),
        .LED_PERIOD_NS(500000000)
    ) blink1 (
        .reset(app_reset),
        .clk(app_clk),
        .led(led[0])
    );
    
    logic        sfp_reset;
    logic        sfp_tx_clk[4];
    logic        sfp_rx_clk[4];
    logic [31:0] sfp_tx_data[4];
    logic [31:0] sfp_rx_data[4];
    logic [3:0]  sfp_tx_is_k[4];
    logic [3:0]  sfp_rx_is_k[4];
    logic        tx_reset_done[4];
    logic        rx_reset_done[4];
    logic        sfp_aligned[4];

    assign sfp_tx_disable = '0;

    gtwizard_wrapper gtwizard_i (
        .refclk_n(REFCLK_SFP_n),
        .refclk_p(REFCLK_SFP_p),
        .sysclk(app_clk), 
        .soft_reset(app_reset),
        .tx_reset_done(tx_reset_done),
        .rx_reset_done(rx_reset_done),
        .tx_clk(sfp_tx_clk),
        .rx_clk(sfp_rx_clk),
        .aligned(sfp_aligned),
        .tx_data(sfp_tx_data),
        .rx_data(sfp_rx_data),
        .txcharisk(sfp_tx_is_k),
        .rxcharisk(sfp_rx_is_k),
        .rx_n(sfp_rx_n),
        .rx_p(sfp_rx_p),
        .tx_n(sfp_tx_n),
        .tx_p(sfp_tx_p)
    );

    assign led[1] = tx_reset_done[0];
    assign led[2] = rx_reset_done[0];
    assign led[3] = sfp_aligned[0];

    genvar i;
    generate
    for (i=0; i < 4; i++) begin
        frame_gen frame_gen_i (
            .clk(sfp_tx_clk[i]),
            .rst(app_reset) ,
            .tx_data(sfp_tx_data[i]),
            .txcharisk(sfp_tx_is_k[i]),
            .data('h01234567)
        );
    end
    endgenerate

endmodule
