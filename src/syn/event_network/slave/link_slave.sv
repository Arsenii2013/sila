module link_slave
(
    input  logic            beacon_clk,

    //------GTP signals-------
    gtx_if.app              gtx_if,

    //------Application signals-------
    output logic            app_clk,
    input  logic            app_rst,

    output evn::ev_t        ev, // ev_valid = ev != 0
    input  evn::trig_t      trig, // trig_valid = trig != 0
    axi_stream_if.s         in_packet,
    axi_stream_if.m         out_packet,

    output evn::delay_t     total_delay,
    link_data.slave         link_data
);
    assign in_packet.tready = 0;
    assign out_packet.tvalid = 0;

    import evn::*;

// Trigger
    logic trig_valid;
    assign trig_valid = trig != '0;
    
// Beacon
    logic beacon_pulse;
    pf_m #(
        .POR("OFF")
    ) pf_beacon(
        .clk(gtx_if.rx_clk),
        .in(is_beacon(gtx_if.rx_data, gtx_if.rx_is_k)),
        .out(beacon_pulse)
    );
    logic beacon_pulse_sync;
    xpm_cdc_pulse beacon_sunchronizer_i(
        .dest_clk(gtx_if.tx_clk),
        .dest_pulse(beacon_pulse_sync),
        .dest_rst(app_rst),
        .src_clk(gtx_if.rx_clk),
        .src_pulse(beacon_pulse),
        .src_rst(app_rst)
    );

    logic beacon_valid = 0;
    logic beacon_ready = 0;

    always_ff @(posedge gtx_if.tx_clk) begin
        if(app_rst) begin
            beacon_valid <= 0;
        end else begin
            if(beacon_pulse_sync) begin
                beacon_valid <= 1;
            end else begin
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
    system_stream_if system_stream_in();
    system_stream_if system_stream_out();
    assign system_stream_in.tdata  = gtx_if.rx_data;
    assign system_stream_in.tisk   = gtx_if.rx_is_k;
    assign system_stream_in.tvalid = is_packet(gtx_if.rx_data, gtx_if.rx_is_k);

    slave_system_packet_reciever system_packet_reciever_i(
        .rx_clk(gtx_if.rx_clk),
        .app_clk(app_clk),
        .app_rst(app_rst),
        .topo_id(link_data.topo_id),
        .topo_id_recv(link_data.topo_id_upd),
        .meas_delay(link_data.link_delay),
        .meas_delay_st(link_data.link_delay_st),
        .meas_delay_recv(link_data.link_delay_upd),
        .tgt_delay(link_data.tgt_delay),
        .tgt_delay_recv(link_data.tgt_delay_upd),
        .up_delay(link_data.up_delay),
        .up_delay_recv(link_data.up_delay_upd),
        .in(system_stream_in)
    );

    slave_system_packet_generator system_packet_generator_i(
        .tx_clk(gtx_if.tx_clk),
        .app_clk(app_clk),
        .app_rst(app_rst),
        .sub_delay(link_data.sub_delay),
        .send_sub_delay(link_data.sub_delay_upd),
        .out(system_stream_out)
    );


// Mux
    always_ff @(posedge gtx_if.tx_clk) begin
        alignment_ready <= 0;
        beacon_ready    <= 0;
        gtx_if.tx_data  <= '0;
        gtx_if.tx_is_k  <= '0;

        if(trig_valid) begin
            gtx_if.tx_data  <= {TRIGGER_COMMA, trig};
            gtx_if.tx_is_k  <= 'h8;
        end else if(beacon_valid && ~beacon_ready) begin
            gtx_if.tx_data  <= BEACON_WORD;
            gtx_if.tx_is_k  <= BEACON_IS_K;
            beacon_ready    <= 1;
        end else if(system_stream_out.tvalid) begin
            gtx_if.tx_data  <= system_stream_out.tdata;
            gtx_if.tx_is_k  <= system_stream_out.tisk;
        end else if(alignment_valid && ~alignment_ready) begin
            gtx_if.tx_data  <= ALIGNMENT_WORD;
            gtx_if.tx_is_k  <= ALIGNMENT_IS_K;
            alignment_ready <= 1;
        end else begin
            gtx_if.tx_data  <= '0;
            gtx_if.tx_is_k  <= '0;
        end
    end

    assign system_stream_out.tready = !trig_valid && !beacon_valid;

// Delay compensation
    logic mmcm_locked;
    logic fifo_rst_busy;

    gtx::data_t fifo_in_data;
    gtx::data_t fifo_out_data;
    gtx::is_k_t fifo_in_isk;
    gtx::is_k_t fifo_out_isk;
    logic fifo_inc, fifo_dec, pll_ph_inc, pll_ph_dec;

    assign fifo_in_data = gtx_if.rx_data;
    assign fifo_in_isk  = gtx_if.rx_is_k ;
    assign ev = is_event(fifo_out_data, fifo_out_isk) ? ev_t'(fifo_out_data) : '0;

    fifo_wrapper #(
        .DEPTH(MAX_COMPENSATION)
    ) fifo_i (
        .app_rst(app_rst || !mmcm_locked),
        .app_clk(app_clk),
        .rx_clk(gtx_if.rx_clk),

        .data_in(fifo_in_data),
        .isk_in(fifo_in_isk),
        .data_out(fifo_out_data),
        .isk_out(fifo_out_isk),

        .fifo_inc(fifo_inc),
        .fifo_dec(fifo_dec),

        .rst_busy(fifo_rst_busy)
    );

    mmcm_wrapper mmcm_i(
        .clk_in1(gtx_if.rx_clk),
        .clk_in2(beacon_clk),
        .clk_in_sel(gtx_if.aligned),
        
        .clk_out1(app_clk),

        .ph_inc(pll_ph_inc),
        .ph_dec(pll_ph_dec),

        .reset(0),
        .locked(mmcm_locked)
    );

    dc_control #(
        .INT_W(DELAY_INT_W),
        .FRAC_W(DELAY_FRAC_W)
    ) dc_control_i (
        .app_clk(app_clk),
        .app_rst(app_rst || !mmcm_locked),
        .dc_ena(link_data.delay_comp_ena),
        .fifo_rst_busy(fifo_rst_busy),

        .start(is_beacon(fifo_in_data, fifo_in_isk)),
        .start_clk(gtx_if.rx_clk),
        .stop(is_beacon(fifo_out_data, fifo_out_isk)),
        .measure_clk(beacon_clk),

        .fifo_inc(fifo_inc),
        .fifo_dec(fifo_dec),
        .pll_ph_inc(pll_ph_inc),
        .pll_ph_dec(pll_ph_dec),
    
        .dc_status(link_data.delay_comp_st),
        .delay_req(link_data.tgt_delay - link_data.up_delay - link_data.link_delay),
        .delay_req_upd(link_data.tgt_delay_upd),
        
        .delay_comp(link_data.delay_comp)
    );
    assign link_data.link_up = gtx_if.aligned;
endmodule