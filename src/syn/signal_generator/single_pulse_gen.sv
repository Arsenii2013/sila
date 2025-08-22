module single_pulse_gen #(
    parameter DELAY_W = 64,
    parameter WIDTH_W = 64
) (
    input  logic                app_clk,
    input  logic                app_rst,

    input  logic                set,
    input  logic                clear,
    input  logic                trigger,

    input  logic [DELAY_W-1: 0] delay,
    input  logic [WIDTH_W-1: 0] width,

    output logic                gen_out
); 
    typedef logic [DELAY_W-1: 0] delay_t;
    typedef logic [WIDTH_W-1: 0] width_t;

// Request Prioritizer
    logic clear_req;
    logic set_req;
    logic trigger_req;
    assign clear_req   = clear;
    assign set_req     = set && !clear;
    assign trigger_req = trigger && !set && !clear;
// Delay Counter
    logic   delay_cnt_eq;
    delay_t delay_cnt = '0;
    logic   delay_start;
    assign  delay_start   = trigger_req;
    assign  delay_cnt_eq  = delay_cnt == 'h1;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            delay_cnt <= '0;
        end else begin
            if(delay_start) begin
                delay_cnt <= delay + 1;
            end else if(delay_cnt > 0) begin
                delay_cnt <= delay_cnt - 1;
            end else if(delay_cnt == 0) begin
                delay_cnt <= delay_cnt;
            end
        end
    end
// Width Counter
    logic   width_cnt_eq;
    width_t width_cnt = '0;
    logic   width_start;
    assign  width_start   = delay_cnt_eq;
    assign  width_cnt_eq  = width_cnt == 'h1;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            width_cnt <= '0;
        end else begin
            if(width_start) begin
                width_cnt <= width + 1;
            end else if(width_cnt > 0) begin
                width_cnt <= width_cnt - 1;
            end else if(width_cnt == 0)  begin
                width_cnt <= width_cnt;
            end
        end
    end
// Set/Clear Prioritizer
    logic set_trigger_req;
    logic clear_trigger_req;
    assign clear_trigger_req = width_cnt_eq && !clear && !set;
    assign set_trigger_req   = delay_cnt_eq && !clear && !set;
// RS Output
    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            gen_out <= 0;
        end else begin
            if(set_req   || set_trigger_req) begin
                gen_out <= 1;
            end
            if(clear_req || clear_trigger_req) begin
                gen_out <= 0;
            end
        end
    end
endmodule

module single_pulse_genTB();
localparam TEST_CYCLE_N = 10;
    logic app_clk;
    logic app_rst = 0;
    logic [63:0] delay = 0;
    logic [63:0] width = 0;
    logic set     = 0;
    logic clear   = 0;
    logic trigger;
    logic gen_out;
    
    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    single_pulse_gen #(
        .DELAY_W(64),
        .WIDTH_W(64)
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .delay(delay),
        .width(width),
        .gen_out(gen_out)
    );

    trigger_generator #(
        .CYCLE_N(TEST_CYCLE_N)
    ) trigger_generator_i (
        .app_clk(app_clk),
        .trigger(trigger)
    );

    initial begin
        reset();

        GenericTest();
        #1us;
        PeriodicTest();
        #1us;
        $stop();
    end

    task GenericTest();
        test_start($sformatf("%m"));
        general_subtest(0, 0);
        general_subtest(9, 9);
    endtask

    task general_subtest(input logic [63:0] test_delay, input logic [63:0] test_width);
        $display("generic subtest: delay %d, width %d", test_delay, test_width);
        delay <= test_delay;
        width <= test_width;
        ->trigger_generator_i.once;
        @(posedge trigger);
        @(posedge app_clk);
        @(posedge app_clk);
        for(int i = 0; i <= test_delay; i++) begin
            assert (gen_out == 0);
            @(posedge app_clk);
        end
        for(int i = 0; i <= test_width; i++) begin
            assert (gen_out == 1);
            @(posedge app_clk);
        end
        @(posedge app_clk);
        assert (gen_out == 0);
    endtask

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
        delay <= test_delay;
        width <= test_width;
        trigger_generator_i.set_period(test_period);
        ->trigger_generator_i.start;
        @(posedge trigger);
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
        delay <= test_delay;
        width <= test_width;
        trigger_generator_i.set_period(test_period);
        ->trigger_generator_i.start;
        for(int i = 0; i < TEST_CYCLE_N; i ++) begin
            @(posedge trigger);
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
        @(posedge app_clk);
        assert(gen_out == 0);
    endtask

    task periodic_dvwn_subtest(input logic [63:0] test_period, input logic [63:0] test_delay, input logic [63:0] test_width);
        $display("periodic width invalid subtest: period %d, delay %d, width %d", test_period, test_delay, test_width);
        delay <= test_delay;
        width <= test_width;
        trigger_generator_i.set_period(test_period);
        ->trigger_generator_i.start;
        @(posedge trigger);
        @(posedge app_clk);
        for(int j = 0; j <= test_delay; j ++) begin
            @(posedge app_clk);
            assert(gen_out == 0) else $display("expect 0 but got 1");
        end
        for(int j = 0; j <= test_width; j ++) begin
            @(posedge app_clk);
            assert(gen_out == 1) else $display("expect 1 but got 0");
        end
        @(posedge app_clk);
        if(test_width == test_period + 1)
            assert(gen_out == 0);
        else 
            assert(gen_out == 1);
        wait(trigger_generator_i.busy == 0);
        if(test_width == test_period + 1)
            assert(gen_out == 0);
        else 
            assert(gen_out == 1);
    endtask

    task periodic_dnwn_subtest(input logic [63:0] test_period, input logic [63:0] test_delay, input logic [63:0] test_width);
        if(test_delay > test_period + 1)
            periodic_dnwv_subtest(test_period, test_delay, test_width);
        else begin
            $display("periodic all invalid subtest: period %d, delay %d, width %d", test_period, test_delay, test_width);
            delay <= test_delay;
            width <= test_width;
            trigger_generator_i.set_period(test_period);
            ->trigger_generator_i.start;
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

module trigger_generator #(
    parameter CYCLE_N = 10
)(
    input  logic app_clk,
    output logic trigger
);
    event start;
    event once;
    logic busy;
    logic [63:0] period;

    initial trigger = 0;

    always @(start) begin
        busy <= 1;
        for(int i = 0; i < CYCLE_N; i++) begin
            trigger <= 1;
            @(posedge app_clk);
            trigger <= 0;
            for(int j = 0; j <= period; j ++) begin
                @(posedge app_clk);
            end
        end
        busy <= 0;
    end    
    always @(once) begin
        busy <= 1;
        @(posedge app_clk);
        trigger <= 1;
        @(posedge app_clk);
        trigger <= 0;
        busy <= 0;
    end

    task set_period(input logic [63:0] new_period);
        period <= new_period;
        @(posedge app_clk);
    endtask
endmodule