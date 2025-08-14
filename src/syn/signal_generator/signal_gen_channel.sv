package signal_gen_ctrl_pkg;

import signal_gen_ctrl_axi_core_pkg::*;

localparam signal_gen_ctrl_axi_core__output_src_t_e SET_EVAL       = signal_gen_ctrl_axi_core__output_src_t__FORCE_SET;
localparam signal_gen_ctrl_axi_core__output_src_t_e CLEAR_EVAL     = signal_gen_ctrl_axi_core__output_src_t__FORCE_CLEAR;
localparam signal_gen_ctrl_axi_core__output_src_t_e GENERATOR_EVAL = signal_gen_ctrl_axi_core__output_src_t__GENERATOR;
localparam signal_gen_ctrl_axi_core__trig_src_t_e   EVENT_EVAL     = signal_gen_ctrl_axi_core__trig_src_t__EVENT;
localparam signal_gen_ctrl_axi_core__trig_src_t_e   PERIOD_EVAL    = signal_gen_ctrl_axi_core__trig_src_t__PERIOD;

localparam OUT_SET       = unsigned'(SET_EVAL);
localparam OUT_CLEAR     = unsigned'(CLEAR_EVAL);
localparam OUT_GENERATOR = unsigned'(GENERATOR_EVAL);
localparam TRIG_EVENT    = unsigned'(EVENT_EVAL);
localparam TRIG_PERIOD   = unsigned'(PERIOD_EVAL);

typedef enum logic [0:0] {
    EVENT      = signal_gen_ctrl_pkg::TRIG_EVENT,
    PERIOD     = signal_gen_ctrl_pkg::TRIG_PERIOD
} trig_source_t;

typedef enum logic [1:0] {
    FORCE_SET   = signal_gen_ctrl_pkg::OUT_SET,
    FORCE_CLEAR = signal_gen_ctrl_pkg::OUT_CLEAR,
    GENERATOR   = signal_gen_ctrl_pkg::OUT_GENERATOR
} output_source_t;

endpackage

module signal_gen_channel #(
    parameter PERIOD_W = 64,
    parameter DELAY_W  = 64,
    parameter WIDTH_W  = 64
) (
    input  logic                 app_clk,
    input  logic                 app_rst,

    input  logic                 set,
    input  logic                 clear,
    input  logic                 trigger,
    input  logic                 cnt_reset,

    input  logic [DELAY_W -1: 0] delay,
    input  logic [WIDTH_W -1: 0] width,
    input  logic [PERIOD_W-1: 0] period,
    input  logic                 polarity,

    output logic                 gen_out,


    input  signal_gen_ctrl_pkg::trig_source_t   trig_src,
    input  signal_gen_ctrl_pkg::output_source_t out_src
); 
    typedef logic [PERIOD_W-1: 0] period_t;
    typedef logic [DELAY_W -1: 0] delay_t;
    typedef logic [WIDTH_W -1: 0] width_t;

    import signal_gen_ctrl_pkg::*;

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
    single_pulse_gen #(
        .DELAY_W(DELAY_W),
        .WIDTH_W(WIDTH_W)
    ) single_pulse_gen_i (
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
        FORCE_SET   : gen_out = polarity ? 0 : 1;
        FORCE_CLEAR : gen_out = polarity ? 1 : 0;
        GENERATOR   : gen_out = polarity ? !gen_out_iternal : gen_out_iternal;
        default     : gen_out = polarity ? 1 : 0;
    endcase
    end

endmodule


module signal_gen_channelTB();
localparam TEST_CYCLE_N = 10;
    logic app_clk;
    logic app_rst = 0;
    logic [63:0] delay  = 0;
    logic [63:0] width  = 0;
    logic [63:0] period = 0;
    logic cnt_reset = 0;
    logic gen_out;
    
    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    signal_gen_channel #(
        .PERIOD_W(64),
        .DELAY_W(64),
        .WIDTH_W(64)
    ) DUT (
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
        .trig_src(signal_gen_ctrl_pkg::PERIOD),
        .out_src(signal_gen_ctrl_pkg::GENERATOR)
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

    task periodic_valid_subtest(input logic [63:0] test_period, input logic [63:0] test_delay, input logic [63:0] test_width);
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

    task periodic_dnwv_subtest(input logic [63:0] test_period, input logic [63:0] test_delay, input logic [63:0] test_width);
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

    task periodic_dvwn_subtest(input logic [63:0] test_period, input logic [63:0] test_delay, input logic [63:0] test_width);
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

    task periodic_dnwn_subtest(input logic [63:0] test_period, input logic [63:0] test_delay, input logic [63:0] test_width);
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