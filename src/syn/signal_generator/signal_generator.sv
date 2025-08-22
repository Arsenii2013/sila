`timescale 1ns/1ns
module signal_generator #(
    parameter N        = 16,
    parameter PERIOD_W = 64,
    parameter DELAY_W  = 64,
    parameter WIDTH_W  = 64
) (
    input  logic                 app_clk,
    input  logic                 app_rst,
    axi4_lite_if.s               mmr,

    input  logic                 set[N],
    input  logic                 clear[N],
    input  logic                 trigger[N],
    input  logic                 cnt_reset[N],
    output logic                 gen_out[N]
);
    typedef logic [PERIOD_W-1: 0] period_t;
    typedef logic [DELAY_W -1: 0] delay_t;
    typedef logic [WIDTH_W -1: 0] width_t;

    import signal_gen_ctrl_pkg::*;

    period_t        period[N];
    delay_t         delay[N];
    width_t         width[N];
    logic           polarity[N];
    trig_source_t   trig_source[N];
    output_source_t output_source[N];

    logic           set_ena[N];
    logic           clear_ena[N];
    logic           trigger_ena[N];
    logic           cnt_reset_ena[N];

    genvar i;
    generate
    for(i = 0; i < N; i++) begin
    signal_gen_channel #(
        .PERIOD_W(PERIOD_W),
        .DELAY_W(DELAY_W),
        .WIDTH_W(WIDTH_W)
    ) signal_gen_channel_i (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .set(set[i] && set_ena[i]),
        .clear(clear[i] && clear_ena[i]),
        .trigger(trigger[i] && trigger_ena[i]),
        .cnt_reset(cnt_reset[i] && cnt_reset_ena[i]),
        .delay(delay[i]),
        .width(width[i]),
        .period(period[i]),
        .polarity(polarity[i]),
        .gen_out(gen_out[i]),
        .trig_src(trig_source[i]),
        .out_src(output_source[i])
    );
    end
    endgenerate

    signal_gen_ctrl_axi_core_pkg::signal_gen_ctrl_axi_core__in_t  hwif_in;
    signal_gen_ctrl_axi_core_pkg::signal_gen_ctrl_axi_core__out_t hwif_out;

    assign hwif_in.cr.reserved.next      = (hwif_out.cr.reserved.value | hwif_out.cr_s.reserved.value) & ~hwif_out.cr_c.reserved.value;
    assign hwif_in.cr_s.reserved.next    = '0;
    assign hwif_in.cr_c.reserved.next    = '0;

    genvar j;
    generate
    for(j = 0; j < N; j++) begin
        assign hwif_in.sr.gen_output.next[j]           = gen_out[j];
        assign hwif_in.gen_regs[j].gen_sr.output_.next = gen_out[j];

        assign set_ena[j]       = (hwif_out.gen_regs[j].gen_cr.set_ena.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.set_ena.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.set_ena.value;
        assign clear_ena[j]     = (hwif_out.gen_regs[j].gen_cr.clear_ena.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.clear_ena.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.clear_ena.value;
        assign trigger_ena[j]   = (hwif_out.gen_regs[j].gen_cr.trigger_ena.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.trigger_ena.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.trigger_ena.value;
        assign cnt_reset_ena[j] = (hwif_out.gen_regs[j].gen_cr.cnt_reset_ena.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.cnt_reset_ena.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.cnt_reset_ena.value;
        assign polarity[j]      = (hwif_out.gen_regs[j].gen_cr.polarity.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.polarity.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.polarity.value;
        assign trig_source[j]   = trig_source_t'((hwif_out.gen_regs[j].gen_cr.trig_src.value | 
                                                  hwif_out.gen_regs[j].gen_cr_s.trig_src.value) & 
                                                 ~hwif_out.gen_regs[j].gen_cr_c.trig_src.value);
        assign output_source[j] = output_source_t'((hwif_out.gen_regs[j].gen_cr.out_src.value | 
                                                    hwif_out.gen_regs[j].gen_cr_s.out_src.value) & 
                                                   ~hwif_out.gen_regs[j].gen_cr_c.out_src.value);

        assign hwif_in.gen_regs[j].gen_cr.set_ena.next       = set_ena[j]; 
        assign hwif_in.gen_regs[j].gen_cr.clear_ena.next     = clear_ena[j];
        assign hwif_in.gen_regs[j].gen_cr.trigger_ena.next   = trigger_ena[j];
        assign hwif_in.gen_regs[j].gen_cr.cnt_reset_ena.next = cnt_reset_ena[j];
        assign hwif_in.gen_regs[j].gen_cr.polarity.next      = polarity[j];
        assign hwif_in.gen_regs[j].gen_cr.trig_src.next      = trig_source[j];
        assign hwif_in.gen_regs[j].gen_cr.out_src.next       = output_source[j];

        assign hwif_in.gen_regs[j].gen_cr_s.set_ena.next       = 0; 
        assign hwif_in.gen_regs[j].gen_cr_s.clear_ena.next     = 0;
        assign hwif_in.gen_regs[j].gen_cr_s.trigger_ena.next   = 0;
        assign hwif_in.gen_regs[j].gen_cr_s.cnt_reset_ena.next = 0;
        assign hwif_in.gen_regs[j].gen_cr_s.polarity.next      = 0;
        assign hwif_in.gen_regs[j].gen_cr_s.trig_src.next      = '0;
        assign hwif_in.gen_regs[j].gen_cr_s.out_src.next       = '0;

        assign hwif_in.gen_regs[j].gen_cr_c.set_ena.next       = 0; 
        assign hwif_in.gen_regs[j].gen_cr_c.clear_ena.next     = 0;
        assign hwif_in.gen_regs[j].gen_cr_c.trigger_ena.next   = 0;
        assign hwif_in.gen_regs[j].gen_cr_c.cnt_reset_ena.next = 0;
        assign hwif_in.gen_regs[j].gen_cr_c.polarity.next      = 0;
        assign hwif_in.gen_regs[j].gen_cr_c.trig_src.next      = '0;
        assign hwif_in.gen_regs[j].gen_cr_c.out_src.next       = '0;

        assign delay[j]  = {hwif_out.gen_regs[j].delay_msb.delay_msb.value,   hwif_out.gen_regs[j].delay_lsb.delay_lsb.value};
        assign width[j]  = {hwif_out.gen_regs[j].width_msb.width_msb.value,   hwif_out.gen_regs[j].width_lsb.width_lsb.value};
        assign period[j] = {hwif_out.gen_regs[j].period_msb.period_msb.value, hwif_out.gen_regs[j].period_lsb.period_lsb.value};
    end
    endgenerate
    
    signal_gen_ctrl_axi_core signal_gen_ctrl_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

endmodule

module signal_generatorTB();
    localparam N = 8;
    import signal_gen_ctrl_pkg::*;

    logic app_clk;
    logic app_rst = 0;
    logic set[N]       = '{default:0};
    logic clear[N]     = '{default:0};
    logic trigger[N]   = '{default:0};
    logic cnt_reset[N] = '{default:0};
    logic gen_out[N];
    
    sys_clk_gen
    #(
        .halfcycle (2000),
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    axi4_lite_if #(.AW(32), .DW(32)) mmr();

    axi_master axi_master(
        .aclk(app_clk),
        .aresetn(!app_rst),
        .axi(mmr)
    );

    signal_generator #(
        .N(N),
        .PERIOD_W(64),
        .DELAY_W(64),
        .WIDTH_W(64)
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .gen_out(gen_out)
    );

    initial begin
        reset();

        CRSetClearTest();
        #1us;
        OutputForceTest();
        #1us;
        SetClearTest();
        #1us;
        PolarityTest();
        #1us;
        //GeneratorTest();
        #1us;
        PeriodicTest();
        #1us;
        $stop();
    end

    task CRSetClearTest();
        test_start($sformatf("%m"));
        axi_master.write('h14, 'h00);

        axi_master.write('h18, {PERIOD, GENERATOR, 5'h1f}); // cr_s
        axi_master.check('h14, {PERIOD, GENERATOR, 5'h1f}); // cr
        axi_master.write('h1c, {PERIOD, GENERATOR, 5'h1f}); // cr_s
        axi_master.check('h14, 'h00); // cr
    endtask

    task OutputForceTest();
        test_start($sformatf("%m"));
        axi_master.write('h14, 'h00); // force 0

        axi_master.check('h0,  0); // sr.out = 0
        axi_master.check('h10, 0); // gen_sr.out = 0
        assert(gen_out[0] == 0);

        axi_master.write('h18, 'h20); // force 1
        axi_master.check('h0,  1); // sr.out = 1
        axi_master.check('h10, 1); // gen_sr.out = 1
        assert(gen_out[0] == 1);

        axi_master.write('h18, 'h40); // generator
        axi_master.check('h0,  0); // sr.out = 0
        axi_master.check('h10, 0); // gen_sr.out = 0
        assert(gen_out[0] == 0);
        
    endtask

    task SetClearTest();
        test_start($sformatf("%m"));
        axi_master.write('h14, 'h00);
        axi_master.write('h18, 'h40); // generator

        axi_master.check('h0,  0); // sr.out = 0
        axi_master.check('h10, 0); // gen_sr.out = 0
        assert(gen_out[0] == 0);
        axi_master.write('h18, 'h3); // set_ena, clear_ena
        set[0] <= 1;
        @(posedge app_clk);
        set[0] <= 0;
        @(posedge app_clk);
        assert(gen_out[0] == 1);
        axi_master.check('h10, 1); // sr.out = 1
        axi_master.check('h0,  1); // gen_sr.out = 1
        clear[0] <= 1;
        @(posedge app_clk);
        clear[0] <= 0;
        @(posedge app_clk);
        assert(gen_out[0] == 0);
        axi_master.check('h0,  0); // sr.out = 0
        axi_master.check('h10, 0); // gen_sr.out = 0
    endtask

    task PolarityTest();
        test_start($sformatf("%m"));
        axi_master.write('h14, 'h00);
        axi_master.write('h18, 'h40); // generator

        axi_master.write('h18, 'h10); // polarity
        axi_master.check('h0,  1); // sr.out = 1
        axi_master.check('h10, 1); // gen_sr.out = 1
        assert(gen_out[0] == 1);
        axi_master.write('h18, 3); // set_ena, clear_ena
        set[0] <= 1;
        @(posedge app_clk);
        set[0] <= 0;
        @(posedge app_clk);
        assert(gen_out[0] == 0);
        axi_master.check('h10, 0); // sr.out = 0
        axi_master.check('h0,  0); // gen_sr.out = 0
        clear[0] <= 1;
        @(posedge app_clk);
        clear[0] <= 0;
        @(posedge app_clk);
        assert(gen_out[0] == 1);
        axi_master.check('h0,  1); // sr.out = 1
        axi_master.check('h10, 1); // gen_sr.out = 1
    endtask

    task GeneratorTest();
        test_start($sformatf("%m"));
        for(int delay = 0; delay < 10; delay++) begin
            for(int width = 0; width < 10; width++) begin
                generator_generic_subtest(0, delay, width);
                #100ns;
            end
        end
        for(int i = 0; i < 100; i++) begin
            generator_generic_subtest(0, unsigned'($random()) % 100000, unsigned'($random()) % 100000);
            #100ns;
        end
    endtask

    task generator_generic_subtest(input int unsigned gen_number, input longint unsigned delay, input longint unsigned width);
        static int unsigned base = 'h10 + gen_number * 'h28;
        $display("generator generic subtest: \t\t\t delay %d, width %d", delay, width);
        axi_master.write(base + 'hc, 'hff); // cr_c
        axi_master.write(base + 'h8, {EVENT, GENERATOR, 5'b00100}); // trig = ev, out = generator, trigger enable
        axi_master.write(base + 'h10, delay[31:0]);
        axi_master.write(base + 'h14, delay[63:32]);
        axi_master.write(base + 'h18, width[31:0]);
        axi_master.write(base + 'h1c, width[63:32]);
        trigger[gen_number] <= 1;
        @(posedge app_clk);
        trigger[gen_number] <= 0;
        @(posedge app_clk);
        @(posedge app_clk);
        for(longint i = 0; i <= delay; i++) begin
            assert (gen_out[gen_number] == 0);
            @(posedge app_clk);
        end
        for(longint i = 0; i <= width; i++) begin
            assert (gen_out[gen_number] == 1);
            @(posedge app_clk);
        end
        @(posedge app_clk);
        assert (gen_out[gen_number] == 0);
    endtask

    task PeriodicTest();
        test_start($sformatf("%m"));
        for(int period = 0; period < 10; period++) begin
            for(int delay = 0; delay < 10; delay++) begin
                for(int width = 0; width < 10; width++) begin
                    if(delay <= period + 1 && width <= period)
                        periodic_valid_subtest(0, period, delay, width);
                    else if(delay > period + 1 && width <= period)
                        periodic_dnwv_subtest(0, period, delay, width);
                    else if(delay <= period + 1 && width > period)
                        periodic_dvwn_subtest(0, period, delay, width);
                    else
                        periodic_dnwn_subtest(0, period, delay, width);
                    #100ns;
                end
            end
        end
    endtask

    localparam TEST_CYCLE_N = 10;
    task periodic_valid_subtest(input     int unsigned gen_number, input longint unsigned period, 
                                input longint unsigned delay,      input longint unsigned width);
        static int unsigned base = 'h10 + gen_number * 'h28;
        $display("periodic all valid subtest: \t\t\t period %d, delay %d, width %d", period, delay, width);

        axi_master.write(base + 'hc, 'hff); // cr_c
        axi_master.write(base + 'h8, {PERIOD, GENERATOR, 5'b01000}); // trig = period, out = generator, cnt_rst enable
        axi_master.write(base + 'h10, delay[31:0]);
        axi_master.write(base + 'h14, delay[63:32]);
        axi_master.write(base + 'h18, width[31:0]);
        axi_master.write(base + 'h1c, width[63:32]);
        axi_master.write(base + 'h20, period[31:0]);
        axi_master.write(base + 'h24, period[63:32]);
        #100ns;
        @(posedge app_clk);
        cnt_reset[gen_number] <= 1;
        @(posedge app_clk);
        cnt_reset[gen_number] <= 0;
        @(posedge app_clk);
        @(posedge app_clk);

        for(int j = 0; j <= delay+period; j ++) begin
            @(posedge app_clk);
        end
        for(int i = 0; i < TEST_CYCLE_N; i ++) begin
            for(int j = 0; j <= width; j ++) begin
                @(posedge app_clk);
                assert(gen_out[gen_number] == 1) else $display("expect 1 but got 0 at %d", i);
            end
            for(int j = 0; j <= period-width; j ++) begin
                @(posedge app_clk);
                assert(gen_out[gen_number] == 0) else $display("expect 0 but got 1 at %d", i);
            end

        end
    endtask

    task periodic_dnwv_subtest(input     int unsigned gen_number, input longint unsigned period, 
                               input longint unsigned delay,      input longint unsigned width);
        static int unsigned base = 'h10 + gen_number * 'h28;
        $display("periodic delay invalid subtest: period %d, delay %d, width %d", period, delay, width);
        
        axi_master.write(base + 'hc, 'hff); // cr_c
        axi_master.write(base + 'h8, {PERIOD, GENERATOR, 5'b01000}); // trig = period, out = generator, cnt_rst enable
        axi_master.write(base + 'h10, delay[31:0]);
        axi_master.write(base + 'h14, delay[63:32]);
        axi_master.write(base + 'h18, width[31:0]);
        axi_master.write(base + 'h1c, width[63:32]);
        axi_master.write(base + 'h20, period[31:0]);
        axi_master.write(base + 'h24, period[63:32]);
        #100ns;
        @(posedge app_clk);
        cnt_reset[gen_number] <= 1;
        @(posedge app_clk);
        cnt_reset[gen_number] <= 0;
        @(posedge app_clk);
        @(posedge app_clk);

        @(posedge app_clk);
        for(int j = 0; j <= delay + period; j ++) begin
            @(posedge app_clk);
            assert(gen_out[gen_number] == 0) else $display("expect 0 but got 1");
        end
        for(int j = 0; j <= width; j ++) begin
            @(posedge app_clk);
            assert(gen_out[gen_number] == 1) else $display("expect 1 but got 0");
        end
        @(posedge app_clk);
        assert(gen_out[gen_number] == 0);

        for(int i = 0; i < TEST_CYCLE_N * (period + 2); i ++) begin
            @(posedge app_clk);
            assert(gen_out[gen_number] == 0);
        end
    endtask

    task periodic_dvwn_subtest(input     int unsigned gen_number, input longint unsigned period, 
                               input longint unsigned delay,      input longint unsigned width);
        static int unsigned base = 'h10 + gen_number * 'h28;
        $display("periodic width invalid subtest: period %d, delay %d, width %d", period, delay, width);

        axi_master.write(base + 'hc, 'hff); // cr_c
        axi_master.write(base + 'h8, {PERIOD, GENERATOR, 5'b01000}); // trig = period, out = generator, cnt_rst enable
        axi_master.write(base + 'h10, delay[31:0]);
        axi_master.write(base + 'h14, delay[63:32]);
        axi_master.write(base + 'h18, width[31:0]);
        axi_master.write(base + 'h1c, width[63:32]);
        axi_master.write(base + 'h20, period[31:0]);
        axi_master.write(base + 'h24, period[63:32]);
        #100ns;
        @(posedge app_clk);
        cnt_reset[gen_number] <= 1;
        @(posedge app_clk);
        cnt_reset[gen_number] <= 0;
        @(posedge app_clk);
        @(posedge app_clk);

        for(int i = 0; i < TEST_CYCLE_N * (period + 2); i ++) begin
        if(width == period + 1)
            assert(gen_out[gen_number] == 0);
        else 
            assert(gen_out[gen_number] == 1);
        end
    endtask

    task periodic_dnwn_subtest(input     int unsigned gen_number, input longint unsigned period, 
                               input longint unsigned delay,      input longint unsigned width);
        $display("periodic all invalid subtest is periodic delay invalid subtest !!!");
        periodic_dnwv_subtest(gen_number, period, delay, width);
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