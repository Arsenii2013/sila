
module ev_mapTB();
    localparam COMP_N    = 64;
    localparam SIG_GEN_N = 16;

    logic app_clk;
    logic app_rst = 0;
    ev_map_pkg::ev_t ev = '0;

    logic set      [SIG_GEN_N];
    logic clear    [SIG_GEN_N];
    logic trigger  [SIG_GEN_N];
    logic cnt_reset[SIG_GEN_N];

    axi4_lite_if #(.AW(32), .DW(32)) mmr();

    sys_clk_gen
    #(
        .halfcycle (2000),
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    ev_map #(
        .COMP_N(COMP_N),
        .SIG_GEN_N(SIG_GEN_N)
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .ev(ev)
    );

    virtual_clock_if clk_if (app_clk, app_rst);
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    axi_driver driver;
    ev_map_generator generator;

    initial begin
        driver = new(clk_if, mmr, req_mbx, resp_mbx);
        generator = new(clk_if, req_mbx, resp_mbx, 0);
        reset();
        #1us;
        GenericTest();
        #1us;
        SingleOutputTest();
        #1us;
        ManyOutputTest();
        #1us;
        $stop();
    end

    task GenericTest();
        test_start($sformatf("%m"));
        reset();
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(1);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(2);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(3);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
    endtask

    task SingleOutputTest();
        test_start($sformatf("%m"));
        reset();
        generator.clear_mapping();
        generator.write_mapping('{
            '{ev: 1, map: '{'{set:1, default:0}}},
            '{ev: 2, map: '{'{clear:1, default:0}}},
            '{ev: 3, map: '{'{trigger:1, default:0}}},
            '{ev: 4, map: '{'{cnt_reset:1, default:0}}},
            '{ev: 5, map: '{'{default:1}}}
        });
        generator.verify_mapping('{
            '{ev: 1, map: '{'{set:1, default:0}}},
            '{ev: 2, map: '{'{clear:1, default:0}}},
            '{ev: 3, map: '{'{trigger:1, default:0}}},
            '{ev: 4, map: '{'{cnt_reset:1, default:0}}},
            '{ev: 5, map: '{'{default:1}}}
        });
        driver.sync();
        send_ev(1);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{0: 1, default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(2);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{default:0});
        assert (clear     == '{0: 1, default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(3);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{0: 1, default:0});
        assert (cnt_reset == '{default:0});
        send_ev(4);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{0: 1, default:0});
        send_ev(5);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{0: 1, default:0});
        assert (clear     == '{0: 1, default:0});
        assert (trigger   == '{0: 1, default:0});
        assert (cnt_reset == '{0: 1, default:0});
    endtask

    task ManyOutputTest();
        test_start($sformatf("%m"));
        reset();
        generator.clear_mapping();
        generator.write_mapping('{
            '{ev: 1, map: '{'{set:1, default:0}, '{clear:1, default:0}, '{clear:1, trigger:1, default:0}}},
            '{ev: 2, map: '{'{clear:1, default:0}, '{cnt_reset:1, default:0}, '{cnt_reset:1, default:0}}},
            '{ev: 3, map: '{'{trigger:1, default:0}, '{clear:1, default:0}, '{clear:1, default:0}}},
            '{ev: 4, map: '{'{cnt_reset:1, default:0}, '{set:1, default:0}, '{trigger:0, default:1}}},
            '{ev: 5, map: '{'{default:1}}}
        });
        generator.verify_mapping('{
            '{ev: 1, map: '{'{set:1, default:0}, '{clear:1, default:0}, '{clear:1, trigger:1, default:0}}},
            '{ev: 2, map: '{'{clear:1, default:0}, '{trigger:1, default:0}, '{cnt_reset:1, default:0}}},
            '{ev: 3, map: '{'{trigger:1, default:0}, '{clear:1, default:0}, '{clear:1, default:0}}},
            '{ev: 4, map: '{'{cnt_reset:1, default:0}, '{set:1, default:0}, '{trigger:0, default:1}}},
            '{ev: 5, map: '{'{default:1}}}
        });
        driver.sync();

        send_ev(1);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{0: 1, default:0});
        assert (clear     == '{1: 1, 2: 1, default:0});
        assert (trigger   == '{2: 1, default:0});
        assert (cnt_reset == '{default:0});
        send_ev(2);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{default:0});
        assert (clear     == '{0: 1, default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{1: 1, 2: 1,default:0});
        send_ev(3);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{default:0});
        assert (clear     == '{1: 1, 2: 1,default:0});
        assert (trigger   == '{0: 1, default:0});
        assert (cnt_reset == '{default:0});
        send_ev(4);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{1: 1, 2: 1, default:0});
        assert (clear     == '{2: 1, default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{0: 1, 2: 1, default:0});
        send_ev(5);
        @(posedge app_clk);
        @(posedge app_clk);
        assert (set       == '{default:1});
        assert (clear     == '{default:1});
        assert (trigger   == '{default:1});
        assert (cnt_reset == '{default:1});
    endtask

    task send_ev(logic [23:0] ev_s);
        @(posedge app_clk);
        ev <= ev_s;
        @(posedge app_clk);
        ev <= 0;
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