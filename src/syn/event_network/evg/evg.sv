`include "top.svh"
`include "evn.svh"
`include "axi4_lite_if.svh"
`include "system_stream_if.svh"

module evg
(
    input  logic            beacon_clk,

    //------GTP signals-------
    input  logic            aligned,

    input  logic            tx_resetdone,
    input  logic            tx_clk,
    output logic [31:0]     tx_data,
    output logic [3:0]      tx_charisk,

    input  logic            rx_resetdone,
    input  logic            rx_clk,
    input  logic [31:0]     rx_data,
    input  logic [3:0]      rx_charisk,

    //------Application signals-------
    output logic            app_clk,
    input  logic            app_rst,
    axi4_lite_if.s          mmr,
    
    input  logic [23:0]     ev, // ev_valid = ev != 0
    output logic [23:0]     trig, // trig_valid = trig != 0
    axi_stream_if.s         in_packet,
    axi_stream_if.m         out_packet
);
    assign app_clk = tx_clk;

    assign in_packet.tready = 0;
    assign out_packet.tvalid = 0;

    typedef logic [DELAY_INT_W+DELAY_FRAC_W-1: 0] delay_t;
    typedef logic [DELAY_INT_W             -1: 0] beacon_cnt_t;
    typedef logic [TOPO_ID_W               -1: 0] topo_id_t;

    logic [3:0] delay_st;
// Event
    logic ev_valid;
    assign ev_valid = ev != '0;
    

// Beacon
    // Во избежание неопределенности измерения задержки из-за включения приемника
    // при частично заполенном FIFO sampler-а при запуске запускаем beacon-ы, таким образом,
    // чтоб за время таймаута отправлялся только один. Таким образом,
    // если поймали beacon_rx это точно ответ на этот beacon_tx, если нет - таймаут.
    // sampler запускается от следующего beacon-а, и точно знает что первый beacon_rx 
    // это ответ на первый beacon_tx

    localparam MAX_DELAY = 2 ** DELAY_INT_W - 1;
    logic beacon_valid = 0;
    logic beacon_ready = 0;
    beacon_cnt_t beacon_cnt = MAX_DELAY;

    always_ff @(posedge tx_clk) begin
        if(app_rst) begin
            beacon_cnt   <= delay_st[0] ? BEACON_PERIOD : MAX_DELAY;
            beacon_valid <= 0;
        end else begin
            if(beacon_cnt == 0) begin
                beacon_cnt   <= delay_st[0] ? BEACON_PERIOD : MAX_DELAY;
                beacon_valid <= 1;
            end else begin
                beacon_cnt <= beacon_cnt - 1;
                if(beacon_ready) begin
                    beacon_valid <= 0;
                end else begin
                    beacon_valid <= beacon_valid;
                end
            end
        end
    end

// Alignment 
    logic alignment_valid = 0;
    logic alignment_ready = 0;
    alignment_cnt_t alignment_cnt = ALIGNMENT_PERIOD;

    always_ff @(posedge tx_clk) begin
        if(app_rst) begin
            alignment_cnt   <= ALIGNMENT_PERIOD;
            alignment_valid <= 0;
        end else begin
            if(alignment_cnt == 0) begin
                alignment_cnt   <= ALIGNMENT_PERIOD;
                alignment_valid <= 1;
            end else begin
                alignment_cnt <= alignment_cnt - 1;
                if(alignment_ready) begin
                    alignment_valid <= 0;
                end else begin
                    alignment_valid <= alignment_valid;
                end
            end
        end
    end

// System packets

    delay_t delay;
    logic   delay_upd;

    // Отправка нового значения задержки если разность между
    // текущим значением и прошлым отправленным больше SEND_TRESH
    localparam SEND_TRESH = delay_t'((1<<DELAY_FRAC_W) >> 9); // Для 175 МГц интервал 1/175e6/2**9 = 11,16 ps
    delay_t last_sended_delay = '0;
    logic   send_delay        = 0;
    logic   send_in_tresh;

    assign send_in_tresh      = last_sended_delay > delay ? 
                                last_sended_delay - delay < SEND_TRESH : 
                                delay - last_sended_delay < SEND_TRESH;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            send_delay        <= 0;
            last_sended_delay <= '0;
        end else begin
            if(delay_upd && !send_in_tresh) begin
                send_delay        <= 1;
                last_sended_delay <= delay;
            end else begin
                send_delay        <= 0;
                last_sended_delay <= last_sended_delay;
            end
        end
    end 

    // Определения подключения приемника
    logic [3:0] prev_delay_st = '0;
    logic device_connected    = 0;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            device_connected     <= 0;
            prev_delay_st        <= '0;
        end else begin
            if(delay_upd && prev_delay_st[0] == 0 && delay_st[0] == 1) begin
                device_connected <= 1;
            end else begin
                device_connected <= 0;
            end
            if(delay_upd)
                prev_delay_st    <= delay_st;
        end
    end 

    topo_id_t topo_id;
    delay_t tgt_delay;
    logic   tgt_delay_upd;
    assign topo_id = 'h12345678;
    system_stream_if #(.DW(32)) system_stream();
    evg_system_packet_generator evg_system_packet_generator_i(
        .app_clk(app_clk),
        .tx_clk(tx_clk),
        .app_rst(app_rst),
        .topo_id(topo_id),
        .send_topo_id(device_connected),
        .meas_delay(delay),
        .meas_delay_st(delay_st),
        .send_meas_delay(send_delay),
        .tgt_delay(tgt_delay),
        .send_tgt_delay(tgt_delay_upd || device_connected),
        .out(system_stream)
    );


