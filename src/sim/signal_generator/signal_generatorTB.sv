
module signal_generatorTB();
    localparam N = 8;
    import signal_generator_pkg::*;

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


    signal_generator #(
        .N(N)
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

    virtual_clock_if clk_if (app_clk, app_rst);
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    axi_driver driver;
    signal_generator_generator generator;

    initial begin
        driver = new(clk_if, mmr, req_mbx, resp_mbx);
        generator = new(clk_if, req_mbx, resp_mbx, 0);
        reset();

        GenericTest();
        #1us;
        ForceOutputTest();
        #1us;
        SetClearTest();
        #1us;
        PolarityTest();
        #1us;
        GeneratorTest();
        #1us;
        PeriodicTest();
        #1us;
        $stop();
    end

    import signal_generator_generator_pkg::*;
    task GenericTest();
        test_start($sformatf("%m"));
        generator.set_cfg(0, '{'{0, 0, 0, 0}, 0, FORCE_CLEAR, EVENT});
        generator.set_cfg(1, '{'{1, 1, 1, 1}, 1, GENERATOR, PERIOD});
        generator.check_cfg(0, '{'{0, 0, 0, 0}, 0, FORCE_CLEAR, EVENT});
        generator.check_cfg(1, '{'{1, 1, 1, 1}, 1, GENERATOR, PERIOD});
        generator.set_ena(2, '{1, 0, 1, 0});
        generator.set_polarity(2, 0);
        generator.set_out_src(2, FORCE_SET);
        generator.set_trig_src(2, PERIOD);
        generator.check_cfg(0, '{'{0, 0, 0, 0}, 0, FORCE_CLEAR, EVENT});
        generator.check_cfg(1, '{'{1, 1, 1, 1}, 1, GENERATOR, PERIOD});
        generator.check_cfg(2, '{'{1, 0, 1, 0}, 0, FORCE_SET, PERIOD});
        generator.set_ena(1, '{0, 1, 0, 1});
        generator.set_polarity(1, 0);
        generator.set_out_src(1, FORCE_SET);
        generator.set_trig_src(1, EVENT);
        generator.check_cfg(0, '{'{0, 0, 0, 0}, 0, FORCE_CLEAR, EVENT});
        generator.check_cfg(1, '{'{0, 1, 0, 1}, 0, FORCE_SET, EVENT});
        generator.check_cfg(2, '{'{1, 0, 1, 0}, 0, FORCE_SET, PERIOD});
        driver.sync();
    endtask

    task ForceOutputTest();
        logic [N-1:0] rd_outs;
        test_start($sformatf("%m"));
        generator.set_cfg(0, '{'{0, 0, 0, 0}, 0, FORCE_CLEAR, EVENT});
        driver.sync();
        generator.get_outputs_all(rd_outs);
        assert(rd_outs[0] == 0);
        generator.check_output(0, 0);
        driver.sync();
        assert(gen_out[0] == 0);
        generator.set_out_src(0, FORCE_SET);
        generator.get_outputs_all(rd_outs);
        assert(rd_outs[0] == 1);
        generator.check_output(0, 1);
        driver.sync();
        assert(gen_out[0] == 1);
        generator.set_out_src(0, FORCE_CLEAR);
        generator.set_polarity(0, 1);
        driver.sync();
        assert(gen_out[0] == 0);
        generator.set_out_src(0, FORCE_SET);
        driver.sync();
        assert(gen_out[0] == 1);
    endtask

    task SetClearTest();
        test_start($sformatf("%m"));
        generator.set_cfg(0, '{'{1, 1, 0, 0}, 0, GENERATOR, EVENT});
        driver.sync();
        #100ns;
        assert(gen_out[0] == 0);
        @(posedge app_clk);
        set[0] <= 1;
        @(posedge app_clk);
        set[0] <= 0;
        @(posedge app_clk);
        assert(gen_out[0] == 1);
        @(posedge app_clk);
        clear[0] <= 1;
        @(posedge app_clk);
        clear[0] <= 0;
        @(posedge app_clk);
        assert(gen_out[0] == 0);
    endtask

    task PolarityTest();
        test_start($sformatf("%m"));
        generator.set_cfg(0, '{'{1, 1, 0, 0}, 1, GENERATOR, EVENT});
        driver.sync();
        #100ns;
        assert(gen_out[0] == 1);
        @(posedge app_clk);
        set[0] <= 1;
        @(posedge app_clk);
        set[0] <= 0;
        @(posedge app_clk);
        assert(gen_out[0] == 0);
        @(posedge app_clk);
        clear[0] <= 1;
        @(posedge app_clk);
        clear[0] <= 0;
        @(posedge app_clk);
        assert(gen_out[0] == 1);
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

    task generator_generic_subtest(input int unsigned gen_number, input delay_t delay, input width_t width);
        $display("generator generic subtest: \t\t\t delay %d, width %d", delay, width);
        generator.set_cfg(gen_number, '{'{0, 0, 1, 0}, 0, GENERATOR, EVENT});
        generator.set_delay(gen_number, delay);
        generator.set_width(gen_number, width);
        driver.sync();
        #100ns;
        @(posedge app_clk);
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
        generator.set_cfg(gen_number, '{'{0, 0, 0, 1}, 0, GENERATOR, PERIOD});
        generator.set_delay(gen_number, delay);
        generator.set_width(gen_number, width);
        generator.set_period(gen_number, period);
        driver.sync();
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
        generator.set_cfg(gen_number, '{'{0, 0, 0, 1}, 0, GENERATOR, PERIOD});
        generator.set_delay(gen_number, delay);
        generator.set_width(gen_number, width);
        generator.set_period(gen_number, period);
        driver.sync();
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
        generator.set_cfg(gen_number, '{'{0, 0, 0, 1}, 0, GENERATOR, PERIOD});
        generator.set_delay(gen_number, delay);
        generator.set_width(gen_number, width);
        generator.set_period(gen_number, period);
        driver.sync();
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
        @(posedge app_clk);
        $display("Start %s test with number %d", name, test_number);
    endtask

    task reset();
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst <= 0;
    endtask

endmodule