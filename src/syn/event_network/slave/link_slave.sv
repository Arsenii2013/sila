`include "top.svh"
`include "evn.svh"
`include "axi4_lite_if.svh"

module link_slave
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
        .clk(rx_clk),
        .in(rx_data == BEACON_WORD && rx_charisk == BEACON_IS_K),
        .out(beacon_pulse)
    );
    logic beacon_pulse_sync;
    xpm_cdc_pulse beacon_sunchronizer_i(
        .dest_clk(tx_clk),
        .dest_pulse(beacon_pulse_sync),
        .dest_rst(app_rst),
        .src_clk(rx_clk),
        .src_pulse(beacon_pulse),
        .src_rst(app_rst)
    );

    logic beacon_valid = 0;
    logic beacon_ready = 0;

    always_ff @(posedge tx_clk) begin
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
    system_stream_if #(.DW(32)) system_stream_in();
    system_stream_if #(.DW(32)) system_stream_out();
    assign system_stream_in.tdata  = rx_data;
    assign system_stream_in.tisk   = rx_charisk;
    assign system_stream_in.tvalid = rx_charisk == 0 || (rx_data[31:24] == PACKET_COMMA && rx_charisk == PACKET_START_IS_K);

    slave_system_packet_reciever system_packet_reciever_i(
        .rx_clk(rx_clk),
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
        .tx_clk(tx_clk),
        .app_clk(app_clk),
        .app_rst(app_rst),
        .sub_delay(link_data.sub_delay),
        .send_sub_delay(link_data.sub_delay_upd),
        .out(system_stream_out)
    );


// Mux
    always_ff @(posedge tx_clk) begin
        alignment_ready <= 0;
        beacon_ready    <= 0;
        tx_data         <= '0;
        tx_charisk      <= '0;

        if(trig_valid) begin
            tx_data         <= {TRIGGER_COMMA, trig};
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

    assign system_stream_out.tready = !trig_valid && !beacon_valid;

// Delay compensation
    logic mmcm_locked;
    logic fifo_rst_busy;

    logic [31:0] fifo_in_data;
    logic [31:0] fifo_out_data;
    logic [ 3:0] fifo_in_isk;
    logic [ 3:0] fifo_out_isk;
    logic fifo_inc, fifo_dec, pll_ph_inc, pll_ph_dec;

    assign fifo_in_data = (rx_data[31:24] == EVENT_COMMA && rx_charisk == 'h8        ) ||
                          (rx_data == BEACON_WORD        && rx_charisk == BEACON_IS_K) 
                          ? rx_data : '0;
    assign fifo_in_isk  = (rx_data[31:24] == EVENT_COMMA && rx_charisk == 'h8        ) ||
                          (rx_data == BEACON_WORD        && rx_charisk == BEACON_IS_K) 
                          ? rx_charisk : '0;
    assign ev = (fifo_out_data[31:24] == EVENT_COMMA && fifo_out_isk == 'h8        )
                ? fifo_out_data[23:0] : '0;

    fifo_wrapper #(
        .DEPTH(MAX_COMPENSATION)
    ) fifo_i (
        .app_rst(app_rst || !mmcm_locked),
        .app_clk(app_clk),
        .rx_clk(rx_clk),

        .data_in(fifo_in_data),
        .isk_in(fifo_in_isk),
        .data_out(fifo_out_data),
        .isk_out(fifo_out_isk),

        .fifo_inc(fifo_inc),
        .fifo_dec(fifo_dec),

        .rst_busy(fifo_rst_busy)
    );

    mmcm_wrapper mmcm_i(
        .clk_in1(rx_clk),
        .clk_in2(beacon_clk),
        .clk_in_sel(aligned),
        
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

        .beacon_in((fifo_in_data == BEACON_WORD) && (fifo_in_isk == BEACON_IS_K)),
        .rx_clk(rx_clk),
        .beacon_out((fifo_out_data == BEACON_WORD) && (fifo_out_isk == BEACON_IS_K)),
        .beacon_clk(beacon_clk),

        .fifo_inc(fifo_inc),
        .fifo_dec(fifo_dec),
        .pll_ph_inc(pll_ph_inc),
        .pll_ph_dec(pll_ph_dec),
    
        .dc_status(link_data.delay_comp_st),
        .delay_req(link_data.tgt_delay - link_data.up_delay - link_data.link_delay),
        .delay_req_upd(link_data.tgt_delay_upd),
        
        .delay_comp(link_data.delay_comp)
    );
    assign link_data.link_up = aligned;
endmodule