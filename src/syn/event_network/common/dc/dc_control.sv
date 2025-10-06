`include "evn.svh"

module dc_control
#(
    INT_W  = 16,
    FRAC_W = 16
)
(
    input  logic                    app_clk,
    input  logic                    app_rst,

    input  logic                    start,
    input  logic                    start_clk,
    input  logic                    stop,
    input  logic                    measure_clk,

    output logic                    fifo_inc,
    output logic                    fifo_dec,
    output logic                    pll_ph_inc,
    output logic                    pll_ph_dec,

    input  logic                    dc_ena,
    input  logic                    fifo_rst_busy,
 
    output evn::link_delay_st_t     dc_status,
    input  evn::delay_t             delay_req,
    input  logic                    delay_req_upd,

    output evn::delay_t             delay_comp
);
    import evn::*;
    typedef logic [INT_W            -1: 0] sample_t;

    localparam delay_t  FINE_TRESH      = delay_t'(((1<<FRAC_W) >> 10) + ((1<<FRAC_W) >> 12)); 
                                        // Для 125 МГц интервал 1/125e6 * 2**-10 = 7,8 пс
    localparam delay_t  PLL_HIST        = delay_t'(((1<<FRAC_W) >> 10) + ((1<<FRAC_W) >> 11) + ((1<<FRAC_W) >> 12)); 
                                        // Для 125 МГц с множителем 11, F_vco = 1,375 ГГц 
                                        // шаг фазы равен 1/(56*1375) = 12,9 пс
                                        // 1/175e6 * (2**-10 + 2**-100) = 13,67 пс
    localparam delay_t  ONE_CYCLE_TRESH = delay_t'(1<<FRAC_W);
    localparam          FILTER_N        = 20;
    localparam          LOCK_TIME       = 2**FILTER_N;
    localparam          BEACON_PERIOD_W = $clog2(BEACON_PERIOD);

    typedef logic [$clog2(LOCK_TIME) : 0] lock_time_t;

    typedef link_delay_st_t state_t;

    logic    delay_comp_upd;
    logic    sample_error;

    // Delay errors calculation
    logic sign;
    delay_t delay_err, delay_err_int, delay_err_frac;

    assign sign               = delay_req > delay_comp;
    assign delay_err          = delay_req > delay_comp ? delay_req - delay_comp : delay_comp - delay_req;

    assign delay_err_int      = delay_err[INT_W+FRAC_W-1     -: INT_W ];
    assign delay_err_frac     = delay_err[FRAC_W-1           -: FRAC_W];

    // State machine
    state_t state = ZERO, next;

    logic       error_in_one_cycle;
    logic       error_in_fine;
    lock_time_t one_cycle_time    = LOCK_TIME;
    lock_time_t fine_time         = LOCK_TIME;

    assign error_in_one_cycle = delay_err < ONE_CYCLE_TRESH;
    assign error_in_fine      = delay_err < FINE_TRESH + PLL_HIST;

    assign dc_status = state;

    always_ff @(posedge app_clk) begin
        if(app_rst || !dc_ena) begin
            state <= ZERO;
            one_cycle_time    <= LOCK_TIME;
            fine_time         <= LOCK_TIME;
        end else begin
            state <= next;
            if(state == ZERO) begin
                one_cycle_time <= LOCK_TIME;
                fine_time      <= LOCK_TIME;
            end
            if(state == INITIAL) begin
                if(delay_comp_upd) begin
                    if(error_in_one_cycle) begin
                        one_cycle_time    <= one_cycle_time - 1;
                    end else begin 
                        one_cycle_time    <= LOCK_TIME;
                    end 
                end
            end
            if(state == ONE_CYCLE) begin
                if(delay_comp_upd) begin
                    if(error_in_fine) begin
                        fine_time    <= fine_time - 1;
                    end else begin 
                        fine_time    <= LOCK_TIME;
                    end 
                end
            end
        end
    end

    always_comb begin
        if(sample_error) begin
            next = ERROR;
        end else if(delay_req_upd) begin
            next = ZERO;
        end else begin
            case (state)
                ZERO     : next = delay_comp_upd      ? INITIAL  : ZERO;
                INITIAL  : next = one_cycle_time == 0 ? ONE_CYCLE : INITIAL;
                ONE_CYCLE : next = fine_time      == 0 ? FINE     : ONE_CYCLE;
                FINE     : next = FINE;
                ERROR    : next = ZERO;
                default      : next = ERROR;
            endcase
        end
    end

    // Delay measure
    sample_t sample;
    logic    sample_upd;

    sampler #(
        .INT_W(INT_W),
        .BEACON_PERIOD_W(BEACON_PERIOD_W)
    ) sampler_i (
        .start(start),
        .start_clk(start_clk),
        .stop(stop),
        .stop_clk(app_clk),
        .measure_clk(measure_clk),

        .app_clk(app_clk),
        .app_rst(app_rst || fifo_rst_busy  || state == ERROR),

        .fine(state == FINE),
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
        .rst(app_rst || fifo_rst_busy || state == ERROR),

        .in(delay_t'(sample) << (FRAC_W)),
        .in_upd(sample_upd),
        .out(delay_comp),
        .out_upd(delay_comp_upd)
    );

    // Inc/Dec forming
    // при увеличении задержки на 2**16 ошибка меньше 1 такта будет через 
    // ln(2××16/1) = 11 постоянных времени. Возьмем степень 2**3 = 8 постоянных времени
    // а для подстройки фазы используем гораздо меньший период например 1/8 постоянной времени
    localparam CNT_FIFO  = 2**(FILTER_N+3) - 1;
    localparam CNT_PLL   = 2**(FILTER_N-2) - 1;
    localparam CNT_WIDTH = $clog2(CNT_FIFO);

    logic [CNT_WIDTH-1: 0] pulse_form_cnt = 1;
    logic                  pulse_form;

    assign pulse_form = pulse_form_cnt == 0;

    always_ff @(posedge app_clk) begin
        if(app_rst || !dc_ena) begin
            pulse_form_cnt <= 1;
        end else begin
            if(delay_comp_upd) begin
                pulse_form_cnt <= pulse_form_cnt - 1;
            end else if (pulse_form_cnt == 0) begin
                if(state <= INITIAL) begin
                    pulse_form_cnt <= CNT_FIFO;
                end else begin
                    pulse_form_cnt <= CNT_PLL;
                end
            end else begin
                pulse_form_cnt <= pulse_form_cnt;
            end
        end
    end

    inc_dec_former #(
        .PULSE_CNT_W(INT_W),
        .TIMEOUT(32)
    ) fifo_inc_dec (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .sign(sign),
        .count(delay_err_int),
        .start(pulse_form && state <= INITIAL),
        .inc(fifo_inc),
        .dec(fifo_dec)
    );

    inc_dec_former #(
        .PULSE_CNT_W(FRAC_W),
        .TIMEOUT(32)
    ) pll_inc_dec (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .sign(sign),
        .count((delay_err_int != 0 || (delay_err_frac > FINE_TRESH + PLL_HIST)) ? 1 : 0),
        .start(pulse_form && state > INITIAL),
        .inc(pll_ph_inc),
        .dec(pll_ph_dec)
    );
endmodule

module inc_dec_former #(
    parameter PULSE_CNT_W       = 16,
    parameter TIMEOUT           = 32
)
(
    input  logic                     app_clk,
    input  logic                     app_rst,
    input  logic                     sign,
    input  logic [PULSE_CNT_W -1: 0] count,
    input  logic                     start,
    output logic                     inc,
    output logic                     dec
);    
    typedef logic [PULSE_CNT_W     -1: 0] count_t;
    typedef logic [$clog2(TIMEOUT) -1: 0] timeout_cnt_t;

    typedef enum
    {
        WAIT_START,
        PULSE,
        PULSE_TIMEOUT
    } state_t;

    count_t count_reg = '0;
    logic   sign_reg  = 0;
    state_t state = WAIT_START, next;

    timeout_cnt_t timeout_cnt = TIMEOUT-1;

    assign inc =  sign_reg ? state == PULSE : 0;
    assign dec = !sign_reg ? state == PULSE : 0;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            count_reg   <= '0;
            sign_reg    <= 0;
            state       <= WAIT_START;
            timeout_cnt <= TIMEOUT-1;
        end else begin
            state <= next;
            if(state == WAIT_START && start) begin
                count_reg   <= count;
                sign_reg    <= sign;
            end
            if(state == PULSE) begin
                count_reg   <= count_reg   - 1;
                timeout_cnt <= TIMEOUT-1;
            end
            if(state == PULSE_TIMEOUT) begin
                timeout_cnt <= timeout_cnt - 1;
            end
        end
    end

    always_comb begin
        case (state)
            WAIT_START    : next = start             ? PULSE_TIMEOUT  : WAIT_START;
            PULSE         : next = PULSE_TIMEOUT;
            PULSE_TIMEOUT : begin
                if(timeout_cnt == '0) begin
                    if(count_reg == '0)
                        next = WAIT_START;
                    else 
                        next = PULSE;
                end else 
                    next = PULSE_TIMEOUT;
            end
            default       : next = WAIT_START;
        endcase
    end

endmodule


module inc_dec_formerTB ();
    logic app_clk, app_rst;
    sys_clk_gen
    #(
        .halfcycle (4000), // 4000 ps = 125 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    logic sign, start;
    logic [15:0] cnt;

    inc_dec_former DUT(
        .app_clk(app_clk),
        .app_rst(app_rst),
        .sign(sign),
        .count(cnt),
        .start(start),
        .inc(),
        .dec()
    );


    initial begin
        sign    <= 0;
        cnt     <= 1;
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst <= 0;
        @(posedge app_clk);
        @(posedge app_clk);
        start   <= 1;
        @(posedge app_clk);
        start   <= 0;
        #10us;
        $stop();
    end

endmodule