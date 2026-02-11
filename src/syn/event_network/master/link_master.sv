module link_master
(
    input  logic            beacon_clk,

    //------GTP signals-------
    gtx_if.app              gtx_if,

    //------Application signals-------
    input  logic            app_clk, // ожидаю, что app_clk той же частоты, что и tx_clk, отличается только фаза
    input  logic            app_rst,
    
    input  evn::ev_t        ev, // ev_valid = ev != 0
    output evn::trig_t      trig, // trig_valid = trig != 0
    axi_stream_if.s         in_packet,
    axi_stream_if.m         out_packet, 

    link_data.master        link_data
);
    assign in_packet.tready = 0;
    assign out_packet.tvalid = 0;

    import evn::*;

// Event
    // разбить крит. путь
    ev_t ev_reg;
    logic ev_valid_reg;
    always_ff @(posedge app_clk) ev_reg       <= ev;
    always_ff @(posedge app_clk) ev_valid_reg <= ev != '0;
    


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

    always_ff @(posedge gtx_if.tx_clk) begin
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

    always_ff @(posedge gtx_if.tx_clk) begin
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

    system_stream_if system_stream_out();
    system_stream_if system_stream_in();
    master_system_packet_generator system_packet_generator_i(
        .app_clk(app_clk),
        .tx_clk(gtx_if.tx_clk),
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
        .rx_clk(gtx_if.rx_clk),
        .app_clk(app_clk),
        .app_rst(app_rst),
        .sub_delay(link_data.sub_delay),
        .sub_delay_recv(link_data.sub_delay_upd),
        .in(system_stream_in)
    );
    assign system_stream_in.tdata  = gtx_if.rx_data;
    assign system_stream_in.tisk   = gtx_if.rx_is_k;
    assign system_stream_in.tvalid = is_packet(gtx_if.rx_data, gtx_if.rx_is_k);

// Mux
    // хоть события и подразумеваются сгенерированными генераторами/пересинхронизованными приемником
    // на app_clk, но app_clk переключается между local и tx_clk и подразумеваестя, что пока
    // он на local_clk, события не валидны. А с tx_clk на tx_clk пересинхронизовывать не нужно.
    always_ff @(posedge gtx_if.tx_clk) begin
        beacon_ready    <= 0;
        alignment_ready <= 0;
        gtx_if.tx_data <= '0;
        gtx_if.tx_is_k <= '0;

        if(ev_valid_reg) begin
            gtx_if.tx_data <= {EVENT_COMMA, ev_reg};
            gtx_if.tx_is_k <= 'h8;
        end else if(beacon_valid && ~beacon_ready) begin
            gtx_if.tx_data <= BEACON_WORD;
            gtx_if.tx_is_k <= BEACON_IS_K;
            beacon_ready    <= 1;
        end else if(system_stream_out.tvalid) begin
            gtx_if.tx_data <= system_stream_out.tdata;
            gtx_if.tx_is_k <= system_stream_out.tisk;
        end else if(alignment_valid && ~alignment_ready) begin
            gtx_if.tx_data <= ALIGNMENT_WORD;
            gtx_if.tx_is_k <= ALIGNMENT_IS_K;
            alignment_ready <= 1;
        end else begin
            gtx_if.tx_data <= '0;
            gtx_if.tx_is_k <= '0;
        end
    end
    assign system_stream_out.tready = !ev_valid_reg && !beacon_valid;

    fifo_wrapper #(
        .DEPTH(16)
    ) fifo_i (
        .app_rst(app_rst),
        .app_clk(app_clk),
        .rx_clk(gtx_if.rx_clk),

        .data_in(is_trigger(gtx_if.rx_data, gtx_if.rx_is_k) ? trig_t'(gtx_if.rx_data) : '0),
        .isk_in('0),
        .data_out(trig),

        .fifo_inc(0),
        .fifo_dec(0)
    );

// Delay measurement
    logic fifo_rst_busy_rd_clk;
    xpm_cdc_async_rst fifo_rst_busy_sunchronizer_i(
        .dest_clk(gtx_if.tx_clk),
        .dest_arst(fifo_rst_busy_rd_clk),
        .src_arst(fifo_rst_busy)
    );

    delay_t link_delay;
    link_delay_st_t link_delay_st;

    delay_measure #(
        .INT_W(DELAY_INT_W),
        .FRAC_W(DELAY_FRAC_W)
    ) measure_i(
        .app_clk(app_clk),
        .app_rst(app_rst),
        
        .start(is_beacon(gtx_if.tx_data, gtx_if.tx_is_k)),
        .start_clk(gtx_if.tx_clk),
        .stop(is_beacon(gtx_if.rx_data, gtx_if.rx_is_k)),
        .stop_clk(gtx_if.rx_clk),
        .measure_clk(beacon_clk),

        .delay_upd(link_data.link_delay_upd),
        .delay(link_delay),
        .delay_status(link_delay_st)
    );

    xpm_cdc_async_rst link_up_cdc_i(
        .dest_clk(app_clk),
        .dest_arst(link_data.link_up),
        .src_arst(gtx_if.aligned)
    );
    assign link_data.link_delay = link_delay + (2 << DELAY_FRAC_W);
    assign link_data.link_delay_st = link_delay_st;
endmodule