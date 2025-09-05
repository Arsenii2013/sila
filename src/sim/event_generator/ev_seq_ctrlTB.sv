
`ifndef SYNTHESIS
module ev_seq_ctrlTB();
    localparam SEQ_NUM = 2;
    logic app_clk;
    logic app_rst = 0;
    event_generator_pkg::ev_t ev_in[SEQ_NUM];
    event_generator_pkg::ev_t ev_out;
    logic enable  [SEQ_NUM];
    logic start   [SEQ_NUM];
    logic stop    [SEQ_NUM];
    logic running [SEQ_NUM];
    
    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    axi4_lite_if #(.AW(32), .DW(32)) mmrSEQ[SEQ_NUM]();
    axi4_lite_if #(.AW(32), .DW(32)) mmrDUT();

    genvar gen_i;
    generate
    for(gen_i = 0; gen_i < SEQ_NUM; gen_i++) begin : seq_inst
    ev_seq sequencer (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmrSEQ[gen_i]),
        .ev(ev_in[gen_i]),
        .disable_(!enable[gen_i]),
        .start(start[gen_i]),
        .stop(stop[gen_i]),
        .running(running[gen_i])
    );
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    axi_driver driver;
    ev_seq_generator generator;
    end
    endgenerate


    ev_seq_ctrl #(
        .EV_SEQ_N(SEQ_NUM)
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmrDUT),

        .seq_enable(enable),
        .seq_start(start),
        .seq_stop(stop),
        .seq_running(running),
        .ev_in(ev_in),
        .ev_out(ev_out)
    );
    axi_transaction_pkg::item_mailbox_t ctrl_req_mbx = new(), ctrl_resp_mbx = new();
    axi_driver ctrl_driver;
    ev_seq_ctrl_generator ctrl_generator;

    ev_monitor #(
        .SEQ_N(SEQ_NUM)
    ) ev_monitor_i(
        .clk(app_clk),
        .reset(app_rst),
        .ev_out(ev_out),
        .ev_in(ev_in),
        .prog_ev(DUT.prog_ev)
    );

    virtual_clock_if clk_if (app_clk, app_rst);
    genvar gen_j;
    for(gen_j = 0; gen_j < SEQ_NUM; gen_j++) begin : seq_init
    initial begin
        seq_inst[gen_j].driver = new(clk_if, mmrSEQ[gen_j], seq_inst[gen_j].req_mbx, seq_inst[gen_j].resp_mbx);
        seq_inst[gen_j].generator = new(clk_if, seq_inst[gen_j].req_mbx, seq_inst[gen_j].resp_mbx, 0);
    end
    end
    initial begin
        ctrl_driver = new(clk_if, mmrDUT, ctrl_req_mbx, ctrl_resp_mbx);
        ctrl_generator = new(clk_if, ctrl_req_mbx, ctrl_resp_mbx, 0);
        reset();
        #1us;
        GenericTest();
        #10us;
        SingleTest();
        #10us;
        OverlapTest();
        #10us;
        ResetTest();
        #10us;
        CycleTest();
        #10us;
        RecycleTest();
        #10us;
        $stop();
    end

    task GenericTest();
        test_start($sformatf("%m"));
        ctrl_generator.check_running_all('0);
        for(int i = 0; i < SEQ_NUM; i ++)
            ctrl_generator.check_running(i, 0);

        ctrl_generator.enable_all();
        ctrl_generator.check_enabled_all('1);
        for(int i = 0; i < SEQ_NUM; i ++)
            ctrl_generator.check_enabled(i, 1);

        ctrl_generator.disable_all();
        ctrl_generator.check_enabled_all('0);
        for(int i = 0; i < SEQ_NUM; i ++)
            ctrl_generator.check_enabled(i, 0);

        for(int i = 0; i < SEQ_NUM; i ++)
            ctrl_generator.enable(i);
        ctrl_generator.check_enabled_all('1);

        for(int i = 0; i < SEQ_NUM; i ++)
            ctrl_generator.disable_(i);
        ctrl_generator.check_enabled_all('0);

        ctrl_generator.enable_all();
        ctrl_generator.reset_all();
        ctrl_generator.check_enabled_all('0);

        ctrl_generator.enable_all();
        for(int i = 0; i < SEQ_NUM; i ++)
            ctrl_generator.reset(i);
        ctrl_generator.check_enabled_all('0);
    endtask

    task SingleTest();
        test_start($sformatf("%m"));
        ctrl_generator.reset_all();
        seq_inst[0].generator.clear_events();
        seq_inst[1].generator.clear_events();
        seq_inst[0].generator.write_seq('{
            '{0,    'h1},
            '{1,    'h2},
            '{2,    'h3},
            '{3,    'h4},
            '{10,   'h10},
            '{20,   'h20},
            '{40,   'h40},
            '{80,   'h80},
            '{8000, 'h1234},
            '{8001, event_generator_pkg::END_OF_SEQ}
        });
        seq_inst[1].generator.write_seq('{
            '{0,    'h11},
            '{1,    'h12},
            '{2,    'h13},
            '{3,    'h14},
            '{10,   'h110},
            '{20,   'h120},
            '{40,   'h140},
            '{80,   'h180},
            '{8000, 'h11234},
            '{8001, event_generator_pkg::END_OF_SEQ}
        });
        seq_inst[0].driver.sync();
        seq_inst[1].driver.sync();
        ctrl_generator.setup('{
            '{event_generator_pkg::PROG, event_generator_pkg::SINGLE},
            '{event_generator_pkg::PROG, event_generator_pkg::SINGLE}
        });
        ctrl_generator.enable_all();
        ctrl_generator.sw_trig(0);
        #1us;
        ctrl_generator.sw_trig(1);
        #100ns;
        ctrl_generator.check_running_all('1);
        ctrl_generator.check_enabled_all('0);
        for(int i = 0; i < SEQ_NUM; i ++) begin
            ctrl_generator.check_running(i, 1);
            ctrl_generator.check_enabled(i, 0);
        end
        wait_seq_end();
        wait_seq_end();
        #100ns;
        ctrl_generator.check_running_all('0);
        for(int i = 0; i < SEQ_NUM; i ++)
            ctrl_generator.check_running(i, 0);
    endtask

    task OverlapTest();
        localparam SEQ_SIZE = 100;
        ev_seq_generator_pkg::seq_item_t seq1 [SEQ_SIZE];
        ev_seq_generator_pkg::seq_item_t seq2 [SEQ_SIZE];
        foreach(seq1[i]) begin
            seq1[i] = '{i, i+1};
            seq2[i] = '{i, i+1+'h100};
        end
        seq1[SEQ_SIZE-1] = '{seq1[SEQ_SIZE-1].timestamp, event_generator_pkg::END_OF_SEQ};
        seq2[SEQ_SIZE-1] = '{seq2[SEQ_SIZE-1].timestamp, event_generator_pkg::END_OF_SEQ};

        test_start($sformatf("%m"));
        ctrl_generator.reset_all();
        seq_inst[0].generator.clear_events();
        seq_inst[1].generator.clear_events();
        seq_inst[0].generator.write_seq(seq1);
        seq_inst[1].generator.write_seq(seq2);
        ctrl_generator.setup('{
            '{event_generator_pkg::PROG, event_generator_pkg::SINGLE},
            '{event_generator_pkg::PROG, event_generator_pkg::SINGLE}
        });
        seq_inst[0].driver.sync();
        seq_inst[1].driver.sync();
        ctrl_driver.sync();

        ctrl_generator.enable_all();
        ctrl_generator.sw_trig(0);
        ctrl_generator.sw_trig(1);
        ctrl_generator.send_prog_ev('h1234);
        ctrl_generator.send_prog_ev('h1234);
        ctrl_generator.send_prog_ev('h1234);
        ctrl_generator.send_prog_ev('h1234);
        wait_seq_end();
        wait_seq_end();
    endtask

    task ResetTest();
        test_start($sformatf("%m"));
        ctrl_generator.reset_all();
        seq_inst[0].generator.clear_events();
        seq_inst[1].generator.clear_events();
        seq_inst[0].generator.write_seq('{
            '{8001, event_generator_pkg::END_OF_SEQ}
        });
        seq_inst[1].generator.write_seq('{
            '{8001, event_generator_pkg::END_OF_SEQ}
        });
        ctrl_generator.setup('{
            '{event_generator_pkg::PROG, event_generator_pkg::SINGLE},
            '{event_generator_pkg::PROG, event_generator_pkg::SINGLE}
        });
        seq_inst[0].driver.sync();
        seq_inst[1].driver.sync();
        ctrl_driver.sync();

        ctrl_generator.enable_all();
        ctrl_generator.sw_trig(0);
        ctrl_generator.sw_trig(1);
        #100ns;

        ctrl_generator.check_running_all('1);
        ctrl_generator.reset_all();
        #100ns;
        ctrl_generator.check_running_all('0);
        ctrl_generator.check_enabled_all('0);

        ctrl_generator.enable_all();
        ctrl_generator.sw_trig(0);
        ctrl_generator.sw_trig(1);
        #100ns;

        ctrl_generator.reset(1);
        #100ns;
        ctrl_generator.check_running_all('b01);
        ctrl_generator.reset(0);
        #100ns;
        ctrl_generator.check_running_all('0);
        ctrl_generator.check_enabled_all('0);
    endtask

    task CycleTest();
        test_start($sformatf("%m"));
        ctrl_generator.reset_all();
        seq_inst[0].generator.clear_events();
        seq_inst[1].generator.clear_events();
        seq_inst[0].generator.write_seq('{
            '{0,    'h1},
            '{1,    'h2},
            '{2,    'h3},
            '{3,    'h4},
            '{10,   'h10},
            '{20,   'h20},
            '{40,   'h40},
            '{80,   'h80},
            '{8000, 'h1234},
            '{8001, event_generator_pkg::END_OF_SEQ}
        });
        seq_inst[1].generator.write_seq('{
            '{0,    'h11},
            '{1,    'h12},
            '{2,    'h13},
            '{3,    'h14},
            '{10,   'h110},
            '{20,   'h120},
            '{40,   'h140},
            '{80,   'h180},
            '{8000, 'h11234},
            '{8001, event_generator_pkg::END_OF_SEQ}
        });
        ctrl_generator.setup('{
            '{event_generator_pkg::PROG, event_generator_pkg::CYCLE},
            '{event_generator_pkg::PROG, event_generator_pkg::CYCLE}
        });
        seq_inst[0].driver.sync();
        seq_inst[1].driver.sync();
        ctrl_driver.sync();

        ctrl_generator.enable_all();
        ctrl_generator.sw_trig(0);
        ctrl_generator.sw_trig(1);

        #100ns;
        ctrl_generator.check_running_all('1);
        wait_seq_end();
        wait_seq_end();
        #100ns;
        ctrl_generator.check_running_all('0);

        ctrl_generator.sw_trig(0);
        ctrl_generator.sw_trig(1);
        #100ns;
        ctrl_generator.check_running_all('1);
        wait_seq_end();
        wait_seq_end();
        #100ns;
        ctrl_generator.check_running_all('0);

        ctrl_generator.sw_trig(0);
        ctrl_generator.sw_trig(1);
        #100ns;
        ctrl_generator.check_running_all('1);
        ctrl_generator.reset_all();
        #100ns;
        ctrl_generator.check_running_all('0);

        ctrl_generator.enable_all();
        ctrl_generator.sw_trig(0);
        ctrl_generator.sw_trig(1);
        #100ns;
        ctrl_generator.check_running_all('1);
        wait_seq_end();
        wait_seq_end();
        #100ns;
        ctrl_generator.check_running_all('0);
    endtask

    task RecycleTest();
        test_start($sformatf("%m"));
        ctrl_generator.reset_all();
        seq_inst[0].generator.clear_events();
        seq_inst[1].generator.clear_events();
        seq_inst[0].generator.write_seq('{
            '{0,    'h1},
            '{1,    'h2},
            '{2,    'h3},
            '{3,    'h4},
            '{10,   'h10},
            '{20,   'h20},
            '{40,   'h40},
            '{80,   'h80},
            '{8000, 'h1234},
            '{8001, event_generator_pkg::END_OF_SEQ}
        });
        seq_inst[1].generator.write_seq('{
            '{0,    'h11},
            '{1,    'h12},
            '{2,    'h13},
            '{3,    'h14},
            '{10,   'h110},
            '{20,   'h120},
            '{40,   'h140},
            '{80,   'h180},
            '{8000, 'h11234},
            '{8001, event_generator_pkg::END_OF_SEQ}
        });
        ctrl_generator.setup('{
            '{event_generator_pkg::PROG, event_generator_pkg::RECYCLE},
            '{event_generator_pkg::PROG, event_generator_pkg::RECYCLE}
        });
        seq_inst[0].driver.sync();
        seq_inst[1].driver.sync();
        ctrl_driver.sync();

        ctrl_generator.enable_all();
        ctrl_generator.sw_trig(0);
        ctrl_generator.sw_trig(1);

        #100ns;
        ctrl_generator.check_running_all('1);
        wait_seq_end();
        wait_seq_end();
        #100ns;
        ctrl_generator.check_running_all('1);
        wait_seq_end();
        wait_seq_end();
        #100ns;
        ctrl_generator.check_running_all('1);
        ctrl_generator.reset_all();
        #100ns;
        ctrl_generator.check_running_all('0);

        ctrl_generator.enable_all();
        ctrl_generator.sw_trig(0);
        ctrl_generator.sw_trig(1);
        #200ns;
        ctrl_generator.check_running_all('1);
        wait_seq_end();
        wait_seq_end();
        #100ns;
        ctrl_generator.check_running_all('1);
    endtask

    task reset();
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst <= 0;
    endtask

    int test_number = 0;
    task test_start(input string name);
        @(posedge app_clk);
        test_number <= test_number + 1;
        @(posedge app_clk);
        $display("Start %s test with numder %d", name, test_number);
    endtask

    task wait_seq_end();
        @(posedge (ev_out == event_generator_pkg::END_OF_SEQ));
    endtask
endmodule

module ev_monitor#(
    parameter SEQ_N = 2
)(
    input  logic                     clk,
    input  logic                     reset,
    input  event_generator_pkg::ev_t ev_out,
    input  event_generator_pkg::ev_t ev_in[SEQ_N],
    input  event_generator_pkg::ev_t prog_ev
);

    assert property (@(posedge clk) (ev_out != '0) |-> ((ev_out != prog_ev) |-> ((ev_out != ev_in[0]) |-> (ev_out == ev_in[1]))));
    assert property (@(posedge clk) (ev_in[0] != '0) |-> (ev_out != '0));
    assert property (@(posedge clk) (ev_in[1] != '0) |-> (ev_out != '0));
endmodule
`endif //SYNTHESIS 