`include "topHSSR.svh"
//`include "gtx.svh"

package HSSR_board_pkg;
    import diff_io_pkg::polarity_t;
    import diff_io_pkg::POSITIVE;
    import diff_io_pkg::NEGATIVE;

    import diff_io_pkg::diff_io_mode_t;
    import diff_io_pkg::PRECISE;
    import diff_io_pkg::COMMON;

    localparam START_N                 = 16;

    localparam polarity_t START_POLARITY [START_N] = 
        '{POSITIVE, NEGATIVE, POSITIVE, NEGATIVE, 
          NEGATIVE, NEGATIVE, NEGATIVE, POSITIVE, 
          NEGATIVE, POSITIVE, NEGATIVE, NEGATIVE, 
          NEGATIVE, POSITIVE, NEGATIVE, NEGATIVE};

    localparam diff_io_mode_t START_MODES [START_N] = 
        '{PRECISE, PRECISE, PRECISE, PRECISE, 
          PRECISE, PRECISE, PRECISE, PRECISE, 
          COMMON,  COMMON,  COMMON,  COMMON, 
          COMMON,  COMMON,  COMMON,  COMMON};

    localparam LED_N                   = 4;

    localparam IO_N                    = 32;
endpackage

module topHSSR(
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
    input  logic       MGTREFCLK_n,
    input  logic       MGTREFCLK_p,

    input  logic       SFP_RX_N     [gtx::HSSR_PORT_N],
    input  logic       SFP_RX_P     [gtx::HSSR_PORT_N],
    output logic       SFP_TX_N     [gtx::HSSR_PORT_N],
    output logic       SFP_TX_P     [gtx::HSSR_PORT_N],
    output logic       SFP_TX_DIS   [gtx::HSSR_PORT_N],
    input  logic       SFP_TX_FAULT [gtx::HSSR_PORT_N],
    input  logic       SFP_DETECT   [gtx::HSSR_PORT_N],
    input  logic       SFP_RX_LOS   [gtx::HSSR_PORT_N],
    output logic       SFP_RS0,
    output logic       SFP_RS1,
    inout  logic       SFP_SDA      [gtx::HSSR_PORT_N],
    inout  logic       SFP_SCL      [gtx::HSSR_PORT_N],

    //-----------Clocking------------\\
    input  logic       SYS_CLK_n,
    input  logic       SYS_CLK_p,

    output logic       RXCLK_n,
    output logic       RXCLK_p,
    input  logic       DM_CLK_n,
    input  logic       DM_CLK_p,
    output logic       DC_CLK_n,
    output logic       DC_CLK_p,
    input  logic       FPGA_OUTCLK_n,
    input  logic       FPGA_OUTCLK_p,

    //-------Clocking control--------\\
    inout  logic       SI570_SDA,
    inout  logic       SI570_SCL,

    output logic       PLL_RST_N,
    inout  logic       PLL1_SDA,
    inout  logic       PLL1_SCL,
    output logic       PLL1_IN_SEL0,
    output logic       PLL1_IN_SEL1,
    input  logic       PLL1_LOL_N,
    inout  logic       PLL2_SDA,
    inout  logic       PLL2_SCL,
    input  logic       PLL2_LOL_N,

    //-----------Outputs-------------\\
    inout  logic       START_p      [HSSR_board_pkg::START_N],
    inout  logic       START_n      [HSSR_board_pkg::START_N],
    inout  logic       IO           [HSSR_board_pkg::IO_N],

    //-------------LEDs--------------\\
    output logic       LED          [HSSR_board_pkg::LED_N],
    output logic       SFP_LED_LINK [gtx::HSSR_PORT_N],
    output logic       SFP_LED_ACT  [gtx::HSSR_PORT_N]
);
    logic POR_reset;
    logic PS_clk, PS_aresetn, PS_reset;

    logic app_clk;
    logic app_aresetn[HSSR_aresetn_params::DEV_CNT];
    logic app_reset[HSSR_reset_params::DEV_CNT];

    axi4_lite_if #(
        .DW(axi_params::GP0_DATA_W),
        .AW(axi_params::GP0_ADDR_W)
    ) GP_0();

    axi4_lite_if #(
        .DW(axi_params::MMR_DATA_W),
        .AW(axi_params::MMR_ADDR_W)
    ) mmr[axi_params::MMR_DEV_CNT2]();

    EMIO_tri_state_if EMIO_0[emio_params::EMIO_0_WIDTH]();

    gtx_if evr_gtx_if[gtx::HSSR_PORT_N]();

    logic sysclk;
    logic sysclk_ds;
    IBUFDS sysclk_ibufds_inst (.O(sysclk_ds), .I(SYS_CLK_p), .IB(SYS_CLK_n));
    BUFG sysclk_BUFG_inst ( .O(sysclk), .I(sysclk_ds));

    logic beacon_clk;
    logic beacon_clk_ds;
    IBUFDS beacon_clk_ibufds_inst (.O(beacon_clk_ds), .I(DM_CLK_p), .IB(DM_CLK_n));
    BUFG beacon_clk_BUFG_inst ( .O(beacon_clk), .I(beacon_clk_ds));

    logic clear_clk;
    logic clear_clk_ds;
    IBUFDS clear_clk_ibufds_inst (.O(clear_clk_ds), .I(FPGA_OUTCLK_p), .IB(FPGA_OUTCLK_n));
    BUFG clear_clk_BUFG_inst ( .O(clear_clk), .I(clear_clk_ds));

    HSSR_system_reset system_reset_i (
        .app_clk(app_clk),
        .PS_reset(PS_reset),
        .PS_aresetn(PS_aresetn),
        .gtx_aligned(evr_gtx_if[0].aligned),
        .PLL1_LOL(!PLL1_LOL_N),
        .PLL2_LOL(!PLL2_LOL_N),

        .app_reset(app_reset),
        .app_aresetn(app_aresetn)
    );

    axi_crossbar #(
        .N(axi_params::MMR_DEV_CNT2),
        .AW(axi_params::GP0_ADDR_W),
        .DW(axi_params::GP0_DATA_W)
    ) axi_crossbar_i (
        .aclk(app_clk),
        .aresetn(app_aresetn[HSSR_aresetn_params::COMMON]),
        .m(GP_0),
        .s(mmr)
    );

    evn::ev_t    ev;
    evn::delay_t delay;

    device_info #(
        .DEVICE("HSSR")
    ) device_info_i (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSR_reset_params::DEVICE_INFO]),
        .mmr(mmr[HSSR_axi_params::DEVICE_INFO])
    );


    timestamper #(
        .CYCLE_CNT_WIDTH(64), 
        .PULSE_CNT_WIDTH(32)
    ) timestamper_i (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSR_reset_params::TIMESTAMPER]),
        .mmr(mmr[HSSR_axi_params::TIMESTAMPER]),
        .cycle_start_val(delay >> 16), // ожидаю, что задержка получилась целеая
        .cycle_cnt(),
        .pulse_cnt(),
        .ev(ev)
    );

    i2c_tri_state_if I2C_0();

    PS_wrapper_sv #(
        .GP0_ADDR_W(axi_params::GP0_ADDR_W),
        .GP0_DATA_W(axi_params::GP0_DATA_W),
        .MMR_DEV_CNT2(axi_params::MMR_DEV_CNT2),
        .DEVICE("HSSR")
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
        .app_aresetn(app_aresetn[HSSR_aresetn_params::COMMON]),
        .app_clk(app_clk)
    );

    i2c_mux #(
        .SFP_N(gtx::HSSR_PORT_N),
        .DEVICE("HSSR")
    ) i2c_mux_inst (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSR_reset_params::COMMON]),
        .mmr(mmr[HSSR_axi_params::I2C_MUX]),

        .I2C_s(I2C_0),

        .SI570_SDA(SI570_SDA),
        .SI570_SCL(SI570_SCL),
        .PLL1_SDA(PLL1_SDA),
        .PLL1_SCL(PLL1_SCL),
        .PLL2_SDA(PLL2_SDA),
        .PLL2_SCL(PLL2_SCL),
        .NST117_SDA(IO[2]),
        .NST117_SCL(IO[0]),
        .SFP_SDA(SFP_SDA),
        .SFP_SCL(SFP_SCL)
    );

    logic soft_reset_sync;

    xpm_cdc_async_rst sofr_reset_cdc_i(
        .dest_clk(PS_clk),
        .dest_arst(soft_reset_sync),
        .src_arst(app_reset[HSSR_reset_params::GTWIZARD])
    );

    gtwizard_wrapper #(
        .DEVICE("HSSR"),
        .PORT_N(gtx::HSSR_PORT_N)
    ) gtwizard_i (
        .refclk_n(MGTREFCLK_n),
        .refclk_p(MGTREFCLK_p),
        .sysclk(PS_clk),
        .soft_reset(soft_reset_sync),
        .sfp_loss(SFP_RX_LOS),
        .rx_n(SFP_RX_N),
        .rx_p(SFP_RX_P),
        .tx_n(SFP_TX_N),
        .tx_p(SFP_TX_P),
        .gtx_if(evr_gtx_if)
    );

    logic sfp_tx_dis_inv;
    stable_m #(
        `ifndef SYNTHESIS
            .LEN(1023)
        `else
            .LEN(2**25 - 1)
        `endif
    ) SFP_TX_DIS_stable (
        .clk(evr_gtx_if[0].rx_clk),
        .in(evr_gtx_if[0].aligned),
        .out(sfp_tx_dis_inv)
    );
    assign SFP_TX_DIS[0] = !sfp_tx_dis_inv;
    assign SFP_RS0    = 1;
    assign SFP_RS1    = 1;

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
    assign PLL1_IN_SEL0 = 0;
    stable_m #(
        .LEN(1023)
    ) PLL1_IN_SEL1_stable (
        .clk(evr_gtx_if[0].rx_clk),
        .in(evr_gtx_if[0].aligned),
        .out(PLL1_IN_SEL1)
    );

    ODDRDS #(.POL("N")) RXCLK_ODDRDS_inst(
        .C(evr_gtx_if[0].rx_clk),
        .O(RXCLK_p),
        .OB(RXCLK_n)
    );

    logic dc_clk;

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

    evn::ev_t ev_optic;
    evr #(
        .PORT_N(gtx::HSSR_PORT_N)
    ) evr_i (
        .beacon_clk(beacon_clk),
        .local_clk(local_clk),
        .dc_clk(dc_clk),
        .jc_clk(clear_clk),
        .jc_clk_valid(evr_gtx_if[0].aligned && PLL1_LOL_N && PLL2_LOL_N),
        .gtx_if(evr_gtx_if),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_reset[HSSR_reset_params::EVR]),
        .mmr(mmr[HSSR_axi_params::EVR]),
        
        .ev(ev_optic), 
        .trig('0),

        .delay(delay)
    );

    system_csr system_csr(
        .app_clk(app_clk),
        .app_rst(app_reset[HSSR_reset_params::SYSTEM_CSR]),
        .mmr(mmr[HSSR_axi_params::SYSTEM_CSR]),

        .ev_in(ev_optic),
        .ev_out(ev)
    );

    ODDRDS DC_CLK_ODDRDS_inst(
        .C(dc_clk),
        .O(DC_CLK_p),
        .OB(DC_CLK_n)
    );

    logic set      [HSSR_axi_params::SIG_GEN_N];
    logic clear    [HSSR_axi_params::SIG_GEN_N];
    logic trigger  [HSSR_axi_params::SIG_GEN_N];
    logic cnt_reset[HSSR_axi_params::SIG_GEN_N];
    ev_map #(
        .COMP_N(HSSR_axi_params::EV_COMP_N),
        .SIG_GEN_N(HSSR_axi_params::SIG_GEN_N)
    ) ev_map_i (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSR_reset_params::EV_MAP]),
        .mmr(mmr[HSSR_axi_params::EV_MAP]),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .ev(ev)
    );

    logic gen_out  [HSSR_axi_params::SIG_GEN_N];
    signal_generator #(
        .N(HSSR_axi_params::SIG_GEN_N)
    ) signal_generator_i (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSR_reset_params::SIG_GEN_CTRL]),
        .mmr(mmr[HSSR_axi_params::SIG_GEN_CTRL]),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .gen_out(gen_out)
    );

    logic o1 [HSSR_axi_params::DIFF_IO_N];
    logic o2 [HSSR_axi_params::DIFF_IO_N];
    gen_map #(
        .SIG_GEN_N(HSSR_axi_params::SIG_GEN_N),
        .DIFF_IO_N(HSSR_board_pkg::START_N)
    ) gen_map_i (
        .app_clk(app_clk),
        .app_rst(app_reset[HSSR_reset_params::SIG_GEN_MAP]),
        .mmr(mmr[HSSR_axi_params::SIG_GEN_MAP]),
        .o1(o1),
        .o2(o2),
        .gen_out(gen_out)
    );


    if (HSSR_axi_params::DIFF_IO_N != HSSR_board_pkg::START_N) begin
        $error("Number of diff_io in axi must be equal to number of board START signals");
    end

    logic diff_inputs [HSSR_axi_params::DIFF_IO_N];
    diff_io #(
        .OUTPUT_N(HSSR_board_pkg::START_N),
        .DUPLICATE_N(8),
        .STATIC_POLARITY(HSSR_board_pkg::START_POLARITY),
        .DIFF_IO_MODES(HSSR_board_pkg::START_MODES)
    ) diff_io_i (
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_reset[HSSR_reset_params::DIFF_IO]),
        .iodelayctrl_refclk(sysclk),
        .mmr(mmr[HSSR_axi_params::DIFF_IO]),

        .o1(o1),
        .o2(o2),
        .in_logic(diff_inputs),

        .IO_P(START_p),
        .IO_N(START_n),
        .IO_D('{IO[12], IO[13], IO[17], IO[18], IO[19], IO[20], IO[21], IO[22]}),

        .SER(IO[14]),
        .RCLK(IO[15]),
        .SRCLK(IO[16])
    );


    // SerDes
    assign IO[9]  = 0;
    assign IO[10] = 1;
    assign IO[11] = !IO[5];
    

    HSSR_pretty_leds HSSR_pretty_leds_i(
        .app_clk(app_clk),
        .app_reset(app_reset[HSSR_reset_params::COMMON]),
        .sfp_aligned(evr_gtx_if[0].aligned),
        .ev(ev),
        .diff_inputs(diff_inputs),
        .LED(LED),
        .SFP_LED_LINK(SFP_LED_LINK[0]),
        .SFP_LED_ACT(SFP_LED_ACT[0])
    );

endmodule

module HSSR_pretty_leds(
    input  logic     app_clk,
    input  logic     app_reset,

    input  logic     sfp_aligned,
    input  evn::ev_t ev,
    input  logic     diff_inputs [HSSR_axi_params::DIFF_IO_N],

    output logic     LED         [HSSR_board_pkg::LED_N],
    output logic     SFP_LED_LINK,
    output logic     SFP_LED_ACT
);

    assign SFP_LED_LINK = sfp_aligned;
    pf_m #(
        .WIDTH(10000000),
        .POR("OFF")
    ) sfp_led_act_pf_i (
        .clk(app_clk),
        .in(ev != '0),
        .out(SFP_LED_ACT)
    );

    assign LED[1] = 1;

    blink #(
        .FREQ_HZ(100000000),
        .LED_PERIOD_NS(500000000)
    ) blink1 (
        .reset(app_reset),
        .clk(app_clk),
        .led(LED[0]),
        .sync(ev != 0)
    );

    logic diff_inputs_ored;
    always_comb begin
        diff_inputs_ored = 0;
        for(int i = 0; i < HSSR_axi_params::DIFF_IO_N; i++)
            diff_inputs_ored |= diff_inputs[i];
    end
    pf_m #(
        .WIDTH(10000000),
        .POR("OFF")
    ) led2_pf_i (
        .clk(app_clk),
        .in(diff_inputs_ored),
        .out(LED[2])
    );

    assign LED[3] = 0;
endmodule

module HSSR_system_reset(
    input  logic app_clk,
    input  logic PS_reset,
    input  logic PS_aresetn,
    input  logic gtx_aligned,
    input  logic PLL1_LOL,
    input  logic PLL2_LOL,

    output logic app_reset[HSSR_reset_params::DEV_CNT],
    output logic app_aresetn[HSSR_aresetn_params::DEV_CNT]
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

    logic PLLS_LOL_sync;
    logic opt_link_not_ready;
    always_ff @(posedge app_clk) opt_link_not_ready <= !gtx_aligned || PLLS_LOL_sync;

    xpm_cdc_async_rst PLLS_LOL_cdc_inst (
        .dest_arst(PLLS_LOL_sync),

        .dest_clk(app_clk),
        .src_arst(PLL1_LOL || PLL2_LOL)
    );

    reset_fanout #(
        .N(HSSR_reset_params::DEV_CNT)
    ) reset_fanout_i(
        .clk(app_clk),
        .reset_in(POR_reset || PS_reset_app_clk),
        .reset_out(app_reset)
    );

    reset_fanout #(
        .N(HSSR_aresetn_params::DEV_CNT)
    ) aresetn_fanout_i(
        .clk(app_clk),
        .reset_in(~POR_reset && PS_aresetn_app_clk),
        .reset_out(app_aresetn)
    );

endmodule