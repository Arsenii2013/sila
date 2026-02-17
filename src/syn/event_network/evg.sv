`include "axi_stream.svh"

module evg#(
    parameter PORT_N = 4
)(
    input  logic            beacon_clk,
    input  logic            local_clk,  // локальный тактовый сигнал, на котором ПЛИС должна работать 
                                        // до того, как получит частоту от опт. сети и залочится 5344 и 5342
    input  logic            gtx_refclk_valid,
    gtx_if.app              gtx_if[PORT_N],

    //------Application signals-------
    output logic            app_clk,
    input  logic            app_rst,
    axi4_lite_if.s          mmr,

    output logic            is_head,
    
    input  evn::ev_t        ev_in,
    output evn::ev_t        ev_out,
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
    axi_stream_if #(.DW(32)) master_in_packet[PORT_N]();
    axi_stream_if #(.DW(32)) master_out_packet[PORT_N]();

    link_data slave_data();
    link_data masters_data[PORT_N]();

    trig_t  trig_iternal[PORT_N];
    delay_t sub_delay_iternal[PORT_N];
    logic   sub_delay_iternal_upd[PORT_N];
    logic   gtx_aligned_sync[PORT_N];

    logic   port_enable[PORT_N];

    ev_t    ev_upstream;
    ev_t    ev_mux;
    // объеденяются события от сети и от логики
    // триггер для разбиения крит. пути
    always_ff @(posedge app_clk) ev_mux <= is_head ? ev_in : ev_upstream;
    assign ev_out = ev_mux;

    delay_t tgt_delay_axi, tgt_delay;
    logic   tgt_delay_upd_axi, tgt_delay_upd;
    assign tgt_delay     = is_head ? tgt_delay_axi      : slave_data.tgt_delay;
    assign tgt_delay_upd = is_head ? tgt_delay_upd_axi  : slave_data.tgt_delay_upd;

    generate
    if (PORT_N > 2 ** TOPO_ID_LEVEL_W) begin
        $error("Портов больше, чем можно выдать топол. идентификаторов");
    end
    endgenerate
    generate
    for(genvar i = 0; i < PORT_N; i++) begin : link_master_insts
        xpm_cdc_async_rst sofr_reset_cdc_i(
            .dest_clk(app_clk),
            .dest_arst(gtx_aligned_sync[i]),
            .src_arst(gtx_if[i].aligned)
        );

        if(i == 0) begin
            assign port_enable[i]           = gtx_aligned_sync[i];

            gtx_if gtx_if_mux_slave();
            gtx_if gtx_if_mux_master();

            gtx_if_mux #(
                .N2(2)
            ) gtx_if_mux_i (
                .in_gtx_if(gtx_if[i]),
                .out_gtx_if('{gtx_if_mux_slave, gtx_if_mux_master}),
                .sel(is_head)
            );

            link_slave link_slave_i(
                .beacon_clk(beacon_clk),
                .dc_clk(),

                //------GTP signals-------
                .gtx_if(gtx_if_mux_slave),

                //------Application signals-------
                .app_clk(app_clk),
                .app_rst(local_app_rst[i] || !port_enable[i]),

                .ev(ev_upstream), 
                .trig(trig),
                .in_packet(slave_in_packet),
                .out_packet(slave_out_packet),

                .total_delay(),
                .link_data(slave_data)
            );

            link_master link_master_i(
                .beacon_clk(beacon_clk),

                //------GTP signals-------
                .gtx_if(gtx_if_mux_master),

                //------Application signals-------
                .app_clk(app_clk),
                .app_rst(local_app_rst[i] || !port_enable[i]),
                
                .ev(ev_mux), 
                .trig(trig_iternal[i]),
                .in_packet(master_in_packet[i]),
                .out_packet(master_out_packet[i]),

                .link_data(masters_data[i])
            );
        end else begin
            assign port_enable[i] = gtx_aligned_sync[i] && (is_head ? 1 : gtx_aligned_sync[0]);

            link_master link_master_i(
                .beacon_clk(beacon_clk),

                //------GTP signals-------
                .gtx_if(gtx_if[i]),

                //------Application signals-------
                .app_clk(app_clk),
                .app_rst(local_app_rst[i] || !port_enable[i]),
                
                .ev(ev_mux), 
                .trig(trig_iternal[i]),
                .in_packet(master_in_packet[i]),
                .out_packet(master_out_packet[i]),

                .link_data(masters_data[i])
            );
        end

        always_comb begin : masters_data_assignments
            masters_data[i].tgt_delay = tgt_delay;
            masters_data[i].tgt_delay_upd = tgt_delay_upd;
            if(is_head) begin
                masters_data[i].topo_id         = i + 1;
                masters_data[i].topo_id_upd     = 0;
                masters_data[i].up_delay        = '0;
                masters_data[i].up_delay_upd    = 0;
                sub_delay_iternal[i]            = masters_data[i].sub_delay;
                sub_delay_iternal_upd[i]        = masters_data[i].sub_delay_upd;
            end else begin
                masters_data[i].topo_id         = (slave_data.topo_id << TOPO_ID_LEVEL_W) + i + 1;
                masters_data[i].topo_id_upd     = slave_data.topo_id_upd;
                masters_data[i].up_delay        = slave_data.up_delay + slave_data.link_delay + 
                                                  delay_t'(4 << DELAY_FRAC_W);
                masters_data[i].up_delay_upd    = slave_data.up_delay_upd || slave_data.link_delay_upd;
                if(i == 0) begin
                    sub_delay_iternal[i]        = '0;
                    sub_delay_iternal_upd[i]    = 0;
                end else begin
                    sub_delay_iternal[i]        = masters_data[i].sub_delay;
                    sub_delay_iternal_upd[i]    = masters_data[i].sub_delay_upd;
                end
            end
        end
    end
    endgenerate

    max #(
        .W(DELAY_W),
        .N(PORT_N)
    ) sub_delay_max (
        .app_clk(app_clk),
        .app_rst(local_app_rst[PORT_N]),

        .in(sub_delay_iternal),
        .in_upd(sub_delay_iternal_upd),
        .out(slave_data.sub_delay),
        .out_upd(slave_data.sub_delay_upd)
    );

    always_comb begin
        trig = 0;
        for(int j = 0; j < PORT_N; j++)
            trig |= trig_iternal[j];
    end

    BUFGMUX_CTRL BUFGMUX_CTRL_inst (
        .O(app_clk),
        .I0(local_clk),
        .I1(gtx_if[0].tx_clk),
        .S(gtx_refclk_valid)
    );

    evg_axi_core #(
        .PORT_N(PORT_N)
    ) evg_axi_core_i(
        .app_clk(app_clk),
        .app_rst(local_app_rst[PORT_N+1]),
        .mmr(mmr),
        .slave_data(slave_data),
        .masters_data(masters_data),
        .tgt_delay(tgt_delay_axi),
        .tgt_delay_upd(tgt_delay_upd_axi),
        .is_head(is_head)
    );
endmodule

module evg_axi_core#(
    parameter PORT_N = 4
)(
    input  logic                app_clk,
    input  logic                app_rst,

    axi4_lite_if.s              mmr,
    link_data.monitor           slave_data,
    link_data.monitor           masters_data[PORT_N],
    output evn::delay_t         tgt_delay,
    output logic                tgt_delay_upd,
    output logic                is_head
);
    link_csr_axi_core_pkg::link_csr_axi_core__in_t  hwif_in;
    link_csr_axi_core_pkg::link_csr_axi_core__out_t hwif_out;

    assign hwif_in.sr.link_up.next       = slave_data.link_up;
    assign hwif_in.sr.link_delay_st.next = slave_data.link_delay_st;
    assign hwif_in.sr.delay_comp_st.next = evn::ZERO;

    assign hwif_in.cr.dc_ena.next        = 0;
    assign hwif_in.cr_s.dc_ena.next      = 0;
    assign hwif_in.cr_c.dc_ena.next      = 0;

    assign hwif_in.cr.head_mode.next     = (hwif_out.cr.head_mode.value | hwif_out.cr_s.head_mode.value) & ~hwif_out.cr_c.head_mode.value;
    assign hwif_in.cr_s.head_mode.next   = 0;
    assign hwif_in.cr_c.head_mode.next   = 0;
    assign is_head = hwif_out.cr.head_mode.value;

    assign hwif_in.port_sr[0].link_up.next        = is_head ? masters_data[0].link_up       : slave_data.link_up;
    assign hwif_in.port_sr[0].link_delay_st.next  = is_head ? masters_data[0].link_delay_st : slave_data.link_delay_st;
    assign hwif_in.port_sr[0].delay_comp_st.next  = is_head ? '0                            : slave_data.delay_comp_st;
    genvar i;
    generate
    for(i = 1; i < PORT_N - 1; i++) begin
        assign hwif_in.port_sr[i].link_up.next        = masters_data[i].link_up;
        assign hwif_in.port_sr[i].link_delay_st.next  = masters_data[i].link_delay_st;
        assign hwif_in.port_sr[i].delay_comp_st.next  = '0;
    end
    endgenerate

    assign hwif_in.topo_id.topo_id.next       = is_head ? 0                        : slave_data.topo_id;
    assign hwif_in.link_delay.link_delay.next = is_head ? '0                       : slave_data.link_delay;
    assign hwif_in.up_delay.up_delay.next     = is_head ? '0                       : slave_data.up_delay + slave_data.link_delay;
    assign hwif_in.sub_delay.sub_delay.next   = slave_data.sub_delay; // это значение правильное вне зависимости от is_head
    assign hwif_in.tgt_delay.tgt_delay.next   = is_head ? tgt_delay : slave_data.tgt_delay;
    assign hwif_in.delay_comp.delay_comp.next = slave_data.delay_comp;
    assign tgt_delay                          = hwif_out.tgt_delay.tgt_delay.value;
    assign tgt_delay_upd                      = hwif_out.tgt_delay.tgt_delay.swmod;

    link_csr_axi_core link_csr_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );
endmodule

module gtx_if_mux #(
    parameter integer N2 = 2
)(
    gtx_if.app in_gtx_if,
    gtx_if.gtx out_gtx_if[N2],

    input  logic [$clog2(N2) - 1: 0] sel
);
    import gtx::*;

    data_t [N2 - 1: 0] tx_data_flat;
    is_k_t [N2 - 1: 0] tx_is_k_flat;

    generate
    for(genvar i = 0; i < N2; i ++) begin : out_assignments
        assign out_gtx_if[i].tx_clk         = in_gtx_if.tx_clk;
        assign out_gtx_if[i].tx_reset_done  = in_gtx_if.tx_reset_done;
        assign out_gtx_if[i].rx_clk         = in_gtx_if.rx_clk;
        assign out_gtx_if[i].rx_data        = in_gtx_if.rx_data;
        assign out_gtx_if[i].rx_is_k        = in_gtx_if.rx_is_k;
        assign out_gtx_if[i].rx_reset_done  = in_gtx_if.rx_reset_done;
        assign out_gtx_if[i].aligned        = in_gtx_if.aligned;

        assign tx_data_flat[i] = out_gtx_if[i].tx_data;
        assign tx_is_k_flat[i] = out_gtx_if[i].tx_is_k;
    end
    endgenerate
    assign in_gtx_if.tx_data = tx_data_flat[sel];
    assign in_gtx_if.tx_is_k = tx_is_k_flat[sel];
endmodule
