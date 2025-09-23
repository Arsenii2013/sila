`include "topEVR.svh"
//`include "gtx.svh"

package EVR_board;
    localparam START_N                 = 16;
    localparam integer START_INVERSE [START_N] 
                    = {0, 1, 0, 1, 1, 1, 1, 0, 
                       1, 0, 1, 1, 1, 0, 1, 1};

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

    input  logic       SFP_RX_N[gtx::EVR_PORT_N],
    input  logic       SFP_RX_P[gtx::EVR_PORT_N],
    output logic       SFP_TX_N[gtx::EVR_PORT_N],
    output logic       SFP_TX_P[gtx::EVR_PORT_N],
    output logic       SFP_TX_DIS,

    output logic [EVR_board::LED_N  -1:0] LED,
    output logic [EVR_board::START_N-1:0] START_p,
    output logic [EVR_board::START_N-1:0] START_n
);
    logic app_clk;
    logic app_aresetn = 1;
    logic app_reset = 0;

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

    evn::ev_t    ev;
    evn::delay_t delay;

    device_info #(
        .DEVICE("EVR")
    ) device_info_i (
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::DEVICE_INFO])
    );


    timestamper #(
        .CYCLE_CNT_WIDTH(64), 
        .PULSE_CNT_WIDTH(32)
    ) timestamper_i (
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::TIMESTAMPER]),
        .cycle_start_val(delay >> 16), // ожидаю, что задержка получилась целеая
        .cycle_cnt(),
        .pulse_cnt(),
        .ev(ev)
    );

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
        .led(LED[0])
    );


    localparam GTX_PORTS = gtx::EVR_PORT_N;
    logic sfp_loss [GTX_PORTS];
    gtx_if evr_gtx_if[GTX_PORTS]();

    gtwizard_wrapper #(
        .DEVICE("EVR"),
        .PORT_N(GTX_PORTS)
    ) gtwizard_i (
        .refclk_n(REFCLK_SFP_n),
        .refclk_p(REFCLK_SFP_p),
        .sysclk(PS_clk), 
        .soft_reset(app_reset),
        .sfp_loss(sfp_loss),
        .rx_n(SFP_RX_N),
        .rx_p(SFP_RX_P),
        .tx_n(SFP_TX_N),
        .tx_p(SFP_TX_P),
        .gtx_if(evr_gtx_if)
    );
    assign SFP_TX_DIS = '0;

    sfp_control #(
        .PORT_N(GTX_PORTS)
    ) sfp_control_i(
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::SFP_CONTROL]),
        .sfp_loss(sfp_loss)
    );

    evr #(
        .PORT_N(GTX_PORTS)
    ) evr_i (
        .beacon_clk(evr_gtx_if[0].tx_clk),
        .gtx_if(evr_gtx_if),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_reset),
        .mmr(mmr[EVR_axi_params::EVR]),
        
        .ev(ev), 
        .trig('0),

        .delay(delay)
    );

    logic set      [EVR_axi_params::SIG_GEN_N];
    logic clear    [EVR_axi_params::SIG_GEN_N];
    logic trigger  [EVR_axi_params::SIG_GEN_N];
    logic cnt_reset[EVR_axi_params::SIG_GEN_N];
    logic gen_out  [EVR_axi_params::SIG_GEN_N];
    ev_map #(
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

    logic [EVR_board::START_N-1:0] start;
    signal_generator #(
        .N(EVR_axi_params::SIG_GEN_N)
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
    assign start = {<<{gen_out}};

    genvar start_gen_i;
    generate
    for(start_gen_i = 0; start_gen_i < EVR_board::START_N; start_gen_i ++) begin
        if(EVR_board::START_INVERSE[start_gen_i]) begin
            OBUFDS start_OBUFDS (
                .O(START_p[start_gen_i]),
                .OB(START_n[start_gen_i]),
                .I(!start[start_gen_i])
            );
        end else begin
            OBUFDS start_OBUFDS (
                .O(START_p[start_gen_i]),
                .OB(START_n[start_gen_i]),
                .I(start[start_gen_i])
            );
        end
    end
    endgenerate
    
    assign LED[1] = evr_gtx_if[0].tx_reset_done;
    assign LED[2] = evr_gtx_if[0].rx_reset_done;
    assign LED[3] = start[0];
endmodule
