`include "evn.svh"
`include "system_stream_if.svh"

module master_system_packet_reciever(
    input  logic           app_clk,
    input  logic           rx_clk,
    input  logic           app_rst,
    output evn::delay_t    sub_delay,
    output logic           sub_delay_recv,
    system_stream_if.m     in
);
    // модуль приема системных пакетов
    // сигналы *_recv - импульсы по окончанию приема соответствующего пакета
    import evn::*;

    logic sub_delay_recv_sync;

    xpm_cdc_pulse sub_delay_recv_sunchronizer_i(
        .dest_clk(app_clk),
        .dest_pulse(sub_delay_recv),
        .dest_rst(app_rst),
        .src_clk(rx_clk),
        .src_pulse(sub_delay_recv_sync),
        .src_rst(app_rst)
    );

    system_stream_if system_stream[4]();

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
        .PARAM_W(DELAY_W),
        .PACKET_ID(SUB_DELAY_PACKET_ID),
        .PARAM_CNT(SUB_DELAY_PACKET_LEN)
    ) sub_delay_rx_fsm (
        .app_clk(rx_clk),
        .app_rst(app_rst),
        .param('{sub_delay}),
        .packet_recv(sub_delay_recv_sync),
        .in(system_stream[0])
    );
endmodule 