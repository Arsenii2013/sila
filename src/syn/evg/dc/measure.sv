`timescale 1ns / 1fs

//------------------------------------------------
module delay_measure #(
    parameter INT_W  = 16,
    parameter FRAC_W = 16
)
(
    input  logic                     app_clk,
    input  logic                     app_rst,
    
    input  logic                     beacon_tx,
    input  logic                     tx_clk,
    input  logic                     beacon_rx,
    input  logic                     rx_clk,
    input  logic                     beacon_clk,

    output logic                     delay_upd,
    output logic [INT_W+FRAC_W-1: 0] delay,
    output logic [4             : 0] delay_status
);
    typedef logic [INT_W+FRAC_W     -1: 0] delay_t;
    typedef logic [INT_W            -1: 0] sample_t;

    localparam delay_t  FINE_TRESH      = delay_t'((1<<FRAC_W) >> 9); // Для 175 МГц интервал 1/175e6/2**9 = 11,16 ps
    localparam delay_t  ONE_CYCLE_TRESH = delay_t'(1<<FRAC_W);
    localparam          FILTER_N        = 12;
    localparam          LOCK_TIME       = 2**FILTER_N;
    `ifdef SYNTHESIS
    localparam sample_t BEACON_TIMEOUT  = '1;
    `else
    localparam sample_t BEACON_TIMEOUT  = 1000; // 1000 тактов, примерно 5700 нс
    `endif

    typedef logic [$clog2(LOCK_TIME) : 0] lock_time_t;

    typedef enum
    {
        mfsmZERO = 0,
        mfsmINITIAL = 1,
        mfsmONECYCLE = 3,
        mfsmFINE = 7,
        mfsmERROR = 8
    } state_t;

    state_t state = mfsmZERO;
    state_t next;
    logic   lock_lost;

    assign lock_lost = state == mfsmERROR;

    sample_t sample;
    logic    sample_upd;
    logic    sample_error;
    delay_t  average;
    logic    average_upd;

    assign delay        = average;
    assign delay_upd    = average_upd;
    assign delay_status = state;

    delay_t     average_one_cycle = '0;
    delay_t     average_fine      = '0;
    logic       average_in_one_cycle;
    logic       average_in_fine;
    lock_time_t one_cycle_time    = LOCK_TIME;
    lock_time_t fine_time         = LOCK_TIME;

    assign average_in_one_cycle = average > average_one_cycle ? 
                                  average - average_one_cycle < ONE_CYCLE_TRESH : 
                                  average_one_cycle - average < ONE_CYCLE_TRESH;

    assign average_in_fine      = average > average_fine ? 
                                  average - average_fine < FINE_TRESH : 
                                  average_fine - average < FINE_TRESH;


    always_ff @(posedge app_clk) begin 
        if(app_rst || lock_lost) begin
            state             <= mfsmZERO;
            average_one_cycle <= 0;
            average_fine      <= 0;
            one_cycle_time    <= LOCK_TIME;
            fine_time         <= LOCK_TIME;
        end else begin
            state <= next;
            if(state == mfsmINITIAL) begin
                if(average_upd) begin
                    if(average_in_one_cycle) begin
                        one_cycle_time    <= one_cycle_time - 1;
                        average_one_cycle <= average_one_cycle;
                    end else begin 
                        one_cycle_time    <= LOCK_TIME;
                        average_one_cycle <= average;
                    end 
                end
            end
            if(state == mfsmONECYCLE) begin
                if(average_upd) begin
                    if(average_in_fine) begin
                        fine_time    <= fine_time - 1;
                        average_fine <= average_fine;
                    end else begin 
                        fine_time    <= LOCK_TIME;
                        average_fine <= average;
                    end 
                end
            end
        end
    end

    always_comb begin
        case (state)
            mfsmZERO     : next = sample_error ? mfsmERROR : average_upd         ? mfsmINITIAL  : mfsmZERO;
            mfsmINITIAL  : next = sample_error ? mfsmERROR : one_cycle_time == 0 ? mfsmONECYCLE : mfsmINITIAL;
            mfsmONECYCLE : next = sample_error ? mfsmERROR : fine_time      == 0 ? mfsmFINE     : mfsmONECYCLE;
            mfsmFINE     : next = sample_error ? mfsmERROR : mfsmFINE;
            mfsmERROR    : next = mfsmZERO;
            default      : next = mfsmERROR;
        endcase
    end

    sampler #(
        .INT_W(INT_W),
        .TIMEOUT(BEACON_TIMEOUT)
    ) sampler_i (
        .beacon_tx(beacon_tx),
        .tx_clk(tx_clk),
        .beacon_rx(beacon_rx),
        .rx_clk(rx_clk),
        .beacon_clk(beacon_clk),

        .app_clk(app_clk),
        .app_rst(app_rst || lock_lost),

        .fine(state == mfsmFINE),
        .sample_upd(sample_upd),
        .sample(sample),
        .error(sample_error)
    );
    
    filter #(
        .INT_W(INT_W),
        .FRAC_W(FRAC_W),
        .N(FILTER_N)
    ) filter_i (
        .clk(app_clk),
        .rst(app_rst || lock_lost),

        .in(delay_t'(sample) << (FRAC_W-1)),
        .in_upd(sample_upd),
        .out(average),
        .out_upd(average_upd)
    );
endmodule 

module sampler #(
    parameter INT_W                        = 16,
    parameter logic [INT_W  -1: 0] TIMEOUT = '1
)
(
    input  logic                     beacon_tx,
    input  logic                     tx_clk,
    input  logic                     beacon_rx,
    input  logic                     rx_clk,
    input  logic                     beacon_clk,

    input  logic                     app_clk,
    input  logic                     app_rst,
    input  logic                     fine,
    output logic                     sample_upd,
    output logic [INT_W       -1: 0] sample,
    output logic                     error
);
    typedef enum
    {
        mfsmWAIT,
        mfsmCOUNT,
        mfsmCHECK
    } state_t;

    typedef logic [INT_W  -1: 0] sample_t;

    logic beacon_rx_sync;
    logic beacon_tx_sync;

    beacon_cdc beacon_cdc_i(
        .beacon_tx(beacon_tx),
        .tx_clk(tx_clk),
        .beacon_rx(beacon_rx),
        .rx_clk(rx_clk),
        .beacon_clk(beacon_clk),
        .beacon_rx_sync(beacon_rx_sync),
        .beacon_tx_sync(beacon_tx_sync)
    );

    logic beacon_rst;

    xpm_cdc_sync_rst beacon_rst_sunchronizer_i(
        .dest_clk(beacon_clk),
        .dest_rst(beacon_rst),
        .src_rst(app_rst)
    );

    logic fine_sync;

    xpm_cdc_single fine_sunchronizer_i(
        .dest_clk(beacon_clk),
        .dest_out(fine_sync),
        .src_clk(app_clk),
        .src_in(fine)
    );

    // sample не синхронизовывал, потому что считаю, что 
    // он будет читаться по импульсу sample_upd, 
    // который в свою очередь синхронизуется 4 такта
    // и sample успеет установиться за это время

    logic sample_upd_sync = 0;
    logic error_sync = 0;

    xpm_cdc_pulse sample_upd_sunchronizer_i(
        .dest_clk(app_clk),
        .dest_pulse(sample_upd),
        .dest_rst(1'b0),
        .src_clk(beacon_clk),
        .src_pulse(sample_upd_sync),
        .src_rst(1'b0)
    );
    xpm_cdc_pulse error_sunchronizer_i(
        .dest_clk(app_clk),
        .dest_pulse(error),
        .dest_rst(1'b0),
        .src_clk(beacon_clk),
        .src_pulse(error_sync),
        .src_rst(1'b0)
    );

    state_t     state = mfsmWAIT;

    sample_t    cnt         = '0;
    sample_t    prev_sample = '0;

    logic sample_valid;

    always_ff @(posedge beacon_clk) begin
        if (beacon_rst) begin
            state           <= mfsmWAIT;
            cnt             <= '0;
            sample          <= '0;
            prev_sample     <= '0;
            sample_upd_sync <= '0;
            error_sync      <= '0;
        end
        else begin
            case (state)
                mfsmWAIT: begin 
                    cnt             <= '0;
                    sample_upd_sync <= 0;
                    if (beacon_tx_sync)
                        state <= mfsmCOUNT;
                end
                mfsmCOUNT: begin
                    cnt <= sample_t'(cnt + 1);
                    if (beacon_tx_sync) 
                        cnt   <= 0;
                    else if (beacon_rx_sync || cnt == TIMEOUT - 1) begin
                        state <= mfsmCHECK;
                    end
                end
                mfsmCHECK: begin
                    if(sample_valid) begin
                        sample_upd_sync <= 1;
                        sample          <= cnt;
                        prev_sample     <= sample;
                    end else begin
                        error_sync      <= 1;
                    end
                    state <= mfsmWAIT;
                end
            endcase
        end
    end

    always_comb begin
        if(fine_sync)
            sample_valid = (cnt != TIMEOUT) && (sample > prev_sample ? sample - prev_sample < sample_t'(4) : prev_sample - sample < sample_t'(4));
        else 
            sample_valid =  cnt != TIMEOUT;
    end
endmodule

module beacon_cdc(
    input  logic beacon_tx,
    input  logic tx_clk,
    input  logic beacon_rx,
    input  logic rx_clk,
    input  logic beacon_clk,
    output logic beacon_tx_sync,
    output logic beacon_rx_sync
);
    logic       beacon_rx_expand;
    logic [1:0] beacon_rx_cnt = '0;

    assign beacon_rx_expand = beacon_rx_cnt != 'b0;

    always_ff @(posedge rx_clk) begin
        if(beacon_rx) 
            beacon_rx_cnt <= 2'b11;
        else
            if(beacon_rx_cnt != 2'b0)
                beacon_rx_cnt <= beacon_rx_cnt - 1;         
    end

    xpm_cdc_pulse beacon_rx_sunchronizer_i(
        .dest_clk(beacon_clk),
        .dest_pulse(beacon_rx_sync),
        .dest_rst(1'b0),
        .src_clk(rx_clk),
        .src_pulse(beacon_rx_expand),
        .src_rst(1'b0)
    );


    logic       beacon_tx_expand;
    logic [1:0] beacon_tx_cnt = '0;

    assign beacon_tx_expand = beacon_tx_cnt != 'b0;

    always_ff @(posedge tx_clk) begin
        if(beacon_tx) 
            beacon_tx_cnt <= 2'b11;
        else
            if(beacon_tx_cnt != 2'b0)
                beacon_tx_cnt <= beacon_tx_cnt - 1;         
    end

    xpm_cdc_pulse beacon_tx_sunchronizer_i(
        .dest_clk(beacon_clk),
        .dest_pulse(beacon_tx_sync),
        .dest_rst(1'b0),
        .src_clk(tx_clk),
        .src_pulse(beacon_tx_expand),
        .src_rst(1'b0)
    );
endmodule

//------------------------------------------------
//
//      First order exponential FIR described by eq:
//      Yn = Yn-1 - Yn-1/T + Xn/T , where 
//      1. T is defined as 2^N for this module
//      2. Optimal N for f = 175 MHz, delta_f = 30 kHz, 
//         beacon_psc = 2**10, is 12
//------------------------------------------------
module filter #(
    parameter INT_W  = 16,
    parameter FRAC_W = 16,
    parameter N      = 12
)
(
    input  logic                     clk,
    input  logic                     rst,

    input  logic [INT_W+FRAC_W-1: 0] in,
    input  logic                     in_upd,
    output logic [INT_W+FRAC_W-1: 0] out,
    output logic                     out_upd
);

//------------------------------------------------
localparam ACC_W = INT_W + FRAC_W;

//------------------------------------------------
typedef logic [ACC_W -1: 0] acc_t;

//------------------------------------------------
acc_t acc = '0;
acc_t fdb;
acc_t sample;

assign out    = acc;

//------------------------------------------------
assign fdb    = acc >> N;
assign sample = in  >> N;

always_ff @(posedge clk) begin
    if (rst) begin
        acc <= '0;
    end
    else begin
        if (in_upd) begin
            acc     <= acc - fdb + sample;
            out_upd <= 1;
        end else begin
            out_upd <= 0;
        end
    end
end
endmodule 