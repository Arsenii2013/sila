`include "topHSSM.svh"

package HSSM_board_pkg;
    localparam LED_N                   = 4;
endpackage

module topHSSM(
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
    inout wire          PHY0_RST,
    inout wire          PHY1_RST,
    `endif //SYNTHESIS 

    //-------------SFP---------------\\
    input  logic       REFCLK_SFP_n,
    input  logic       REFCLK_SFP_p,
    input  logic       REFCLK_n,
    input  logic       REFCLK_p,

    input  logic       SFP_RX_N     [gtx::HSSM_PORT_N],
    input  logic       SFP_RX_P     [gtx::HSSM_PORT_N],
    output logic       SFP_TX_N     [gtx::HSSM_PORT_N],
    output logic       SFP_TX_P     [gtx::HSSM_PORT_N],
    output logic       SFP_TX_DIS   [gtx::HSSM_PORT_N],
    input  logic       SFP_TX_FAULT [gtx::HSSM_PORT_N],
    input  logic       SFP_RX_LOS   [gtx::HSSM_PORT_N],
    output logic       SFP_RS0,
    output logic       SFP_RS1,
    inout  logic       SFP_SDA      [8],
    inout  logic       SFP_SCL      [8],

    //-----------Clocking------------\\
    input  logic       SYS_CLK_n,
    input  logic       SYS_CLK_p,

    output logic       RXCLK_n,
    output logic       RXCLK_p,
    input  logic       DM_CLK_n,
    input  logic       DM_CLK_p,

    //-------Clocking control--------\\
    inout  logic       SI570_SDA,
    inout  logic       SI570_SCL,

    output logic       PLL_RST_N,
    inout  logic       PLL_SDA,
    inout  logic       PLL_SCL,
    output logic       PLL_IN_SEL0,
    output logic       PLL_IN_SEL1,
    input  logic       PLL_LOL_N,

    //-------------LEDs--------------\\
    output logic       LED          [HSSM_board_pkg::LED_N],
    output logic       SFP_LED_LINK [gtx::HSSM_PORT_N],
    output logic       SFP_LED_ACT  [gtx::HSSM_PORT_N]
);
    logic PS_clk, PS_aresetn, PS_reset;

    logic app_clk;
    logic app_aresetn[HSSM_aresetn_params::DEV_CNT];
    logic app_reset[HSSM_reset_params::DEV_CNT];

    axi4_lite_if #(
        .DW(axi_params::GP0_DATA_W),
        .AW(axi_params::GP0_ADDR_W)
    ) GP_0();
    
    axi4_lite_if #(
        .DW(axi_params::MMR_DATA_W),
        .AW(axi_params::MMR_ADDR_W)
    ) mmr[axi_params::MMR_DEV_CNT2]();

    EMIO_tri_state_if EMIO_0[emio_params::EMIO_0_WIDTH]();

    logic sysclk;
    logic sysclk_ds;
    IBUFDS sysclk_ibuf_i (.O(sysclk_ds), .I(SYS_CLK_p), .IB(SYS_CLK_n));
    BUFG sysclk_BUFG_inst ( .O(sysclk), .I(sysclk_ds));

    logic beacon_clk;
    logic beacon_clk_ds;
    IBUFDS beacon_clk_ibufds_inst (.O(beacon_clk_ds), .I(DM_CLK_p), .IB(DM_CLK_n));
    BUFG beacon_clk_BUFG_inst ( .O(beacon_clk), .I(~beacon_clk_ds));

    HSSM_system_reset system_reset_i (
        .app_clk(app_clk),
        .PS_reset(PS_reset),
        .PS_aresetn(PS_aresetn),
        .app_reset(app_reset),
        .app_aresetn(app_aresetn)
    );

    axi_crossbar #(
        .N(axi_params::MMR_DEV_CNT2),
        .AW(axi_params::GP0_ADDR_W),
        .DW(axi_params::GP0_DATA_W)
    ) axi_crossbar_i (
        .aclk(app_clk),
        .aresetn(app_aresetn[HSSM_aresetn_params::COMMON]),
        .m(GP_0),
        .s(mmr)
    );

    evn::ev_t ev;
    
    device_info #(
        .DEVICE("HSSM")
    ) device_info_i (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSM_reset_params::DEVICE_INFO]),
        .mmr(mmr[HSSM_axi_params::DEVICE_INFO])
    );

    logic [63:0] cycle_cnt;
    logic [31:0] pulse_cnt;

    timestamper #(
        .CYCLE_CNT_WIDTH(64), 
        .PULSE_CNT_WIDTH(32)
    ) timestamper_i (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSM_reset_params::TIMESTAMPER]),
        .mmr(mmr[HSSM_axi_params::TIMESTAMPER]),
        .cycle_start_val('0),
        .cycle_cnt(cycle_cnt),
        .pulse_cnt(pulse_cnt),
        .ev(ev)
    );

    i2c_tri_state_if I2C_0();

    PS_wrapper_sv #(
        .GP0_ADDR_W(axi_params::GP0_ADDR_W),
        .GP0_DATA_W(axi_params::GP0_DATA_W),
        .MMR_DEV_CNT2(axi_params::MMR_DEV_CNT2),
        .SIM_DEVICE("HSSM")
    ) PS_wrapper_i (
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
        .I2C_0(I2C_0),
        .EMIO_0(EMIO_0),
        
        .peripheral_clock(PS_clk),
        .peripheral_aresetn(PS_aresetn),
        .peripheral_reset(PS_reset),
        .app_aresetn(app_aresetn[HSSM_aresetn_params::COMMON]),
        .app_clk(app_clk)
    );
    `ifdef SYNTHESIS
    IOBUF PHY0_RST_IOBUF_inst (
        .O(EMIO_0[0].i),
        .IO(PHY0_RST),
        .I(EMIO_0[0].o),
        .T(EMIO_0[0].t)
    );
    IOBUF PHY1_RST_IOBUF_inst (
        .O(EMIO_0[1].i),
        .IO(PHY1_RST),
        .I(EMIO_0[1].o),
        .T(EMIO_0[1].t)
    );
    `endif // SYNTHESIS

    i2c_mux #(
        .SFP_N(8),
        .DEVICE("HSSM")
    ) i2c_mux_inst (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSM_reset_params::COMMON]),
        .mmr(mmr[HSSM_axi_params::I2C_MUX]),

        .I2C_s(I2C_0),

        .SI570_SDA(SI570_SDA),
        .SI570_SCL(SI570_SCL),
        .PLL1_SDA(PLL_SDA),
        .PLL1_SCL(PLL_SCL),
        .SFP_SDA(SFP_SDA),
        .SFP_SCL(SFP_SCL)
    );

    localparam GTX_PORTS = gtx::HSSM_PORT_N;
    logic sfp_loss [GTX_PORTS];
    gtx_if evg_gtx_if[GTX_PORTS]();
    logic soft_reset_sync;

    xpm_cdc_async_rst sofr_reset_cdc_i(
        .dest_clk(PS_clk),
        .dest_arst(soft_reset_sync),
        .src_arst(app_reset[HSSM_reset_params::GTWIZARD])
    );

    gtwizard_wrapper #(
        .DEVICE("HSSM"),
        .PORT_N(GTX_PORTS)
    ) gtwizard_i (
        .refclk_n(REFCLK_n),
        .refclk_p(REFCLK_p),
        .sysclk(PS_clk), 
        .soft_reset(soft_reset_sync),
        .sfp_loss(SFP_RX_LOS),
        .rx_n(SFP_RX_N),
        .rx_p(SFP_RX_P),
        .tx_n(SFP_TX_N),
        .tx_p(SFP_TX_P),
        .gtx_if(evg_gtx_if)
    );
    logic pll_lol_sync;
    xpm_cdc_sync_rst pll_lol_cdc_inst (
        .dest_rst(pll_lol_sync),
        .dest_clk(app_clk),
        .src_rst(!PLL_LOL_N)
    );
    logic sfp_tx_dis_inv;
    stable_m #(
        .LEN(1023)
    ) SFP_TX_DIS_stable (
        .clk(app_clk),
        .in(!pll_lol_sync),
        .out(sfp_tx_dis_inv)
    );
    assign SFP_TX_DIS = '{default : !sfp_tx_dis_inv};
    assign SFP_RS0    = 1;
    assign SFP_RS1    = 1;

    ODDRDS RXCLK_ODDRDS_inst(
        .C(evg_gtx_if[0].rx_clk),
        .O(RXCLK_p),
        .OB(RXCLK_n)
    );

    logic pll_rst;
    pf_m #(
        .WIDTH(125000),
        .POR("ON")
    ) pll_rst_pf (
        .clk(app_clk),
        .in(0),
        .out(pll_rst)
    );
    assign PLL_RST_N    = !pll_rst;
    assign PLL_IN_SEL0 = 1;
    assign PLL_IN_SEL1 = 0;

    logic local_clk;
    logic clk_fb_buf;
    logic clk_fb;
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(7.0), 
        .CLKFBOUT_PHASE(0.0),
        .CLKIN1_PERIOD(5.0),
        .CLKOUT0_DIVIDE_F(8.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),
        .CLKOUT4_CASCADE("FALSE"),
        .DIVCLK_DIVIDE(1)
    ) local_clk_MMCME2_BASE_inst (
        .CLKOUT0(local_clk),
        .CLKFBOUT(clk_fb_buf),
        .CLKIN1(sysclk),
        .PWRDWN(0),
        .RST(0),
        .CLKFBIN(clk_fb)
    );
    BUFG clk_fb_bufg (
        .O(clk_fb),
        .I(clk_fb_buf)
    );

    evg #(
        .PORT_N(GTX_PORTS)
    ) evg_i (
        .beacon_clk(beacon_clk),
        .local_clk(local_clk), 
        .gtx_refclk_valid(PLL_LOL_N),
        .gtx_if(evg_gtx_if),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_reset[HSSM_reset_params::HSSM]),
        .mmr(mmr[HSSM_axi_params::HSSM]),
        
        .ev(ev), 
        .trig()
    );
    /*gtx_if_ila gtx_if_ila_i(
        .gtx_if(evg_gtx_if[0]),
        .app_clk(app_clk)
    );*/

    event_generator #(
        .EV_SEQ_N(HSSM_axi_params::EV_SEQ_N)
    ) event_generator_i (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSM_reset_params::EV_SEQ_CTRL]),
        .mmr_ctrl(mmr[HSSM_axi_params::EV_SEQ_CTRL]),
        .mmr_mem(mmr[HSSM_axi_params::EV_SEQ_0 +: HSSM_axi_params::EV_SEQ_N]),

        .ev(ev)
    );

    logic sfp_aligned[gtx::HSSM_PORT_N];
    generate
    for(genvar i = 0; i < gtx::HSSM_PORT_N; i++) begin
        assign sfp_aligned[i] = evg_gtx_if[i].aligned;
    end
    endgenerate
    HSSM_pretty_leds HSSM_pretty_leds_i(
        .app_clk(app_clk),
        .app_reset(app_reset[HSSM_reset_params::COMMON]),
        .sfp_aligned(sfp_aligned),
        .ev(ev),
        .LED(LED),
        .SFP_LED_LINK(SFP_LED_LINK),
        .SFP_LED_ACT(SFP_LED_ACT)
    );

