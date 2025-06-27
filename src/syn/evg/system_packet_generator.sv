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

module evg_system_packet_fsm(
    input  logic                  app_clk,
    input  logic                  app_rst,
    input  logic [TOPO_ID_W-1: 0] topo_id,
    input  logic                  topo_id_upd,
    input  logic [DELAY_W  -1: 0] measured_delay,
    input  logic                  measured_delay_upd,
    input  logic [DELAY_W  -1: 0] target_delay,
    input  logic                  target_delay_upd,
    system_stream_if.m            out
);

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
                            sum        <= sum + param[param_i];
                        end 
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
                            sum                 <= sum + in.tdata;
                        end 
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