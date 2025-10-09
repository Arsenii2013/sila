
module gen_mapTB();
    import gen_map_generator_pkg::*;
    localparam SIG_GEN_N = 16;
    localparam DIFF_IO_N = 16;

    logic app_clk;
    logic app_rst = 0;
    
    logic gen_out [SIG_GEN_N];
    logic o1      [DIFF_IO_N];
    logic o2      [DIFF_IO_N];

    axi4_lite_if #(.AW(32), .DW(32)) mmr();

    sys_clk_gen
    #(
        .halfcycle (2000),
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    gen_map #(
        .SIG_GEN_N(SIG_GEN_N),
        .DIFF_IO_N(DIFF_IO_N)
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .o1(o1),
        .o2(o2),
        .gen_out(gen_out)
    );

    virtual_clock_if clk_if (app_clk, app_rst);
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    axi_driver driver;
    gen_map_generator generator;

    initial begin
        driver = new(clk_if, mmr, req_mbx, resp_mbx);
        generator = new(clk_if, req_mbx, resp_mbx, 0);
        reset();
        GenericTest();
        RandomTest();
        #1us;
        $stop();
    end

    task GenericTest();
        test_start($sformatf("%m"));
        reset();
        assert (o1 == '{default:0});
        assert (o2 == '{default:0});
        gen_out <= '{default:1};
        assert (o1 == '{default:0});
        assert (o2 == '{default:0});
        gen_out <= '{default:0};
        assert (o1 == '{default:0});
        assert (o2 == '{default:0});
    endtask

    mapping_item_t mapping[SIG_GEN_N];
    task RandomTest();
        test_start($sformatf("%m"));
        reset();
        @(posedge app_clk);

        for(int i = 0; i < 100; i ++) begin
            randomize_mapping(mapping);
            generator.write_mapping(mapping);
            generator.verify_mapping(mapping);
            driver.sync();
            repeat (10) @(posedge app_clk);
            for(int i = 0; i < 100; i ++) begin
                randomize_gen_out(mapping);
            end
        end
    endtask

    task randomize_mapping(output mapping_item_t mapping[SIG_GEN_N]);
        foreach(mapping[i]) begin
            mapping[i].map = '{DIFF_IO_N{'{o1:0, o2:0}}};
            foreach(mapping[i].map[j]) begin
                mapping[i].map[j].o1 = ($random % SIG_GEN_N == 0);
                mapping[i].map[j].o2 = ($random % SIG_GEN_N == 0);
            end
        end
        @(posedge app_clk);
    endtask

    task randomize_gen_out(mapping_item_t mapping[SIG_GEN_N]);
        logic o1_expected;
        logic o2_expected;

        foreach (gen_out[i]) begin
            gen_out[i] = $random;
        end
        repeat (10) @(posedge app_clk);

        foreach(o1[i]) begin
            o1_expected = 0;
            o2_expected = 0;
            foreach(gen_out[j]) begin
                o1_expected |= mapping[j].map[i].o1 & gen_out[j];
                o2_expected |= mapping[j].map[i].o2 & gen_out[j];
            end
            assert (o1[i] == o1_expected);
            assert (o2[i] == o2_expected);
        end
    endtask

    int test_number = 0;
    task test_start(input string name);
        @(posedge app_clk);
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