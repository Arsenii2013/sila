`include "top.svh"
`include "evn.svh"
`include "axi4_lite_if.svh"

module evr
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
    
    output logic [23:0]     ev, // ev_valid = ev != 0
    input  logic [23:0]     trig, // trig_valid = trig != 0
    axi_stream_if.s         in_packet,
    axi_stream_if.m         out_packet
);
    assign app_clk = rx_clk;

    assign in_packet.tready = 0;
    assign out_packet.tvalid = 0;

    typedef logic [DELAY_INT_W+DELAY_FRAC_W-1: 0] delay_t;

// Event
    assign ev = (rx_data[31:24] == EVENT_COMMA && rx_charisk[3] == 1) ? rx_data : 0;

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
        end else if(alignment_valid && ~alignment_ready) begin
            tx_data         <= ALIGNMENT_WORD;
            tx_charisk      <= ALIGNMENT_IS_K;
            alignment_ready <= 1;
        end else begin
            tx_data         <= '0;
            tx_charisk      <= '0;
        end
    end

endmodule