`include "topEVR.svh"
//`include "gtx.svh"

package EVR_board_pkg;
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
endpackage

module topEVR(
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

    input  logic       SFP_RX_N     [gtx::EVR_PORT_N],
    input  logic       SFP_RX_P     [gtx::EVR_PORT_N],
    output logic       SFP_TX_N     [gtx::EVR_PORT_N],
    output logic       SFP_TX_P     [gtx::EVR_PORT_N],
    output logic       SFP_TX_DIS   [gtx::EVR_PORT_N],
    input  logic       SFP_TX_FAULT [gtx::EVR_PORT_N],
    input  logic       SFP_DETECT   [gtx::EVR_PORT_N],
    input  logic       SFP_RX_LOS   [gtx::EVR_PORT_N],
    output logic       SFP_RS0,
    output logic       SFP_RS1,
    inout  logic       SFP_SDA      [gtx::EVR_PORT_N],
    inout  logic       SFP_SCL      [gtx::EVR_PORT_N],

    input  logic       SYS_CLK_n,
    input  logic       SYS_CLK_p,

    output logic       RXCLK_n,
    output logic       RXCLK_p,
    input  logic       DM_CLK_n,
    input  logic       DM_CLK_p,
    output logic       DC_CLK_n,
    output logic       DC_CLK_p,

    output logic       LED          [EVR_board_pkg::LED_N],
    output logic       SFP_LED_LINK,
    output logic       SFP_LED_ACT,
    inout  logic       START_p      [EVR_board_pkg::START_N],
    inout  logic       START_n      [EVR_board_pkg::START_N],
    input  logic       FPGA_OUTCLK_n,
    input  logic       FPGA_OUTCLK_p,

    output logic       SER,
    output logic       SRCLK,
    output logic       RCLK,

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
    input  logic       PLL2_LOL_N
);
    logic POR_reset;
    logic PS_clk, PS_aresetn, PS_reset;

    logic app_clk;
    logic app_aresetn[EVR_aresetn_params::DEV_CNT];
    logic app_reset[EVR_reset_params::DEV_CNT];

    axi4_lite_if #(
        .DW(axi_params::GP0_DATA_W),
        .AW(axi_params::GP0_ADDR_W)
    ) GP_0();

    axi4_lite_if #(
        .DW(axi_params::MMR_DATA_W),
        .AW(axi_params::MMR_ADDR_W)
    ) mmr[axi_params::MMR_DEV_CNT2]();

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

    pf_m #(
        .WIDTH(1000),
        .POR("ON")
    ) pf_i (
        .clk(app_clk),
        .in(0),
        .out(POR_reset)
    );

    reset_fanout #(
        .N(EVR_reset_params::DEV_CNT)
    ) reset_fanout_i(
        .clk(app_clk),
        .reset_in(POR_reset || PS_reset),
        .reset_out(app_reset)
    );

    reset_fanout #(
        .N(EVR_aresetn_params::DEV_CNT)
    ) aresetn_fanout_i(
        .clk(app_clk),
        .reset_in(~POR_reset && PS_aresetn),
        .reset_out(app_aresetn)
    );

    axi_crossbar #(
        .N(axi_params::MMR_DEV_CNT2),
        .AW(axi_params::GP0_ADDR_W),
        .DW(axi_params::GP0_DATA_W)
    ) axi_crossbar_i (
        .aclk(app_clk),
        .aresetn(app_aresetn[EVR_aresetn_params::COMMON]),
        .m(GP_0),
        .s(mmr)
    );

    evn::ev_t    ev;
    evn::delay_t delay;

    device_info #(
        .DEVICE("EVR")
    ) device_info_i (
        .app_clk(app_clk),
        .app_rst(app_reset[EVR_reset_params::DEVICE_INFO]),
        .mmr(mmr[EVR_axi_params::DEVICE_INFO])
    );


    timestamper #(
        .CYCLE_CNT_WIDTH(64), 
        .PULSE_CNT_WIDTH(32)
    ) timestamper_i (
        .app_clk(app_clk),
        .app_rst(app_reset[EVR_reset_params::TIMESTAMPER]),
        .mmr(mmr[EVR_axi_params::TIMESTAMPER]),
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
        .SIM_DEVICE("EVR")
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
        
        .peripheral_clock(PS_clk),
        .peripheral_aresetn(PS_aresetn),
        .peripheral_reset(PS_reset),
        .app_aresetn(app_aresetn[EVR_aresetn_params::COMMON]),
        .app_clk(app_clk)
    );

    i2c_mux #(
        .SFP_N(gtx::EVR_PORT_N)
    ) i2c_mux_inst (
        .app_clk(app_clk),
        .app_rst(app_reset[EVR_reset_params::COMMON]),
        .mmr(mmr[EVR_axi_params::I2C_MUX]),

        .I2C_s(I2C_0),

        .SI570_SDA(SI570_SDA),
        .SI570_SCL(SI570_SCL),
        .PLL1_SDA(PLL1_SDA),
        .PLL1_SCL(PLL1_SCL),
        .PLL2_SDA(PLL2_SDA),
        .PLL2_SCL(PLL2_SCL),
        .SFP_SDA(SFP_SDA),
        .SFP_SCL(SFP_SCL)
    );

    localparam GTX_PORTS = gtx::EVR_PORT_N;
    gtx_if evr_gtx_if[GTX_PORTS]();
    logic soft_reset_sync;

    xpm_cdc_async_rst sofr_reset_cdc_i(
        .dest_clk(PS_clk),
        .dest_arst(soft_reset_sync),
        .src_arst(app_reset[EVR_reset_params::GTWIZARD])
    );

    gtwizard_wrapper #(
        .DEVICE("EVR"),
        .PORT_N(GTX_PORTS)
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
    assign SFP_TX_DIS = '{default : 0};
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
        .clk(app_clk),
        .in(evr_gtx_if[0].aligned),
        .out(PLL1_IN_SEL1)
    );

    ODDRDS RXCLK_ODDRDS_inst(
        .C(evr_gtx_if[0].rx_clk),
        .O(RXCLK_p),
        .OB(RXCLK_n)
    );

    evr #(
        .PORT_N(GTX_PORTS)
    ) evr_i (
        .beacon_clk(beacon_clk),
        .local_clk(PS_clk),
        .gtx_if(evr_gtx_if),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_reset[EVR_reset_params::EVR]),
        .mmr(mmr[EVR_axi_params::EVR]),
        
        .ev(ev), 
        .trig('0),

        .delay(delay)
    );

    ODDRDS DC_CLK_ODDRDS_inst(
        .C(app_clk),
        .O(DC_CLK_p),
        .OB(DC_CLK_n)
    );

    logic set      [EVR_axi_params::SIG_GEN_N];
    logic clear    [EVR_axi_params::SIG_GEN_N];
    logic trigger  [EVR_axi_params::SIG_GEN_N];
    logic cnt_reset[EVR_axi_params::SIG_GEN_N];
    ev_map #(
        .COMP_N(EVR_axi_params::EV_COMP_N),
        .SIG_GEN_N(EVR_axi_params::SIG_GEN_N)
    ) ev_map_i (
        .app_clk(app_clk),
        .app_rst(app_reset[EVR_reset_params::EV_MAP]),
        .mmr(mmr[EVR_axi_params::EV_MAP]),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .ev(ev)
    );

    logic gen_out  [EVR_axi_params::SIG_GEN_N];
    signal_generator #(
        .N(EVR_axi_params::SIG_GEN_N)
    ) signal_generator_i (
        .app_clk(app_clk),
        .app_rst(app_reset[EVR_reset_params::SIG_GEN_CTRL]),
        .mmr(mmr[EVR_axi_params::SIG_GEN_CTRL]),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .gen_out(gen_out)
    );

    logic o1 [EVR_axi_params::DIFF_IO_N];
    logic o2 [EVR_axi_params::DIFF_IO_N];
    gen_map #(
        .SIG_GEN_N(EVR_axi_params::SIG_GEN_N),
        .DIFF_IO_N(EVR_board_pkg::START_N)
    ) gen_map_i (
        .app_clk(app_clk),
        .app_rst(app_reset[EVR_reset_params::SIG_GEN_MAP]),
        .mmr(mmr[EVR_axi_params::SIG_GEN_MAP]),
        .o1(o1),
        .o2(o2),
        .gen_out(gen_out)
    );


    if (EVR_axi_params::DIFF_IO_N != EVR_board_pkg::START_N) begin
        $error("Number of diff_io in axi must be equal to number of board START signals");
    end

    logic diff_inputs [EVR_axi_params::DIFF_IO_N];
    diff_io #(
        .OUTPUT_N(EVR_board_pkg::START_N),
        .STATIC_POLARITY(EVR_board_pkg::START_POLARITY),
        .DIFF_IO_MODES(EVR_board_pkg::START_MODES)
    ) diff_io_i (
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_reset[EVR_reset_params::DIFF_IO]),
        .iodelayctrl_refclk(sysclk),
        .mmr(mmr[EVR_axi_params::DIFF_IO]),

        .o1(o1),
        .o2(o2),
        .in_logic(diff_inputs),

        .IO_P(START_p),
        .IO_N(START_n),

        .SER(SER),
        .RCLK(RCLK),
        .SRCLK(SRCLK)
    );

    EVR_pretty_leds EVR_pretty_leds_i(
        .app_clk(app_clk),
        .app_reset(app_reset[EVR_reset_params::COMMON]),
        .sfp_aligned(evr_gtx_if[0].aligned),
        .ev(ev),
        .diff_inputs(diff_inputs),
        .LED(LED),
        .SFP_LED_LINK(SFP_LED_LINK),
        .SFP_LED_ACT(SFP_LED_ACT)
    );

endmodule

module EVR_pretty_leds(
    input  logic     app_clk,
    input  logic     app_reset,

    input  logic     sfp_aligned,
    input  evn::ev_t ev,
    input  logic     diff_inputs [EVR_axi_params::DIFF_IO_N],

    output logic     LED         [EVR_board_pkg::LED_N],
    output logic     SFP_LED_LINK,
    output logic     SFP_LED_ACT
);

    assign SFP_LED_LINK = sfp_aligned;
    pf_m #(
        .WIDTH(12500000),
        .POR("OFF")
    ) sfp_led_act_pf_i (
        .clk(app_clk),
        .in(ev != '0),
        .out(SFP_LED_ACT)
    );

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

    logic diff_inputs_ored;
    always_comb begin
        diff_inputs_ored = 0;
        for(int i = 0; i < EVR_axi_params::DIFF_IO_N; i++)
            diff_inputs_ored |= diff_inputs[i];
    end
    pf_m #(
        .WIDTH(12500000),
        .POR("OFF")
    ) led2_pf_i (
        .clk(app_clk),
        .in(diff_inputs_ored),
        .out(LED[2])
    );

    assign LED[3] = 0;
endmodule
