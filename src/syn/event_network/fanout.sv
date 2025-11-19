`include "axi_stream.svh"

module fanout#(
    parameter PORT_N = 4
)(
    input  logic            beacon_clk,
    input  logic            local_clk, // локальный тактовый сигнал, на котором ПЛИС должна работать 
                                       // до того, как получит частоту от опт. сети
    gtx_if.app              gtx_if[PORT_N],

    //------Application signals-------
    output logic            app_clk,
    input  logic            app_rst,
    axi4_lite_if.s          mmr,
    
    output evn::ev_t        ev,
    output evn::trig_t      trig
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

    axi_stream_if #(.DW(32)) master_in_packet[PORT_N - 1]();
    axi_stream_if #(.DW(32)) master_out_packet[PORT_N - 1]();

    link_data upstream_data();
    link_data downstream_data[PORT_N - 1]();

    trig_t  trig_iternal[PORT_N - 1];
    delay_t sub_delay_iternal[PORT_N - 1];
    logic   sub_delay_iternal_upd[PORT_N - 1];
    logic   app_clk_iternal[PORT_N - 1];

    logic   dc_clk;
    link_slave link_slave_i(
        .beacon_clk(beacon_clk),
        .local_clk(local_clk),
        .dc_clk(dc_clk),
        .jc_clk(dc_clk),
        .jc_clk_valid(1),

        //------GTP signals-------
        .gtx_if(gtx_if[0]),

        //------Application signals-------
        .app_clk(app_clk), // app_clk generated only by first evg
        .app_rst(local_app_rst[0]),

        .ev(ev), 
        .trig(trig),
        .in_packet(slave_in_packet),
        .out_packet(slave_out_packet),

        .link_data(upstream_data)
    );

    genvar i;
    generate
    for(i = 0; i < PORT_N - 1; i++) begin : link_master_inst
    assign downstream_data[i].topo_id        = (upstream_data.topo_id << 4) + i + 2;
    assign downstream_data[i].topo_id_upd    = upstream_data.topo_id_upd;
    assign downstream_data[i].tgt_delay      = upstream_data.tgt_delay;
    assign downstream_data[i].tgt_delay_upd  = upstream_data.tgt_delay_upd;
    assign downstream_data[i].up_delay       = upstream_data.up_delay + upstream_data.link_delay;
    assign downstream_data[i].up_delay_upd   = upstream_data.up_delay_upd || upstream_data.link_delay_upd;
    assign sub_delay_iternal[i]         = downstream_data[i].sub_delay;
    assign sub_delay_iternal_upd[i]     = downstream_data[i].sub_delay_upd;
    link_master link_master_i(
        .beacon_clk(beacon_clk),

        //------GTP signals-------
        .gtx_if(gtx_if[i+1]),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(local_app_rst[i+1]),
        
        .ev(ev), 
        .trig(trig_iternal[i]),
        .in_packet(master_in_packet[i]),
        .out_packet(master_out_packet[i]),

        .link_data(downstream_data[i])
    );
    end
    endgenerate

    always_comb begin
        trig = 0;
        for(int j = 0; j < PORT_N - 1; j++)
            trig |= trig_iternal[j];
    end

    max #(
        .W(DELAY_W),
        .N(PORT_N-1)
    ) sub_delay_max (
        .app_clk(app_clk),
        .app_rst(local_app_rst[PORT_N]),

        .in(sub_delay_iternal),
        .in_upd(sub_delay_iternal_upd),
        .out(upstream_data.sub_delay),
        .out_upd(upstream_data.sub_delay_upd)
    );

    fanout_axi_core #(
        .PORT_N(PORT_N)
    ) fanout_axi_core_i(
        .app_clk(app_clk),
        .app_rst(local_app_rst[PORT_N+1]),
        .mmr(mmr),
        .upstream(upstream_data),
        .downstream(downstream_data)
    );
endmodule

module fanout_axi_core#(
    parameter PORT_N = 4
)(
    input  logic                app_clk,
    input  logic                app_rst,

    axi4_lite_if.s              mmr,
    link_data.monitor           upstream,
    link_data.monitor           downstream[PORT_N-1]
);
    link_csr_axi_core_pkg::link_csr_axi_core__in_t  hwif_in;
    link_csr_axi_core_pkg::link_csr_axi_core__out_t hwif_out;

    assign hwif_in.sr.link_up.next       = upstream.link_up;
    assign hwif_in.sr.link_delay_st.next = upstream.link_delay_st;
    assign hwif_in.sr.delay_comp_st.next = upstream.delay_comp_st;

    assign hwif_in.cr.dc_ena.next        = 0;
    assign hwif_in.cr_s.dc_ena.next      = 0;
    assign hwif_in.cr_c.dc_ena.next      = 0;

    assign hwif_in.port_sr[0].link_up.next       = upstream.link_up;
    assign hwif_in.port_sr[0].link_delay_st.next = upstream.link_delay_st;
    assign hwif_in.port_sr[0].delay_comp_st.next = upstream.delay_comp_st;
    genvar i;
    generate
    for(i = 0; i < PORT_N-1; i++) begin
    assign hwif_in.port_sr[i+1].link_up.next        = downstream[i].link_up;
    assign hwif_in.port_sr[i+1].link_delay_st.next  = downstream[i].link_delay_st;
    assign hwif_in.port_sr[i+1].delay_comp_st.next  = downstream[i].delay_comp_st;
    end
    endgenerate

    assign hwif_in.topo_id.topo_id.next       = upstream.topo_id;
    assign hwif_in.link_delay.link_delay.next = upstream.link_delay;
    assign hwif_in.up_delay.up_delay.next     = upstream.up_delay + upstream.link_delay;
    assign hwif_in.sub_delay.sub_delay.next   = upstream.sub_delay;
    assign hwif_in.tgt_delay.tgt_delay.next   = upstream.tgt_delay;
    assign hwif_in.delay_comp.delay_comp.next = '0;

    link_csr_axi_core link_csr_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );
endmodule