// Mux
    always_ff @(posedge tx_clk) begin
        beacon_ready    <= 0;
        alignment_ready <= 0;
        tx_data         <= '0;
        tx_charisk      <= '0;

        if(ev_valid) begin
            tx_data         <= {EVENT_COMMA, ev};
            tx_charisk      <= 'h8;
        end else if(beacon_valid && ~beacon_ready) begin
            tx_data         <= BEACON_WORD;
            tx_charisk      <= BEACON_IS_K;
            beacon_ready    <= 1;
        end else if(system_stream.tvalid) begin
            tx_data         <= system_stream.tdata;
            tx_charisk      <= system_stream.tisk;
        end else if(alignment_valid && ~alignment_ready) begin
            tx_data         <= ALIGNMENT_WORD;
            tx_charisk      <= ALIGNMENT_IS_K;
            alignment_ready <= 1;
        end else begin
            tx_data         <= '0;
            tx_charisk      <= '0;
        end
    end

    assign system_stream.tready = !ev_valid && !beacon_valid;

// Delay measurement
    delay_measure #(
        .INT_W(DELAY_INT_W),
        .FRAC_W(DELAY_FRAC_W)
    )
    measure_i(
        .app_clk(app_clk),
        .app_rst(app_rst),
        
        .beacon_tx((tx_data == BEACON_WORD) && (tx_charisk == BEACON_IS_K)),
        .tx_clk(tx_clk),
        .beacon_rx((rx_data == BEACON_WORD) && (rx_charisk == BEACON_IS_K)),
        .rx_clk(rx_clk),
        .beacon_clk(beacon_clk),

        .delay_upd(delay_upd),
        .delay(delay),
        .delay_status(delay_st)
    );

// MMR
    evg_axi_core #(
        .ADDR_W(GP0_ADDR_W),
        .DATA_W(GP0_DATA_W)
    ) evg_axi_core_i (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .aligned(aligned),
        .topoid(topo_id),
        .delay(delay),
        .delay_status(delay_st),
        .tgt_delay(tgt_delay),
        .tgt_delay_upd(tgt_delay_upd)
    );

endmodule


module evg_axi_core#(
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)(
    input  logic                                 app_clk,
    input  logic                                 app_rst,
    axi4_lite_if.s                               mmr,

    input  logic                                 aligned,
    input  logic [TOPO_ID_W               -1: 0] topoid,
    input  logic [DELAY_INT_W+DELAY_FRAC_W-1: 0] delay,
    input  logic [3                         : 0] delay_status,
    output logic [DELAY_INT_W+DELAY_FRAC_W-1: 0] tgt_delay,
    output logic                                 tgt_delay_upd
);
//MMR logic 
    typedef logic [ADDR_W-1:0] addr_t;
    typedef logic [DATA_W-1:0] data_t;

    typedef enum addr_t {
        SR            = addr_t'(8'h00),
        CR            = addr_t'(8'h04),
        CR_S          = addr_t'(8'h08),
        CR_C          = addr_t'(8'h0C),
        LINK_TOPO_ID  = addr_t'(8'h10),
        LINK_DELAY    = addr_t'(8'h14),
        TGT_DELAY     = addr_t'(8'h18)
    } evr_regs;

    typedef struct packed {
        logic [3:0] link_delay_st;
        logic [2:0] none;
        logic       link_up;
    } sr_t;

    typedef struct packed {
        logic none;
    } cr_t;

    sr_t sr;
    cr_t cr;
    addr_t addr;
    data_t data;
    logic read;
    logic write_addr;
    logic write_data;

    assign sr.link_up       = aligned;
    assign sr.none          = '0;
    assign sr.link_delay_st = delay_status;

    always_ff @(posedge app_clk) begin
        if (app_rst) begin
            mmr.arready <= 0;
            mmr.rvalid  <= 0;
            mmr.awready <= 0;
            mmr.wready  <= 0;
            mmr.bvalid  <= 0;
            mmr.rresp   <= '0;
            mmr.bresp   <= '0;
            mmr.rdata   <= '0;
            read        <= 0;
            write_addr  <= 0;
            write_data  <= 0;

            tgt_delay     <= '0;
            tgt_delay_upd <= 0;
        end
        else begin
            mmr.arready <= 0;
            if(mmr.arvalid && !read) begin
                addr <= mmr.araddr;
                read <= 1;
                mmr.arready <= 1;
            end 

            mmr.rvalid <= read;
            if(mmr.rready && read) begin
                read <= 0;
                case (addr)
                    SR            : mmr.rdata <= data_t'(sr);
                    CR            : mmr.rdata <= data_t'(cr);
                    LINK_TOPO_ID  : mmr.rdata <= data_t'(topoid);
                    LINK_DELAY    : mmr.rdata <= data_t'(delay);
                    TGT_DELAY     : mmr.rdata <= data_t'(tgt_delay);
                    default       : mmr.rdata <= '0;
                endcase 
            end 


            mmr.awready <= 0;
            if(mmr.awvalid && !write_addr) begin
                addr <= mmr.awaddr;
                write_addr  <= 1;
                mmr.awready <= 1;
            end 

            mmr.wready <= 0;
            if(mmr.wvalid && !write_data) begin
                data <= mmr.wdata;
                write_data <= 1;
                mmr.wready <= 1;
            end 

            tgt_delay_upd <= 0;
            mmr.bvalid <= write_addr && write_data;
            if(mmr.bready && write_addr && write_data) begin
                write_addr <= 0;
                write_data <= 0;
                case (addr)
                    CR        : cr <= cr_t'(data);
                    CR_S      : cr <= cr | cr_t'(data);
                    CR_C      : cr <= cr & ~(cr_t'(data));
                    TGT_DELAY : begin
                        tgt_delay_upd <= 1;
                        tgt_delay     <= data;
                    end
                    default;
                endcase
            end 
            
        end
    end
endmodule