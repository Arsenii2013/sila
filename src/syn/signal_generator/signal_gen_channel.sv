module signal_gen_channel import signal_generator_pkg::*; (
    input  logic        app_clk,
    input  logic        app_rst,

    input  logic        set,
    input  logic        clear,
    input  logic        trigger,
    input  logic        cnt_reset,

    input  delay_t      delay,
    input  width_t      width,
    input  period_t     period,
    input  polarity_t   polarity,

    output logic        gen_out,


    input  signal_generator_pkg::trig_source_t trig_src,
    input  signal_generator_pkg::out_source_t  out_src
); 
    import signal_generator_pkg::*;

// Period Counter
    logic   period_cnt_eq;
    period_t period_cnt = '0;
    logic   period_start;
    assign  period_start   = cnt_reset || period_cnt_eq;
    assign  period_cnt_eq  = period_cnt == 'h1;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            period_cnt <= 2;
        end else begin
            if(period_start) begin
                period_cnt <= period + 2;
            end else if(period_cnt > 0) begin
                period_cnt <= period_cnt - 1;
            end else if(period_cnt == 0) begin
                period_cnt <= period_cnt;
            end
        end
    end

// Trig multiplexer
    logic trigger_1;
    always_ff @(posedge app_clk) trigger_1 <= trigger;
    logic trigger_iternal;

    always_comb begin
    case (trig_src)
        EVENT    : trigger_iternal = trigger_1;
        PERIOD   : trigger_iternal = period_cnt_eq;
        default  : trigger_iternal = 0;
    endcase
    end

// Single Pulse Generator
    logic gen_out_iternal;
    single_pulse_gen single_pulse_gen_i (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .set(set),
        .clear(clear),
        .trigger(trigger_iternal),
        .delay(delay),
        .width(width),
        .gen_out(gen_out_iternal)
    ); 

// Output multiplexer and polarity
    always_comb begin
    case (out_src)
        FORCE_SET   : gen_out = polarity == POSITIVE ? 0 : 1;
        FORCE_CLEAR : gen_out = polarity == POSITIVE ? 1 : 0;
        GENERATOR   : gen_out = polarity == POSITIVE ? !gen_out_iternal : gen_out_iternal;
        default     : gen_out = polarity == POSITIVE ? 1 : 0;
    endcase
    end

endmodule


module signal_gen_channelTB();
    localparam TEST_CYCLE_N = 10;
    import signal_generator_pkg::*;

    logic app_clk;
    logic app_rst = 0;
    delay_t  delay  = '0;
    width_t  width  = '0;
    period_t period = '0;
    logic cnt_reset = 0;
    logic gen_out;
    
    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    signal_gen_channel DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .set(0),
        .clear(0),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .delay(delay),
        .width(width),
        .period(period),
        .polarity(0),
        .gen_out(gen_out),
        .trig_src(signal_generator_pkg::PERIOD),
        .out_src(signal_generator_pkg::GENERATOR)
    );

    initial begin
        reset();
        cnt_reset <= 1;
        @(posedge app_clk);
        cnt_reset <= 0;

        PeriodicTest();
        #1us;
        $stop();
    end

    task PeriodicTest();
        test_start($sformatf("%m"));
        for(int test_period = 0; test_period < 10; test_period++) begin
            for(int test_delay = 0; test_delay < 10; test_delay++) begin
                for(int test_width = 0; test_width < 10; test_width++) begin
                    if(test_delay <= test_period + 1 && test_width <= test_period)
                        periodic_valid_subtest(test_period, test_delay, test_width);
                    else if(test_delay > test_period + 1 && test_width <= test_period)
                        periodic_dnwv_subtest(test_period, test_delay, test_width);
                    else if(test_delay <= test_period + 1 && test_width > test_period)
                        periodic_dvwn_subtest(test_period, test_delay, test_width);
                    else
                        periodic_dnwn_subtest(test_period, test_delay, test_width);
                    #100ns;
                end
            end
        end
    endtask

    task periodic_valid_subtest(input period_t test_period, input delay_t test_delay, input width_t test_width);
        $display("periodic all valid subtest: \t\t\t period %d, delay %d, width %d", test_period, test_delay, test_width);
        delay  <= test_delay;
        width  <= test_width;
        period <= test_period;
        @(posedge app_clk);
        @(posedge DUT.trigger_iternal);
        @(posedge app_clk);
        for(int j = 0; j <= test_delay; j ++) begin
            @(posedge app_clk);
            assert(gen_out == 0) else $display("expect 0 but got 1");
        end
        for(int i = 0; i < TEST_CYCLE_N; i ++) begin
            for(int j = 0; j <= test_width; j ++) begin
                @(posedge app_clk);
                assert(gen_out == 1) else $display("expect 1 but got 0 at %d", i);
            end
            for(int j = 0; j <= test_period-test_width; j ++) begin
                @(posedge app_clk);
                assert(gen_out == 0) else $display("expect 0 but got 1 at %d", i);
            end

        end
    endtask

    task periodic_dnwv_subtest(input period_t test_period, input delay_t test_delay, input width_t test_width);
        $display("periodic delay invalid subtest: period %d, delay %d, width %d", test_period, test_delay, test_width);
        delay  <= test_delay;
        width  <= test_width;
        period <= test_period;
        @(posedge app_clk);
        for(int i = 0; i < TEST_CYCLE_N; i ++) begin
            @(posedge DUT.trigger_iternal);
        end
        @(posedge app_clk);
        for(int j = 0; j <= test_delay; j ++) begin
            @(posedge app_clk);
            assert(gen_out == 0) else $display("expect 0 but got 1");
        end
        for(int j = 0; j <= test_width; j ++) begin
            @(posedge app_clk);
            assert(gen_out == 1) else $display("expect 1 but got 0");
        end
    endtask

    task periodic_dvwn_subtest(input period_t test_period, input delay_t test_delay, input width_t test_width);
        $display("periodic width invalid subtest: period %d, delay %d, width %d", test_period, test_delay, test_width);
        delay  <= test_delay;
        width  <= test_width;
        period <= test_period;
        @(posedge DUT.trigger_iternal);
        @(posedge app_clk);
        for(int j = 0; j <= test_delay; j ++) begin
            @(posedge app_clk);
            assert(gen_out == 0) else $display("expect 0 but got 1");
        end
        for(int j = 0; j <= test_width; j ++) begin
            @(posedge app_clk);
            assert(gen_out == 1) else $display("expect 1 but got 0");
        end
    endtask

    task periodic_dnwn_subtest(input period_t test_period, input delay_t test_delay, input width_t test_width);
        if(test_delay > test_period + 1)
            periodic_dnwv_subtest(test_period, test_delay, test_width);
        else begin
            $display("periodic all invalid subtest: period %d, delay %d, width %d", test_period, test_delay, test_width);
            delay <= test_delay;
            width <= test_width;
            period <= test_period;
            @(posedge DUT.trigger_iternal);
            @(posedge trigger);
            @(posedge app_clk);
            #1us;
        end
    endtask

    int test_number = 0;
    task test_start(input string name);
        test_number <= test_number + 1;
        @(posedge app_clk);
        $display("Start %s test with numder %d", name, test_number);
    endtask

    task reset();
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst <= 0;
    endtask
endmodule