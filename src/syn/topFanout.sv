`include "topFanout.svh"

module topFanout(
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
    input  logic       REFCLK_FROM_RX_n,
    input  logic       REFCLK_FROM_RX_p,
    output logic       RXCLK_n,
    output logic       RXCLK_p,

    input  logic       sfp_rx_n[gtx::FANOUT_PORT_N],
    input  logic       sfp_rx_p[gtx::FANOUT_PORT_N],
    output logic       sfp_tx_n[gtx::FANOUT_PORT_N],
    output logic       sfp_tx_p[gtx::FANOUT_PORT_N],
    output logic [1:0] sfp_tx_disable,

    input  logic       sysclk_n,
    input  logic       sysclk_p,
    output logic [3:0] led
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
        .DW(axi_params::GP0_DATA_W),
        .AW(axi_params::GP0_ADDR_W)
    ) GP_0();
    
    axi4_lite_if #(
        .DW(axi_params::MMR_DATA_W),
        .AW(axi_params::MMR_ADDR_W)
    ) mmr[axi_params::MMR_DEV_CNT2]();

    axi_crossbar #(
        .N(axi_params::MMR_DEV_CNT2),
        .AW(axi_params::GP0_ADDR_W),
        .DW(axi_params::GP0_DATA_W)
    ) axi_crossbar_i (
        .aclk(app_clk),
        .aresetn(app_aresetn),
        .m(GP_0),
        .s(mmr)
    );

    evn::ev_t ev;
    
    device_info #(
        .DEVICE("Fanout")
    ) device_info_i (
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[Fanout_axi_params::DEVICE_INFO])
    );

    logic [63:0] cycle_cnt;
    logic [31:0] pulse_cnt;

    timestamper #(
        .CYCLE_CNT_WIDTH(64), 
        .PULSE_CNT_WIDTH(32)
    ) timestamper_i (
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[Fanout_axi_params::TIMESTAMPER]),
        .cycle_start_val('0),
        .cycle_cnt(cycle_cnt),
        .pulse_cnt(pulse_cnt),
        .ev(ev)
    );

    PS_wrapper_sv #(
        .GP0_ADDR_W(axi_params::GP0_ADDR_W),
        .GP0_DATA_W(axi_params::GP0_DATA_W),
        .MMR_DEV_CNT2(axi_params::MMR_DEV_CNT2),
        .SIM_DEVICE("Fanout")
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

    localparam GTX_PORTS = gtx::FANOUT_PORT_N;
    logic sfp_loss [GTX_PORTS];
    gtx_if fanout_gtx_if[GTX_PORTS]();
    logic beacon_clk;

    gtwizard_wrapper #(
        .DEVICE("Fanout"),
        .PORT_N(GTX_PORTS)
    ) gtwizard_i (
        .refclk_rx_n(REFCLK_SFP_n),
        .refclk_rx_p(REFCLK_SFP_p),
        .refclk_n(REFCLK_FROM_RX_n),
        .refclk_p(REFCLK_FROM_RX_p),
        .sysclk(PS_clk), 
        .soft_reset(app_reset),
        .sfp_loss(sfp_loss),
        .rx_n(sfp_rx_n),
        .rx_p(sfp_rx_p),
        .tx_n(sfp_tx_n),
        .tx_p(sfp_tx_p),
        .gtx_if(fanout_gtx_if),
        .beacon_clk(beacon_clk)
    );
    assign sfp_tx_disable = '0;

    logic RXCLK;
    ODDR RXCLK_ODDR (
        .Q(RXCLK),
        .C(fanout_gtx_if[0].rx_clk),
        .CE(fanout_gtx_if[0].aligned),
        .D1(1),
        .D2(0)
    );
    OBUFDS RXCLK_OBUFDS (
        .O(RXCLK_p),
        .OB(RXCLK_n),
        .I(RXCLK)
    );

    sfp_control #(
        .PORT_N(GTX_PORTS)
    ) sfp_control_i(
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[Fanout_axi_params::SFP_CONTROL]),
        .sfp_loss(sfp_loss)
    );
    
    fanout #(
        .PORT_N(GTX_PORTS)
    ) fanout_i (
        .beacon_clk(beacon_clk),
        .gtx_if(fanout_gtx_if),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[Fanout_axi_params::FANOUT])
    );

    /*gtx_if_ila gtx_if_ila_i(
        .gtx_if(fanout_gtx_if[0]),
        .app_clk(app_clk)
    );*/

    assign led[1] = fanout_gtx_if[0].tx_reset_done;
    assign led[2] = fanout_gtx_if[0].rx_reset_done;
    assign led[3] = 0;
endmodule


module gtx_if_ila(
    gtx_if.monitor gtx_if,
    input  logic   app_clk 
);

    ila_0 ila(
        .clk(app_clk),
        .probe0(gtx_if.tx_clk),
        .probe1(gtx_if.tx_data),
        .probe2(gtx_if.tx_is_k),
        .probe3(gtx_if.tx_reset_done),
        .probe4(gtx_if.rx_clk),
        .probe5(gtx_if.rx_data),
        .probe6(gtx_if.rx_is_k),
        .probe7(gtx_if.rx_reset_done),
        .probe8(gtx_if.aligned)
    );
endmodule