endmodule


module HSSM_pretty_leds(
    input  logic     app_clk,
    input  logic     app_reset,

    input  logic     sfp_aligned[gtx::HSSM_PORT_N],
    input  evn::ev_t ev,

    output logic     LED          [HSSM_board_pkg::LED_N],
    output logic     SFP_LED_LINK [gtx::HSSM_PORT_N],
    output logic     SFP_LED_ACT  [gtx::HSSM_PORT_N]
);

    assign SFP_LED_LINK = sfp_aligned;
    logic sfp_act;
    pf_m #(
        .WIDTH(12500000),
        .POR("OFF")
    ) sfp_led_act_pf_i (
        .clk(app_clk),
        .in(ev != '0),
        .out(sfp_act)
    );
    generate
    for(genvar i = 0; i < gtx::HSSM_PORT_N; i++) begin
        assign SFP_LED_ACT[i] = sfp_act && sfp_aligned[i];
    end
    endgenerate

    assign LED[0] = 1;

    blink #(
        .FREQ_HZ(125000000),
        .LED_PERIOD_NS(500000000)
    ) blink1 (
        .reset(app_reset),
        .clk(app_clk),
        .led(LED[1]),
        .sync(ev != 0)
    );

    assign LED[2] = 0;
    assign LED[3] = 0;
