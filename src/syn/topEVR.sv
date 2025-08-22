`timescale 1ns/1ns

`include "axi4_lite_if.svh"
`include "axi_stream.svh"
`include "top.svh"
`include "topEVR.svh"
`include "cfg_params.svh"

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

    input  logic       sfp_rx_n[4],
    input  logic       sfp_rx_p[4],
    output logic       sfp_tx_n[4],
    output logic       sfp_tx_p[4],
    output logic [1:0] sfp_tx_disable,

    input  logic       sysclk_n,
    input  logic       sysclk_p,
    output logic [3:0] led,
    output logic [15:0]out_pulse
);
    logic app_clk;
    logic app_aresetn = 1;
    logic app_reset = 0;

    logic sysclk;
    IBUFDS sysclk_ibuf_i (.O(sysclk), .I(sysclk_p), .IB(sysclk_n));

    BUFG clkf_buf
    (.O (clkfbout_buf),
        .I (clkfbout));

    logic PS_clk, PS_aresetn, PS_reset;

    axi4_lite_if #(
        .DW(EVR_axi_params::GP0_DATA_W),
        .AW(EVR_axi_params::GP0_ADDR_W)
    ) GP_0();

    axi4_lite_if #(
        .DW(EVR_axi_params::MMR_DATA_W),
        .AW(EVR_axi_params::MMR_ADDR_W)
    ) mmr[EVR_axi_params::MMR_DEV_CNT2]();

    axi_crossbar #(
        .N(EVR_axi_params::MMR_DEV_CNT2),
        .AW(EVR_axi_params::GP0_ADDR_W),
        .DW(EVR_axi_params::GP0_DATA_W)
    ) axi_crossbar_i (
        .aclk(app_clk),
        .aresetn(app_aresetn),
        .m(GP_0),
        .s(mmr)
    );

    logic [23:0] ev;
    logic [31:0] delay;
    
    `ifndef SYNTHESIS
    `define GIT_VERSION_MAJOR 'h1234
    `define GIT_VERSION_MINOR 'h5678
    `define GIT_HASH          'habcd
    `endif
    device_info #(
        .DEVICE_TYPE(EVR_axi_params::DEVICE_TYPE),
        .FW_MAJOR(`GIT_VERSION_MAJOR),
        .FW_MINOR(`GIT_VERSION_MINOR),
        .FW_HASH(`GIT_HASH)
    ) device_info_i (
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::DEVICE_INFO])
    );


    typedef logic [63:0] cycle_cnt_t;
    typedef logic [31:0] pulse_cnt_t;
    cycle_cnt_t cycle_cnt;
    pulse_cnt_t pulse_cnt;

    timestamper #(
        .CYCLE_CNT_WIDTH(64), 
        .PULSE_CNT_WIDTH(32)
    ) timestamper_i (
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::TIMESTAMPER]),
        .cycle_start_val(cycle_cnt_t'(delay) >> 16), // ожидаю, что задержка получилась целеая
        .cycle_cnt(cycle_cnt),
        .pulse_cnt(pulse_cnt),
        .ev(ev)
    );

    PS_wrapper_sv #(
        .GP0_ADDR_W(EVR_axi_params::GP0_ADDR_W),
        .GP0_DATA_W(EVR_axi_params::GP0_DATA_W),
        .MMR_DEV_CNT2(EVR_axi_params::MMR_DEV_CNT2),
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
        
        .peripheral_clock(PS_clk),
        .peripheral_aresetn(PS_aresetn),
        .peripheral_reset(PS_reset),
        .app_aresetn(app_aresetn),
        .app_clk(app_clk)
    );

    logic POR_reset;

    pf_m #(
        .WIDTH(1000),
        .POR("ON")
    ) pf_i (
        .clk(app_clk),
        .in(0),
        .out(POR_reset)
    );

    always_ff @( posedge app_clk ) app_aresetn <= PS_aresetn && ~POR_reset;
    always_ff @( posedge app_clk ) app_reset   <= PS_reset || POR_reset;

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

    logic sfp_loss [4];


    gtwizard_wrapper gtwizard_i (
        .refclk_n(REFCLK_SFP_n),
        .refclk_p(REFCLK_SFP_p),
        .sysclk(PS_clk), 
        .soft_reset(app_reset),
        .sfp_loss(sfp_loss),
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

    sfp_control sfp_control_i(
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::SFP_CONTROL]),
        .sfp_loss(sfp_loss)
    );

    axi_stream_if #(.DW(32)) slave_in_packet();
    axi_stream_if #(.DW(32)) slave_out_packet();

    link_slave link_slave1(
        .beacon_clk(sfp_tx_clk[0]),

        //------GTP signals-------
        .aligned(sfp_aligned[0]),

        .tx_resetdone(tx_reset_done[0]),
        .tx_clk(sfp_tx_clk[0]),
        .tx_data(sfp_tx_data[0]),
        .tx_charisk(sfp_tx_is_k[0]),

        .rx_resetdone(rx_reset_done[0]),
        .rx_clk(sfp_rx_clk[0]),
        .rx_data(sfp_rx_data[0]),
        .rx_charisk(sfp_rx_is_k[0]),

        //------Application signals-------
        .app_clk(app_clk), // app_clk generated only by first evg
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::SLAVE]),
        
        .ev(ev), 
        .trig(),
        .in_packet(slave_in_packet),
        .out_packet(slave_out_packet),

        .delay(delay)
    );

    logic set      [EVR_axi_params::SIG_GEN_N];
    logic clear    [EVR_axi_params::SIG_GEN_N];
    logic trigger  [EVR_axi_params::SIG_GEN_N];
    logic cnt_reset[EVR_axi_params::SIG_GEN_N];
    logic gen_out  [EVR_axi_params::SIG_GEN_N];
    ev_map #(
        .EV_WIDTH(24),
        .COMP_N(EVR_axi_params::EV_COMP_N),
        .SIG_GEN_N(EVR_axi_params::SIG_GEN_N)
    ) ev_map_i (
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::EV_MAP]),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .ev(ev)
    );

    signal_generator #(
        .N(EVR_axi_params::SIG_GEN_N),
        .PERIOD_W(64),
        .DELAY_W(64),
        .WIDTH_W(64)
    ) signal_generator_i (
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::SIG_GEN_CTRL]),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .gen_out(gen_out)
    );
    assign out_pulse = {<<{gen_out}};
    
    assign led[1] = tx_reset_done[0];
    assign led[2] = rx_reset_done[0];
    assign led[3] = out_pulse[0];
endmodule
