`include "evn.svh"
`include "system_stream_if.svh"

module evg_system_packet_generator(
    input  logic                  tx_clk,
    input  logic                  app_clk,
    input  logic                  app_rst,
    input  logic [TOPO_ID_W-1: 0] topo_id,
    input  logic                  send_topo_id,
    input  logic [DELAY_W  -1: 0] meas_delay,
    input  logic [          4: 0] meas_delay_st,
    input  logic                  send_meas_delay,
    input  logic [DELAY_W  -1: 0] tgt_delay,
    input  logic                  send_tgt_delay,
    system_stream_if.m            out
);
    // модуль генерации системных пакетов
    // сигналы send_* - запросы на отправку соответствующего пакета
    // импульс по send_* означает, что пакет будет отправлен, но никаких гарантий времени нет
    // импульс может приходить до окончания отправки пакета, 
    // в этом случае сразу же сгенерируется запрос на новый пакет
    logic send_topo_id_sync, send_meas_delay_sync, send_tgt_delay_sync;

    xpm_cdc_pulse send_topo_id_sunchronizer_i(
        .dest_clk(tx_clk),
        .dest_pulse(send_topo_id_sync),
        .dest_rst(app_rst),
        .src_clk(app_clk),
        .src_pulse(send_topo_id),
        .src_rst(app_rst)
    );
    xpm_cdc_pulse send_meas_sunchronizer_i(
        .dest_clk(tx_clk),
        .dest_pulse(send_meas_delay_sync),
        .dest_rst(app_rst),
        .src_clk(app_clk),
        .src_pulse(send_meas_delay),
        .src_rst(app_rst)
    );
    xpm_cdc_pulse send_tgt_delay_sunchronizer_i(
        .dest_clk(tx_clk),
        .dest_pulse(send_tgt_delay_sync),
        .dest_rst(app_rst),
        .src_clk(app_clk),
        .src_pulse(send_tgt_delay),
        .src_rst(app_rst)
    );

    system_stream_if #(.DW(32)) system_stream[4]();

    system_stream_mux4 #(.DW(4)) packet_mux (
        .app_clk(tx_clk),
        .app_rst(app_rst),
        .in(system_stream),
        .out(out)
    );

    simple_packet_tx_fsm #(
        .DW(32),
        .PACKET_ID(TOPO_ID_PACKET_ID),
        .PARAM_CNT(TOPO_ID_PACKET_LEN)
    ) topo_id_tx_fsm (
        .app_clk(tx_clk),
        .app_rst(app_rst),
        .param('{topo_id}),
        .send_packet(send_topo_id_sync),
        .out(system_stream[0])
    );

    simple_packet_tx_fsm #(
        .DW(32),
        .PACKET_ID(MEAS_DELAY_PACKET_ID),
        .PARAM_CNT(MEAS_DELAY_PACKET_LEN)
    ) meas_delay_tx_fsm (
        .app_clk(tx_clk),
        .app_rst(app_rst),
        .param('{meas_delay, meas_delay_st}),
        .send_packet(send_meas_delay_sync),
        .out(system_stream[1])
    );

    simple_packet_tx_fsm #(
        .DW(32),
        .PACKET_ID(TGT_DELAY_PACKET_ID),
        .PARAM_CNT(TGT_DELAY_PACKET_LEN)
    ) tgt_delay_tx_fsm (
        .app_clk(tx_clk),
        .app_rst(app_rst),
        .param('{tgt_delay}),
        .send_packet(send_tgt_delay_sync),
        .out(system_stream[2])
    );

endmodule 


module evg_system_packet_generatorTB();

    logic     app_clk;
    logic     app_rst;

    sys_clk_gen
    #(
        .halfcycle (2857), // 2857 ps ~ 175_008_750 Hz
        .offset    (0)
    ) app_clk_gen (
        .sys_clk (app_clk)
    );

    system_stream_if #(.DW(32)) out();
    system_stream_if #(.DW(32)) in();
    
    logic           send_packet = 0;
    logic           connect     = 1;


    assign out.tready = connect ? in.tready  : 0;
    assign in.tvalid  = connect ? out.tvalid : 0;
    assign in.tdata   = connect ? out.tdata  : 0;
    assign in.tisk    = connect ? out.tisk   : 0;

    evg_system_packet_generator DUT_TX(
        .app_clk(app_clk),
        .app_rst(app_rst),
        .topo_id('h12345678),
        .send_topo_id(send_packet),
        .meas_delay('h9abcdef0),
        .meas_delay_st('h02468ace),
        .send_meas_delay(send_packet),
        .tgt_delay('h13579bdf),
        .send_tgt_delay(send_packet),
        .out(out)
    );

    evr_system_packet_reciever DUT_RX(
        .app_clk(app_clk),
        .app_rst(app_rst),
        .topo_id(),
        .topo_id_recv(),
        .meas_delay(),
        .meas_delay_st(),
        .meas_delay_recv(),
        .tgt_delay(),
        .tgt_delay_recv(),
        .in(in)
    );

    initial begin
        app_rst      <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst      <= 0;
        @(posedge app_clk) send_packet  <= 1;
        @(posedge app_clk) send_packet  <= 0;
        @(posedge app_clk) send_packet  <= 1;
        @(posedge app_clk) send_packet  <= 0;
        @(posedge app_clk);
        @(posedge app_clk);

        for(int i = 0; i < 7; i++)
            @(posedge app_clk);
        
        @(posedge app_clk) connect = 0;
        for(int i = 0; i < 100; i++)
            @(posedge app_clk);
        @(posedge app_clk) connect = 1;
        for(int i = 0; i < 100; i++)
            @(posedge app_clk);


        $stop();
    end
endmodule