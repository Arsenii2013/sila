`include "top.svh"
`include "evn.svh"
`include "axi4_lite_if.svh"
`include "system_stream_if.svh"

module link_master
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
    
    input  evn::ev_t        ev, // ev_valid = ev != 0
    output evn::trig_t      trig, // trig_valid = trig != 0
    axi_stream_if.s         in_packet,
    axi_stream_if.m         out_packet, 

    link_data.master        link_data
);
    assign app_clk = tx_clk;

    assign in_packet.tready = 0;
    assign out_packet.tvalid = 0;

    import evn::*;

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
            beacon_cnt   <= link_data.link_delay_st[0] ? BEACON_PERIOD : MAX_DELAY;
            beacon_valid <= 0;
        end else begin
            if(beacon_cnt == 0) begin
                beacon_cnt   <= link_data.link_delay_st[0] ? BEACON_PERIOD : MAX_DELAY;
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
    // Отправка нового значения задержки если разность между
    // текущим значением и прошлым отправленным больше SEND_TRESH
    localparam SEND_TRESH = delay_t'((1<<DELAY_FRAC_W) >> 9); // Для 175 МГц интервал 1/175e6/2**9 = 11,16 ps
    delay_t last_sended_link_delay = '0;
    link_delay_st_t last_sended_st;
    logic   send_link_delay        = 0;
    logic   send_in_tresh;

    assign send_in_tresh      = last_sended_link_delay > link_data.link_delay ? 
                                last_sended_link_delay - link_data.link_delay < SEND_TRESH : 
                                link_data.link_delay   - last_sended_link_delay < SEND_TRESH;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            send_link_delay        <= 0;
            last_sended_link_delay <= '0;
            last_sended_st         <= evn::ZERO;
        end else begin
            if(link_data.link_delay_upd && (!send_in_tresh || last_sended_st != link_data.link_delay_st)) begin
                send_link_delay        <= 1;
                last_sended_link_delay <= link_data.link_delay;
                last_sended_st         <= link_data.link_delay_st;
            end else begin
                send_link_delay        <= 0;
                last_sended_link_delay <= last_sended_link_delay;
                last_sended_st         <= last_sended_st;
            end
        end
    end

    // Определения подключения приемника
    link_delay_st_t prev_link_delay_st = evn::ZERO;
    logic device_connected    = 0;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            device_connected     <= 0;
            prev_link_delay_st   <= evn::ZERO;
        end else begin
            if(link_data.link_delay_upd && prev_link_delay_st[0] == 0 && link_data.link_delay_st[0] == 1) begin
                device_connected <= 1;
            end else begin
                device_connected <= 0;
            end
            if(link_data.link_delay_upd)
                prev_link_delay_st    <= link_data.link_delay_st;
        end
    end 

    system_stream_if #(.DW(32)) system_stream_out();
    system_stream_if #(.DW(32)) system_stream_in();
    master_system_packet_generator system_packet_generator_i(
        .app_clk(app_clk),
        .tx_clk(tx_clk),
        .app_rst(app_rst),
        .topo_id(link_data.topo_id),
        .send_topo_id(link_data.topo_id_upd || device_connected),
        .meas_delay(link_data.link_delay),
        .meas_delay_st(link_data.link_delay_st),
        .send_meas_delay(send_link_delay),
        .tgt_delay(link_data.tgt_delay),
        .send_tgt_delay(link_data.tgt_delay_upd || device_connected),
        .up_delay(link_data.up_delay),
        .send_up_delay(link_data.up_delay_upd || device_connected),
        .out(system_stream_out)
    );

    master_system_packet_reciever system_packet_reciever_i(
        .rx_clk(rx_clk),
        .app_clk(app_clk),
        .app_rst(app_rst),
        .sub_delay(link_data.sub_delay),
        .sub_delay_recv(link_data.sub_delay_upd),
        .in(system_stream_in)
    );
    assign system_stream_in.tdata  = rx_data;
    assign system_stream_in.tisk   = rx_charisk;
    assign system_stream_in.tvalid = rx_charisk == 0 || (rx_data[31:24] == PACKET_COMMA && rx_charisk == PACKET_START_IS_K);

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
        end else if(system_stream_out.tvalid) begin
            tx_data         <= system_stream_out.tdata;
            tx_charisk      <= system_stream_out.tisk;
        end else if(alignment_valid && ~alignment_ready) begin
            tx_data         <= ALIGNMENT_WORD;
            tx_charisk      <= ALIGNMENT_IS_K;
            alignment_ready <= 1;
        end else begin
            tx_data         <= '0;
            tx_charisk      <= '0;
        end
    end

    assign system_stream_out.tready = !ev_valid && !beacon_valid;

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

        .delay_upd(link_data.link_delay_upd),
        .delay(link_data.link_delay),
        .delay_status(link_data.link_delay_st)
    );
    assign link_data.link_up = aligned;

/*
    link_control_axi_core_pkg::link_control_axi_core__in_t  hwif_in;
    link_control_axi_core_pkg::link_control_axi_core__out_t hwif_out;

    assign hwif_in.sr.link_up.next       = aligned;
    assign hwif_in.sr.link_delay_st.next = link_data.link_delay_st;

    assign hwif_in.cr.reserved.next      = (hwif_out.cr.reserved.value | hwif_out.cr_s.reserved.value) & ~hwif_out.cr_c.reserved.value;
    assign hwif_in.cr_s.reserved.next    = 0;
    assign hwif_in.cr_c.reserved.next    = 0;

    assign hwif_in.topo_id.topo_id.next       = link_data.topo_id;
    assign hwif_in.link_delay.link_delay.next = link_data.link_delay;
    assign hwif_in.up_delay.up_delay.next     = link_data.up_delay;
    assign hwif_in.sub_delay.sub_delay.next   = sub_delay;
    assign hwif_in.tgt_delay.tgt_delay.next   = link_data.tgt_delay;

    link_control_axi_core link_master_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );*/
endmodule