endmodule

module HSSM_system_reset(
    input  logic app_clk,
    input  logic PS_clk,
    input  logic PS_reset,
    input  logic PS_aresetn,

    output logic app_reset[HSSM_reset_params::DEV_CNT],
    output logic app_aresetn[HSSM_aresetn_params::DEV_CNT]
);

    logic POR_reset;
    logic PS_reset_app_clk, PS_aresetn_app_clk;

    pf_m #(
        .WIDTH(1000),
        .POR("ON")
    ) pf_i (
        .clk(app_clk),
        .in(0),
        .out(POR_reset)
    );

    xpm_cdc_sync_rst PS_reset_cdc_inst (
        .dest_rst(PS_reset_app_clk),

        .dest_clk(app_clk),
        .src_rst(PS_reset)
    );
    xpm_cdc_sync_rst PS_aresetn_cdc_inst (
        .dest_rst(PS_aresetn_app_clk),

        .dest_clk(app_clk),
        .src_rst(PS_aresetn)
    );

    reset_fanout #(
        .N(HSSM_reset_params::DEV_CNT)
    ) reset_fanout_i(
        .clk(app_clk),
        .reset_in(POR_reset || PS_reset_app_clk),
        .reset_out(app_reset)
    );

    reset_fanout #(
        .N(HSSM_aresetn_params::DEV_CNT)
    ) aresetn_fanout_i(
        .clk(app_clk),
        .reset_in(~POR_reset && PS_aresetn_app_clk),
        .reset_out(app_aresetn)
    );

endmodule