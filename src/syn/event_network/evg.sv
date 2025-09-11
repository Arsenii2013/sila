`include "axi_stream.svh"

module evg#(
    parameter PORT_N = 4
)(
    input  logic            beacon_clk,
    gtx_if.app              gtx_if[PORT_N],

    //------Application signals-------
    output logic            app_clk,
    input  logic            app_rst,
    axi4_lite_if.s          mmr,
    
    input  evn::ev_t        ev,
    output evn::trig_t      trig
);
    import evn::*;

    axi_stream_if #(.DW(32)) slave_in_packet[PORT_N]();
    axi_stream_if #(.DW(32)) slave_out_packet[PORT_N]();

    link_data axi_data();
    link_data ports_data[PORT_N]();

    trig_t  trig_iternal[PORT_N];
    delay_t sub_delay_iternal[PORT_N];
    logic   sub_delay_iternal_upd[PORT_N];

    genvar i;
    generate
    for(i = 0; i < PORT_N; i++) begin
    assign ports_data[i].topo_id        = i+1;
    assign ports_data[i].topo_id_upd    = 0;
    assign ports_data[i].tgt_delay      = axi_data.tgt_delay;
    assign ports_data[i].tgt_delay_upd  = axi_data.tgt_delay_upd;
    assign ports_data[i].up_delay       = '0;
    assign ports_data[i].up_delay_upd   = 0;
    assign sub_delay_iternal[i]         = ports_data[i].sub_delay;
    assign sub_delay_iternal_upd[i]     = ports_data[i].sub_delay_upd;
    link_master link_master_i(
        .beacon_clk(beacon_clk),

        //------GTP signals-------
        .gtx_if(gtx_if[i]),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_rst),
        
        .ev(ev), 
        .trig(trig_iternal[i]),
        .in_packet(slave_in_packet[i]),
        .out_packet(slave_out_packet[i]),

        .link_data(ports_data[i])
    );
    end
    endgenerate

    assign app_clk = gtx_if[0].tx_clk;

    assign axi_data.topo_id    = '0;
    assign axi_data.up_delay   = '0;
    assign axi_data.link_delay = '0;

    max #(
        .W(DELAY_W),
        .N(PORT_N)
    ) sub_delay_max (
        .app_clk(app_clk),
        .app_rst(app_rst),

        .in(sub_delay_iternal),
        .in_upd(sub_delay_iternal_upd),
        .out(axi_data.sub_delay)
    );

    always_comb begin
        trig = 0;
        for(int j = 0; j < PORT_N; j++)
            trig |= trig_iternal[j];
    end

    evg_axi_core #(
        .PORT_N(PORT_N)
    ) evg_axi_core_i(
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .link_data(axi_data),
        .ports_data(ports_data)
    );
endmodule

module evg_axi_core#(
    parameter PORT_N = 4
)(
    input  logic                app_clk,
    input  logic                app_rst,

    axi4_lite_if.s              mmr,
    link_data                   link_data,
    link_data.monitor           ports_data[PORT_N]
);
    link_csr_axi_core_pkg::link_csr_axi_core__in_t  hwif_in;
    link_csr_axi_core_pkg::link_csr_axi_core__out_t hwif_out;

    assign hwif_in.sr.link_up.next       = link_data.link_up;
    assign hwif_in.sr.link_delay_st.next = link_data.link_delay_st;
    assign hwif_in.sr.delay_comp_st.next = evn::ZERO;

    assign hwif_in.cr.dc_ena.next        = 0;
    assign hwif_in.cr_s.dc_ena.next      = 0;
    assign hwif_in.cr_c.dc_ena.next      = 0;

    genvar i;
    generate
    for(i = 0; i < PORT_N; i++) begin
    assign hwif_in.port_sr[i].link_up.next        = ports_data[i].link_up;
    assign hwif_in.port_sr[i].link_delay_st.next  = ports_data[i].link_delay_st;
    assign hwif_in.port_sr[i].delay_comp_st.next  = ports_data[i].delay_comp_st;
    end
    endgenerate

    assign hwif_in.topo_id.topo_id.next       = link_data.topo_id;
    assign hwif_in.link_delay.link_delay.next = link_data.link_delay;
    assign hwif_in.up_delay.up_delay.next     = link_data.up_delay;
    assign hwif_in.sub_delay.sub_delay.next   = link_data.sub_delay;
    assign hwif_in.tgt_delay.tgt_delay.next   = link_data.tgt_delay;
    assign hwif_in.delay_comp.delay_comp.next = '0;
    assign link_data.tgt_delay                = hwif_out.tgt_delay.tgt_delay.value;
    assign link_data.tgt_delay_upd            = hwif_out.tgt_delay.tgt_delay.swmod;

    link_csr_axi_core link_csr_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );
endmodule