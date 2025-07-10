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
    output logic [3             : 0] delay_status
);
    typedef logic [INT_W+FRAC_W     -1: 0] delay_t;
    typedef logic [INT_W            -1: 0] sample_t;

    localparam delay_t  FINE_TRESH      = delay_t'(((1<<FRAC_W) >> 10) + ((1<<FRAC_W) >> 12)); 
                                        // Для 125 МГц интервал 1/125e6 * 2**-10 = 7,8 пс
    localparam delay_t  ONE_CYCLE_TRESH = delay_t'(1<<FRAC_W);
    localparam          FILTER_N        = 20;
    localparam          LOCK_TIME       = 2**FILTER_N;
    localparam          BEACON_PERIOD_W = $clog2(BEACON_PERIOD);

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
        .BEACON_PERIOD_W(BEACON_PERIOD_W)
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

        .in(delay_t'(sample) << (FRAC_W-1)), // сдвиг для приведения к delay_t и -1 для деления на два
        .in_upd(sample_upd),
        .out(average),
        .out_upd(average_upd)
    );
endmodule 
