`include "top.svh"
`include "evn.svh"
`include "axi4_lite_if.svh"

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
    
    input  logic [23:0]     ev, // ev_valid = ev != 0
    output logic [23:0]     trig, // trig_valid = trig != 0
    axi_stream_if.s         in_packet,
    axi_stream_if.m         out_packet
);
    assign app_clk = tx_clk;

    assign in_packet.tready = 0;
    assign out_packet.tvalid = 0;

// Event
    logic ev_valid;
    assign ev_valid = ev != '0;
    

// Beacon
    logic beacon_valid = 0;
    logic beacon_ready;
    beacon_cnt_t beacon_cnt = BEACON_PERIOD;

    always_ff @(posedge tx_clk) begin
        if(app_rst) begin
            beacon_cnt   <= BEACON_PERIOD;
            beacon_valid <= 0;
        end else begin
            if(beacon_cnt == 0) begin
                beacon_cnt   <= BEACON_PERIOD;
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
    logic alignment_ready;
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
        end else if(alignment_valid && ~alignment_ready) begin
            tx_data         <= ALIGNMENT_WORD;
            tx_charisk      <= ALIGNMENT_IS_K;
            alignment_ready <= 1;
        end 
    end

endmodule