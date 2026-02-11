`include "axi_stream.svh"

module evr#(
    parameter PORT_N = 1
)(
    input  logic            beacon_clk, // измерительный клок от 5344
    input  logic            local_clk,  // локальный тактовый сигнал, на котором ПЛИС должна работать 
                                        // до того, как получит частоту от опт. сети и залочится 5344 и 5342
    output logic            dc_clk,     // клок идущий к 5342
    input  logic            jc_clk,     // клок идущий от 5342
    input  logic            jc_clk_valid, // лок 5342

    gtx_if.app              gtx_if[PORT_N],

    //------Application signals-------
    output logic            app_clk,
    input  logic            app_rst,
    axi4_lite_if.s          mmr,
    
    output evn::ev_t        ev,
    input  evn::trig_t      trig,

    output evn::delay_t     delay
);
    import evn::*;

    localparam LOCAL_RESET_CNT = PORT_N + 2;
    logic local_app_rst [LOCAL_RESET_CNT];
    reset_fanout #(LOCAL_RESET_CNT) reset_fanout_i(
        .clk(app_clk),
        .reset_in(app_rst),
        .reset_out(local_app_rst)
    );

    axi_stream_if #(.DW(32)) slave_in_packet();
    axi_stream_if #(.DW(32)) slave_out_packet();

    link_data ports_data[PORT_N]();

    assign ports_data[0].sub_delay     = ports_data[0].up_delay + ports_data[0].link_delay;
    assign ports_data[0].sub_delay_upd = ports_data[0].up_delay_upd || ports_data[0].link_delay_upd;

    ev_t ev_internal;
    always_ff @(posedge app_clk) ev <= ev_internal;

    link_slave link_slave_i(
        .beacon_clk(beacon_clk),
        .dc_clk(dc_clk),

        //------GTP signals-------
        .gtx_if(gtx_if[0]),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(local_app_rst[0] || !jc_clk_valid),

        .ev(ev_internal), 
        .trig(trig),
        .in_packet(slave_in_packet),
        .out_packet(slave_out_packet),

        .total_delay(delay),
        .link_data(ports_data[0])
    );

    BUFGCTRL #(
        .INIT_OUT(0),
        .PRESELECT_I0("TRUE"),
        .PRESELECT_I1("FALSE")
    ) BUFGCTRL_inst (
        .O(app_clk),
        .CE0(1),
        .CE1(1),
        .I0(local_clk),
        .I1(jc_clk),
        .IGNORE0(0),
        .IGNORE1(0),
        .S0(!jc_clk_valid),
        .S1(jc_clk_valid)
    );


    evr_axi_core #(
        .PORT_N(PORT_N)
    ) evg_axi_core_i(
        .app_clk(app_clk),
        .app_rst(local_app_rst[1]),
        .mmr(mmr),
        .link_data(ports_data[0])
    );
endmodule

module evr_axi_core#(
    parameter PORT_N
)(
    input  logic                app_clk,
    input  logic                app_rst,

    axi4_lite_if.s              mmr,
    link_data.monitor_dc_ena    link_data
);
    link_csr_axi_core_pkg::link_csr_axi_core__in_t  hwif_in;
    link_csr_axi_core_pkg::link_csr_axi_core__out_t hwif_out;

    assign hwif_in.sr.link_up.next       = link_data.link_up;
    assign hwif_in.sr.link_delay_st.next = link_data.link_delay_st;
    assign hwif_in.sr.delay_comp_st.next = link_data.delay_comp_st;

    assign hwif_in.cr.dc_ena.next        = link_data.delay_comp_ena;
    assign hwif_in.cr_s.dc_ena.next      = 0;
    assign hwif_in.cr_c.dc_ena.next      = 0;
    assign link_data.delay_comp_ena      = (hwif_out.cr.dc_ena.value | hwif_out.cr_s.dc_ena.value) & ~hwif_out.cr_c.dc_ena.value;

    assign hwif_in.cr.head_mode.next     = 0;
    assign hwif_in.cr_s.head_mode.next   = 0;
    assign hwif_in.cr_c.head_mode.next   = 0;

    assign hwif_in.port_sr[0].link_up.next        = link_data.link_up;
    assign hwif_in.port_sr[0].link_delay_st.next  = link_data.link_delay_st;
    assign hwif_in.port_sr[0].delay_comp_st.next  = link_data.delay_comp_st;

    assign hwif_in.topo_id.topo_id.next       = link_data.topo_id;
    assign hwif_in.link_delay.link_delay.next = link_data.link_delay;
    assign hwif_in.up_delay.up_delay.next     = link_data.up_delay + link_data.link_delay;
    assign hwif_in.sub_delay.sub_delay.next   = link_data.sub_delay;
    assign hwif_in.tgt_delay.tgt_delay.next   = link_data.tgt_delay;
    assign hwif_in.delay_comp.delay_comp.next = link_data.delay_comp;

    link_csr_axi_core link_csr_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );
endmodule