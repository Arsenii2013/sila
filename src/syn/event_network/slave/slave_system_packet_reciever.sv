`include "evn.svh"
`include "system_stream_if.svh"

module slave_system_packet_reciever(
    input  logic                  app_clk,
    input  logic                  rx_clk,
    input  logic                  app_rst,
    output logic [TOPO_ID_W-1: 0] topo_id,
    output logic                  topo_id_recv,
    output logic [DELAY_W  -1: 0] meas_delay,
    output logic [          3: 0] meas_delay_st,
    output logic                  meas_delay_recv,
    output logic [DELAY_W  -1: 0] tgt_delay,
    output logic                  tgt_delay_recv,
    system_stream_if.m            in
);
    // модуль приема системных пакетов
    // сигналы *_recv - импульсы по окончанию приема соответствующего пакета
    logic topo_id_recv_sync, meas_delay_recv_sync, tgt_delay_recv_sync;

    xpm_cdc_pulse send_topo_id_sunchronizer_i(
        .dest_clk(app_clk),
        .dest_pulse(topo_id_recv),
        .dest_rst(app_rst),
        .src_clk(rx_clk),
        .src_pulse(topo_id_recv_sync),
        .src_rst(app_rst)
    );
    xpm_cdc_pulse send_meas_sunchronizer_i(
        .dest_clk(app_clk),
        .dest_pulse(meas_delay_recv),
        .dest_rst(app_rst),
        .src_clk(rx_clk),
        .src_pulse(meas_delay_recv_sync),
        .src_rst(app_rst)
    );
    xpm_cdc_pulse send_tgt_delay_sunchronizer_i(
        .dest_clk(app_clk),
        .dest_pulse(tgt_delay_recv),
        .dest_rst(app_rst),
        .src_clk(rx_clk),
        .src_pulse(tgt_delay_recv_sync),
        .src_rst(app_rst)
    );

    system_stream_if #(.DW(32)) system_stream[4]();

    assign in.tready = system_stream[0].tready;
    genvar i;
    generate
    for (i=0; i < 4; i++) begin
        assign system_stream[i].tvalid = in.tvalid;
        assign system_stream[i].tdata = in.tdata;
        assign system_stream[i].tisk = in.tisk;
    end
    endgenerate

    simple_packet_rx_fsm #(
        .DW(32),
        .PACKET_ID(TOPO_ID_PACKET_ID),
        .PARAM_CNT(TOPO_ID_PACKET_LEN)
    ) topo_id_rx_fsm (
        .app_clk(rx_clk),
        .app_rst(app_rst),
        .param('{topo_id}),
        .packet_recv(topo_id_recv_sync),
        .in(system_stream[0])
    );

    simple_packet_rx_fsm #(
        .DW(32),
        .PACKET_ID(MEAS_DELAY_PACKET_ID),
        .PARAM_CNT(MEAS_DELAY_PACKET_LEN)
    ) meas_delay_rx_fsm (
        .app_clk(rx_clk),
        .app_rst(app_rst),
        .param('{meas_delay, meas_delay_st}),
        .packet_recv(meas_delay_recv_sync),
        .in(system_stream[1])
    );

    simple_packet_rx_fsm #(
        .DW(32),
        .PACKET_ID(TGT_DELAY_PACKET_ID),
        .PARAM_CNT(TGT_DELAY_PACKET_LEN)
    ) tgt_delay_rx_fsm (
        .app_clk(rx_clk),
        .app_rst(app_rst),
        .param('{tgt_delay}),
        .packet_recv(tgt_delay_recv_sync),
        .in(system_stream[2])
    );

endmodule 