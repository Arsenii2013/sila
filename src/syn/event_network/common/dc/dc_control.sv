module dc_control
#(
    INT_W  = 16,
    FRAC_W = 16
)
(
    input  logic                    app_clk,
    input  logic                    app_rst,

    input  logic                    beacon_in,
    input  logic                    rx_clk,
    input  logic                    beacon_out,
    input  logic                    beacon_clk,

    output logic                    fifo_inc,
    output logic                    fifo_dec,
    output logic                    pll_ph_inc,
    output logic                    pll_ph_dec,
 
    output logic [             3:0] dc_status,
    input  logic [INT_W+FRAC_W-1:0] delay_req,
    input  logic                    delay_req_upd,

    output logic [INT_W+FRAC_W-1:0] delay_comp
);
    typedef logic [INT_W+FRAC_W     -1: 0] delay_t;
    typedef logic [INT_W            -1: 0] sample_t;

    localparam delay_t  FINE_TRESH      = delay_t'((1<<FRAC_W) >> 9); // Для 175 МГц интервал 1/175e6 * 2**-9 = 11,16 пс
    localparam delay_t  PLL_HIST        = delay_t'((1<<FRAC_W) >> 9 + (1<<FRAC_W) >> 11); 
                                        // Для 175 МГц с множителем 8, F_vco = 1,4 ГГц 
                                        // шаг фазы равен 1/(56*1400) = 13 пс
                                        // 1/175e6 * (2**-9 + 2**-11) = 13,95 пс
    localparam delay_t  ONE_CYCLE_TRESH = delay_t'(1<<FRAC_W);
    localparam          FILTER_N        = 12;
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
    state_t state = mfsmZERO, next;

    logic       error_in_one_cycle;
    logic       error_in_fine;
    lock_time_t one_cycle_time    = LOCK_TIME;
    lock_time_t fine_time         = LOCK_TIME;

    assign error_in_one_cycle = delay_err < ONE_CYCLE_TRESH;
    assign error_in_fine      = delay_err < FINE_TRESH + PLL_HIST;

    assign dc_status = state;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            state <= mfsmZERO;
            one_cycle_time    <= LOCK_TIME;
            fine_time         <= LOCK_TIME;
        end else begin
            state <= next;
            if(state == mfsmINITIAL) begin
                if(delay_comp_upd) begin
                    if(error_in_one_cycle) begin
                        one_cycle_time    <= one_cycle_time - 1;
                    end else begin 
                        one_cycle_time    <= LOCK_TIME;
                    end 
                end
            end
            if(state == mfsmONECYCLE) begin
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
            next = mfsmERROR;
        end else if(delay_req_upd) begin
            next = mfsmINITIAL;
        end else begin
            case (state)
                mfsmZERO     : next = delay_comp_upd      ? mfsmINITIAL  : mfsmZERO;
                mfsmINITIAL  : next = one_cycle_time == 0 ? mfsmONECYCLE : mfsmINITIAL;
                mfsmONECYCLE : next = fine_time      == 0 ? mfsmFINE     : mfsmONECYCLE;
                mfsmFINE     : next = mfsmFINE;
                mfsmERROR    : next = mfsmZERO;
                default      : next = mfsmERROR;
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
        .beacon_tx(beacon_in),
        .tx_clk(rx_clk),
        .beacon_rx(beacon_out),
        .rx_clk(app_clk),
        .beacon_clk(beacon_clk),

        .app_clk(app_clk),
        .app_rst(app_rst || state == mfsmERROR),

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
        .rst(app_rst || state == mfsmERROR),

        .in(delay_t'(sample) << (FRAC_W-1)),
        .in_upd(sample_upd),
        .out(delay_comp),
        .out_upd(delay_comp_upd)
    );

    // Inc/Dec forming
    localparam CNT_WIDTH = FILTER_N-3;
    localparam CNT_MAX   = 2 ** CNT_WIDTH;

    logic [CNT_WIDTH-1: 0] pulse_form_cnt = 1;
    logic                  pulse_form;

    assign pulse_form = pulse_form_cnt == 0;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            pulse_form_cnt <= 1;
        end else begin
            if(delay_comp_upd || pulse_form_cnt == 0) begin
                pulse_form_cnt <= pulse_form_cnt - 1;
            end
        end
    end

    always_ff @(posedge app_clk) begin
        fifo_inc   <= 0;
        fifo_dec   <= 0;
        pll_ph_inc <= 0;
        pll_ph_dec <= 0;
        if (pulse_form) begin
            if (state <= mfsmINITIAL) begin
                if (delay_err_int != 0) begin
                    if (sign) fifo_inc <= 1;
                    else      fifo_dec <= 1;
                end
            end else begin
                if (delay_err_frac > FINE_TRESH + PLL_HIST) begin
                    if (sign) pll_ph_inc <= 1;
                    else      pll_ph_dec <= 1;
                end
            end
        end
    end
endmodule
