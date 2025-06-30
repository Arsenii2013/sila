`include "top.svh"
`include "evn.svh"
`include "axi_stream.svh"

interface system_stream_if #(
    parameter DW = 64
);
    logic [DW-1  :0] tdata;
    logic [DW/8-1:0] tisk;
    logic            tvalid;
    logic            tready;
    
    modport m(
        output tdata,
        output tisk,
        output tvalid,
        input  tready
    );
    
    modport s(
        input  tdata,
        input  tisk,
        input  tvalid,
        output tready
    );
endinterface

module evg_system_packet_generator(
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
    system_stream_if #(.DW(32)) system_stream[4]();

    stream_mux4 #(.DW(4)) packet_mux (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .in(system_stream),
        .out(out)
    );

    simple_packet_tx_fsm #(
        .DW(32),
        .PACKET_ID(TOPO_ID_PACKET_ID),
        .PARAM_CNT(TOPO_ID_PACKET_LEN)
    ) topo_id_tx_fsm (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .param('{topo_id}),
        .send_packet(send_topo_id),
        .out(system_stream[0])
    );

    simple_packet_tx_fsm #(
        .DW(32),
        .PACKET_ID(MEAS_DELAY_PACKET_ID),
        .PARAM_CNT(MEAS_DELAY_PACKET_LEN)
    ) meas_delay_tx_fsm (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .param('{meas_delay, meas_delay_st}),
        .send_packet(send_meas_delay),
        .out(system_stream[1])
    );

    simple_packet_tx_fsm #(
        .DW(32),
        .PACKET_ID(TGT_DELAY_PACKET_ID),
        .PARAM_CNT(TGT_DELAY_PACKET_LEN)
    ) tgt_delay_tx_fsm (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .param('{tgt_delay}),
        .send_packet(send_tgt_delay),
        .out(system_stream[2])
    );

endmodule 

module evr_system_packet_reciever(
    input  logic                  app_clk,
    input  logic                  app_rst,
    output logic [TOPO_ID_W-1: 0] topo_id,
    output logic                  topo_id_recv,
    output logic [DELAY_W  -1: 0] meas_delay,
    output logic [          4: 0] meas_delay_st,
    output logic                  meas_delay_recv,
    output logic [DELAY_W  -1: 0] tgt_delay,
    output logic                  tgt_delay_recv,
    system_stream_if.m            in
);
    // модуль генерации системных пакетов
    // сигналы send_* - запросы на отправку соответствующего пакета
    // импульс по send_* означает, что пакет будет отправлен, но никаких гарантий времени нет
    // импульс может приходить до окончания отправки пакета, 
    // в этом случае сразу же сгенерируется запрос на новый пакет
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
        .app_clk(app_clk),
        .app_rst(app_rst),
        .param('{topo_id}),
        .packet_recv(topo_id_recv),
        .in(system_stream[0])
    );

    simple_packet_rx_fsm #(
        .DW(32),
        .PACKET_ID(MEAS_DELAY_PACKET_ID),
        .PARAM_CNT(MEAS_DELAY_PACKET_LEN)
    ) meas_delay_rx_fsm (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .param('{meas_delay, meas_delay_st}),
        .packet_recv(meas_delay_recv),
        .in(system_stream[1])
    );

    simple_packet_rx_fsm #(
        .DW(32),
        .PACKET_ID(TGT_DELAY_PACKET_ID),
        .PARAM_CNT(TGT_DELAY_PACKET_LEN)
    ) tgt_delay_rx_fsm (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .param('{tgt_delay}),
        .packet_recv(tgt_delay_recv),
        .in(system_stream[2])
    );

endmodule 

module stream_mux4 #(
    parameter DW = 32
) (
    input  logic           app_clk,
    input  logic           app_rst,
    system_stream_if.s     in[4],
    system_stream_if.m     out
);
    typedef logic [1: 0] id_t;

    id_t current_id, prev_id = 0;

    always_ff @(posedge app_clk) prev_id <= current_id;

    always_comb begin
        in[0].tready = 0;
        in[1].tready = 0;
        in[2].tready = 0;
        in[3].tready = 0;

        if(prev_id == 0) begin
            out.tdata    = in[0].tdata;
            out.tisk     = in[0].tisk;
            out.tvalid   = in[0].tvalid;
            in[0].tready = out.tready;
        end else if(prev_id == 1) begin
            out.tdata    = in[1].tdata;
            out.tisk     = in[1].tisk;
            out.tvalid   = in[1].tvalid;
            in[1].tready = out.tready;
        end else if(prev_id == 2) begin
            out.tdata    = in[2].tdata;
            out.tisk     = in[2].tisk;
            out.tvalid   = in[2].tvalid;
            in[2].tready = out.tready;
        end else if(prev_id == 3) begin
            out.tdata    = in[3].tdata;
            out.tisk     = in[3].tisk;
            out.tvalid   = in[3].tvalid;
            in[3].tready = out.tready;
        end

        if(out.tvalid) 
            current_id = prev_id;
        else begin
            if(in[0].tvalid)
                current_id = 0;
            else if(in[1].tvalid)
                current_id = 1;
            else if(in[2].tvalid)
                current_id = 2;
            else if(in[3].tvalid)
                current_id = 3;
        end
    end
endmodule

module simple_packet_tx_fsm #(
    parameter DW        = 32,
    parameter PACKET_ID = 8'h00,
    parameter PARAM_CNT = 1
) (
    input  logic           app_clk,
    input  logic           app_rst,
    input  logic [DW-1: 0] param [PARAM_CNT],
    input  logic           send_packet,
    system_stream_if.m     out
);
    // Простой генератор пакетов состоящих из PARAM_CNT слов.
    // send_packet запускает генерацию
    // дожен учитывать, что транзакции на интерфейсе могут быть приостановлены
    typedef logic [15: 0] uint16_t;
    localparam START_WORD  = {PACKET_COMMA, PACKET_ID, uint16_t'(PARAM_CNT)};

    typedef logic [$clog2(PARAM_CNT): 0] param_cnt_t;
    typedef logic [DW -1: 0] data_t;
    typedef enum
    {
        WAIT,
        SEND_START,
        SEND_PARAMS,
        SEND_SUM
    } state_t;

    state_t state         = WAIT;
    logic send_packet_reg = 0;
    data_t sum            = '0;
    param_cnt_t param_i   = '0;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            state           <= WAIT;
            send_packet_reg <= 0;
            sum             <= '0;
            param_i         <= '0;
            out.tvalid      <= 0;
        end else begin
            if(send_packet) 
                send_packet_reg <= 1;
            
            case (state)
                WAIT : begin
                    if(send_packet_reg) begin
                        send_packet_reg <= 0;
                        state           <= SEND_START;
                        out.tvalid      <= 1;
                    end 
                end

                SEND_START : begin
                    if(out.tready) begin
                        out.tvalid <= 1;
                        state      <= SEND_PARAMS;
                        sum        <= sum + START_WORD;
                    end
                end

                SEND_PARAMS : begin
                    if(out.tready) begin
                        if(param_i == PARAM_CNT - 1) begin
                            param_i    <= 0;
                            state      <= SEND_SUM;
                        end else begin
                            out.tvalid <= 1;
                            param_i    <= param_i + 1;
                        end 
                        sum        <= sum + param[param_i];
                    end
                end

                SEND_SUM : begin
                    if(out.tready) begin
                        out.tvalid  <= 1;
                        state       <= WAIT;
                        sum         <= 0;
                        out.tvalid  <= 0;
                    end
                end
                
                default : begin
                    state           <= WAIT;
                    send_packet_reg <= 0;
                    sum             <= '0;
                    param_i         <= '0;
                end
            endcase
        end
    end

    always_comb begin
        case (state)
            WAIT : begin 
                out.tdata = '0;
                out.tisk  = '0;
            end
            SEND_START : begin 
                out.tdata = START_WORD;
                out.tisk  = PACKET_START_IS_K;
            end
            SEND_PARAMS : begin 
                out.tdata = param[param_i];
                out.tisk  = '0;
            end
            SEND_SUM : begin 
                out.tdata = sum;
                out.tisk  = '0;
            end
            default : begin 
                out.tdata = '0;
                out.tisk  = '0;
            end
        endcase
    end

endmodule 


module simple_packet_rx_fsm #(
    parameter DW        = 32,
    parameter PACKET_ID = 8'h00,
    parameter PARAM_CNT = 1
) (
    input  logic           app_clk,
    input  logic           app_rst,
    output logic [DW-1: 0] param [PARAM_CNT],
    output logic           packet_recv,
    system_stream_if.s     in
);

    // должен учитывать что valid может пропасть
    // valid должен формироваться как отутствик к символов
    typedef logic [15: 0] uint16_t;
    localparam START_WORD  = {PACKET_COMMA, PACKET_ID, uint16_t'(PARAM_CNT)};

    typedef logic [$clog2(PARAM_CNT): 0] param_cnt_t;
    typedef logic [DW -1: 0] data_t;
    typedef enum
    {
        WAIT,
        GET_PARAMS,
        CHECK_SUM
    } state_t;

    state_t state         = WAIT;
    data_t sum            = '0;
    logic [DW-1: 0] param_buf [PARAM_CNT] = '{default : {'0}};
    param_cnt_t param_i   = '0;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            param       <= '{default : {'0}};
            param_buf   <= '{default : {'0}};
            packet_recv <= 0;
            state       <= WAIT;
            sum         <= '0;
            in.tready   <= 0;
        end else begin
            case (state)
                WAIT : begin
                    in.tready <= 1;
                    packet_recv <= 0;
                    if(in.tvalid && in.tdata == START_WORD) begin
                        state <= GET_PARAMS;
                        sum   <= sum + in.tdata;
                    end 
                end

                GET_PARAMS : begin
                    if(in.tvalid) begin
                        if(param_i == PARAM_CNT - 1) begin
                            param_i    <= 0;
                            state      <= CHECK_SUM;
                            param_buf [param_i] <= in.tdata;
                        end else begin
                            param_buf [param_i] <= in.tdata;
                            param_i             <= param_i + 1;
                        end
                        sum                 <= sum + in.tdata;
                    end
                end

                CHECK_SUM : begin
                    if(in.tvalid) begin
                        if(sum == in.tdata) begin
                            param       <= param_buf;
                            packet_recv <= 1;
                        end 
                        state <= WAIT;
                        sum <= '0;
                    end
                end
                
                default : begin
                    state           <= WAIT;
                    packet_recv     <= 0;
                    sum             <= '0;
                    param_i         <= '0;
                end
            endcase
        end
    end


endmodule

module simple_packet_fsmTB();

    logic     app_clk;
    logic     app_rst;

    sys_clk_gen
    #(
        .halfcycle (2857), // 2857 ps ~ 175_008_750 Hz
        .offset    (0)
    ) app_clk_gen (
        .sys_clk (app_clk)
    );

    logic connect = 1;
    system_stream_if #(.DW(32)) in();
    system_stream_if #(.DW(32)) out();
    assign in.tdata   = out.tdata;
    assign in.tisk    = out.tisk;
    assign in.tvalid  = connect ? out.tvalid : 0;
    assign out.tready = connect ? in.tready : 0;
    logic           send_packet = 0;

    simple_packet_tx_fsm #(.DW(32), .PACKET_ID(8'hfd), .PARAM_CNT(4)) DUT_TX (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .param('{'h12345678, 'h9abcdef0, 'h12345678, 'h9abcdef0}),
        .send_packet(send_packet),
        .out(out)
    );

    simple_packet_rx_fsm #(.DW(32), .PACKET_ID(8'hfd), .PARAM_CNT(4)) DUT_RX (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .param(),
        .packet_recv(),
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
        @(posedge app_clk) connect <=0;

        for(int i = 0; i < 100; i++)
            @(posedge app_clk);
        @(posedge app_clk) connect <=1;

        for(int i = 0; i < 100; i++)
            @(posedge app_clk);

        $stop();
    end
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

        for(int i = 0; i < 100; i++)
            @(posedge app_clk);

        for(int i = 0; i < 100; i++)
            @(posedge app_clk);

        $stop();
    end
endmodule