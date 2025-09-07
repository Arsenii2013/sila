import evn::*;

module treeTB(

    );
    localparam time PROPAGATION_DELAY_DEEP_0_PORT_0 = 1234.56ns;
    localparam time PROPAGATION_DELAY_DEEP_0_PORT_1 = 560.12ns;
    localparam time PROPAGATION_DELAY_DEEP_1_PORT_0 = 346.98ns;
    localparam time ENDPOINT_DELAY_ARR [2]     = '{
                                                 PROPAGATION_DELAY_DEEP_0_PORT_0, 
                                                 PROPAGATION_DELAY_DEEP_0_PORT_1 + PROPAGATION_DELAY_DEEP_1_PORT_0
                                                  };
    function time max_time(time times [2]);
        max_time = 0ps;
        foreach(times[i])
            if(times[i] > max_time)
                max_time = times[i];
    endfunction
    localparam time MAX_SUBTREE_DELAY          = max_time(ENDPOINT_DELAY_ARR);

    localparam FANOUT_CNT = 1;
    localparam EVR_CNT = 2;
    import evn::*;
    import gtx::*;

    logic app_rst;
    semaphore display_key = new(1);

    gtx_if evg_gtx[EVG_PORT_N]();
    logic evg_gtx_refclk;

    gtx_if fanout_gtx[FANOUT_CNT][FANOUT_PORT_N]();
    logic fanout_gtx_refclk[FANOUT_CNT];

    gtx_if evr_gtx[EVR_CNT][EVR_PORT_N]();
    logic evr_gtx_refclk[EVR_CNT];

    evg_board_emulator #(
        .PORTS_USED('{0, 1}),
        .SUBTREE_DELAY(MAX_SUBTREE_DELAY)
    ) head_evg (
        .gtx_if(evg_gtx),
        .gtx_refclk(evg_gtx_refclk),
        .app_rst(app_rst)
    );

    fanout_board_emulator #(
        .PORTS_USED('{0, 1}),
        .TOPO_ID('h1)
    ) fanout_deep_0_port_0(
        .gtx_if(fanout_gtx[0]),
        .gtx_refclk(fanout_gtx_refclk[0]),
        .app_rst(app_rst)
    );

    evr_board_emulator #(
        .TOPO_ID('h2)
    ) evr_deep_0_port_1(
        .gtx_if(evr_gtx[0]),
        .gtx_refclk(evr_gtx_refclk[0]),
        .app_rst(app_rst)
    );

    evr_board_emulator #(
        .TOPO_ID('h12)
    ) evr_deep_1_port_0(
        .gtx_if(evr_gtx[1]),
        .gtx_refclk(evr_gtx_refclk[1]),
        .app_rst(app_rst)
    );

    gtx_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY_DEEP_0_PORT_0)
    ) link_deep_0_port_0 (
        .from(evg_gtx[0]),
        .from_ref_clk(evg_gtx_refclk),
        .to(fanout_gtx[0][0]),
        .to_ref_clk(fanout_gtx_refclk[0])
    );
    gtx_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY_DEEP_0_PORT_1)
    ) link_deep_0_port_1 (
        .from(evg_gtx[1]),
        .from_ref_clk(evg_gtx_refclk),
        .to(evr_gtx[0][0]),
        .to_ref_clk(evr_gtx_refclk[0])
    );
    gtx_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY_DEEP_1_PORT_0)
    ) link_deep_1_port_0 (
        .from(fanout_gtx[0][1]),
        .from_ref_clk(fanout_gtx_refclk[0]),
        .to(evr_gtx[1][0]),
        .to_ref_clk(evr_gtx_refclk[0])
    );
    gtx_stub gtx_stub_deep_0_port_2(
        .gtx_if(evg_gtx[2])
    );
    gtx_stub gtx_stub_deep_0_port_3(
        .gtx_if(evg_gtx[3])
    );
    gtx_stub gtx_stub_deep_1_port_2(
        .gtx_if(fanout_gtx[0][2])
    );
    gtx_stub gtx_stub_deep_1_port_3(
        .gtx_if(fanout_gtx[0][3])
    );

    initial begin
        app_rst <= 1;
        #(MAX_SUBTREE_DELAY);
        repeat (100) @(posedge evg_gtx_refclk);
        app_rst <= 0;
        #10us;
    end

    initial begin
        #500ms;
        $display("Timeout! Cant get FINE state in %t\n", $realtime);
        $stop();
    end
endmodule

module evg_board_emulator#(
    parameter int  PORTS_USED [] = '{},
    parameter time SUBTREE_DELAY = 12345.56ns
)(
    gtx_if.app   gtx_if[gtx::EVG_PORT_N],
    output logic gtx_refclk,
    input  logic app_rst
);
    localparam REFCLK_PHASE  = 1234;
    logic     app_clk;
    ev_t      ev;
    trig_t    trig;
    logic     beacon_clk;
    axi4_lite_if #(.AW(32), .DW(32)) axi();

    sys_clk_gen
    #(
        .halfcycle (2857), // 2857 ps = 175 MHz
        .offset    (REFCLK_PHASE)
    ) CLK_GEN (
        .sys_clk (gtx_refclk)
    );
    sys_clk_gen
    #(
        .halfcycle (2856.5), // 2856.5 ps ~ 175_039_383  Hz
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (beacon_clk)
    );

    evg #(
        .PORT_N(gtx::EVG_PORT_N)
    ) DUT_EVG (
        .beacon_clk(beacon_clk),
        .gtx_if(gtx_if),
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(axi),
        
        .ev(ev),
        .trig(trig)
    );

    ev_generator evg_ev_generator(
        .app_clk(app_clk),
        .app_rst(app_rst),
        .ev(ev)
    );
    
    virtual_clock_if clk_if (app_clk, app_rst);
    axi_driver driver;
    link_csr_generator generator;
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    initial begin
        driver    = new(clk_if, axi, req_mbx, resp_mbx);
        generator = new(clk_if, req_mbx, resp_mbx, 0, $sformatf("Head EVG with topo id \t%x\t", 0));
    end

    initial begin
        @(negedge app_rst);

        fork
        generator.set_tgt_delay((generator.time_to_delay_t(SUBTREE_DELAY) 
                                & ~((1 << evn::DELAY_FRAC_W) - 1)) // зануляем дробную часть
                                + (10 << evn::DELAY_FRAC_W));       // + 10 тактов
        wait_delay_statuses();
        periodic_dump();
        join
    end

    task wait_delay_statuses();
        $timeformat(-3, 5, " ms");
        generator.wait_delay_statuses(PORTS_USED, evn::INITIAL, 10us);
        $root.treeTB.display_key.get();
        $display("Get Head EVG ports INITIAL state at %t\n", $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();

        generator.wait_delay_statuses(PORTS_USED, evn::ONE_CYCLE, 1ms);
        $root.treeTB.display_key.get();
        $display("Get Head EVG ports ONE_CYCLE state at %t\n", $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();

        generator.wait_delay_statuses(PORTS_USED, evn::FINE, 100ms);
        $root.treeTB.display_key.get();
        $display("Get Head EVG ports FINE state at %t\n", $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();
    endtask

    task periodic_dump();
        forever begin
            $root.treeTB.display_key.get();
            $display("Periodic Dump Head EVG");
            generator.dump();
            $root.treeTB.display_key.put();
            #1ms;
        end
    endtask
endmodule

module fanout_board_emulator#(
    parameter int            PORTS_USED [] = '{},
    parameter evn::topo_id_t TOPO_ID       = 1
)(
    gtx_if.app   gtx_if[gtx::FANOUT_PORT_N],
    output logic gtx_refclk,
    input  logic app_rst
);
    localparam REFCLK_PHASE  = 1234;
    logic     app_clk;
    ev_t      ev;
    trig_t    trig;
    logic     beacon_clk;
    axi4_lite_if #(.AW(32), .DW(32)) axi();

    assign gtx_refclk = gtx_if[0].rx_clk;
    sys_clk_gen
    #(
        .halfcycle (2856.5), // 2856.5 ps ~ 175_039_383  Hz
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (beacon_clk)
    );

    fanout #(
        .PORT_N(gtx::FANOUT_PORT_N)
    ) DUT_FANOUT (
        .beacon_clk(beacon_clk),
        .gtx_if(gtx_if),
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(axi),
        
        .ev(ev),
        .trig(trig)
    );
    
    virtual_clock_if clk_if (app_clk, app_rst);
    axi_driver driver;
    link_csr_generator generator;
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    initial begin
        driver    = new(clk_if, axi, req_mbx, resp_mbx);
        generator = new(clk_if, req_mbx, resp_mbx, 0, $sformatf("FANOUT with topo id \t%x\t", TOPO_ID));
    end
    initial begin
        @(negedge app_rst);
        fork
        wait_delay_statuses();
        periodic_dump();
        join
    end

    task wait_delay_statuses();
        $timeformat(-3, 5, " ms");
        generator.wait_delay_statuses(PORTS_USED, evn::INITIAL, 10us);
        $root.treeTB.display_key.get();
        $display("Get FANOUT with topo id %x ports INITIAL state at %t\n", TOPO_ID, $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();

        generator.wait_delay_statuses(PORTS_USED, evn::ONE_CYCLE, 1ms);
        $root.treeTB.display_key.get();
        $display("Get FANOUT with topo id %x ONE_CYCLE state at %t\n", TOPO_ID, $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();

        generator.wait_delay_statuses(PORTS_USED, evn::FINE, 100ms);
        $root.treeTB.display_key.get();
        $display("Get FANOUT with topo id %x FINE state at %t\n", TOPO_ID, $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();
    endtask

    task periodic_dump();
        forever begin
            $root.treeTB.display_key.get();
            $display("Periodic Dump FANOUT with topo id %x \t", TOPO_ID);
            generator.dump();
            $root.treeTB.display_key.put();
            #1ms;
        end
    endtask
endmodule

module evr_board_emulator#(
    parameter evn::topo_id_t TOPO_ID       = 1
)(
    gtx_if.app   gtx_if[gtx::EVR_PORT_N],
    output logic gtx_refclk,
    input  logic app_rst
);
    localparam REFCLK_PHASE  = 1234;
    logic     app_clk;
    ev_t      ev;
    trig_t    trig;
    logic     beacon_clk;
    axi4_lite_if #(.AW(32), .DW(32)) axi();

    sys_clk_gen
    #(
        .halfcycle (2857), // 2857 ps = 175 MHz
        .offset    (REFCLK_PHASE)
    ) CLK_GEN (
        .sys_clk (gtx_refclk)
    );
    sys_clk_gen
    #(
        .halfcycle (2856.5), // 2856.5 ps ~ 175_039_383  Hz
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (beacon_clk)
    );

    evr #(
        .PORT_N(gtx::EVR_PORT_N)
    ) DUT_EVR (
        .beacon_clk(beacon_clk),
        .gtx_if(gtx_if),
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(axi),
        
        .ev(ev),
        .trig(trig)
    );

    trig_generator trig_generator_i(
        .app_clk(app_clk),
        .app_rst(app_rst),
        .trig(trig)
    );
    
    virtual_clock_if clk_if (app_clk, app_rst);
    axi_driver driver;
    link_csr_generator generator;
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    initial begin
        driver    = new(clk_if, axi, req_mbx, resp_mbx);
        generator = new(clk_if, req_mbx, resp_mbx, 0, $sformatf("EVR with topo id \t%x\t", TOPO_ID));
    end
    initial begin
        @(negedge app_rst);
        fork
        wait_delay_status();
        wait_dc_status();
        enable_dc();
        periodic_dump();
        join
    end

    task wait_delay_status();
        $timeformat(-3, 5, " ms");
        generator.wait_delay_status(0, evn::INITIAL, 10us);
        $root.treeTB.display_key.get();
        $display("Get EVR with topo id %x ports INITIAL state at %t\n", TOPO_ID, $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();

        generator.wait_delay_status(0, evn::ONE_CYCLE, 1ms);
        $root.treeTB.display_key.get();
        $display("Get EVR with topo id %x ONE_CYCLE state at %t\n", TOPO_ID, $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();

        generator.wait_delay_status(0, evn::FINE, 100ms);
        $root.treeTB.display_key.get();
        $display("Get EVR with topo id %x FINE state at %t\n", TOPO_ID, $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();
    endtask

    task wait_dc_status();
        $timeformat(-3, 5, " ms");
        generator.wait_dc_status(0, evn::INITIAL, 10us);
        $root.treeTB.display_key.get();
        $display("Get EVR with topo id %x compensation INITIAL state at %t\n", TOPO_ID, $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();
        generator.wait_dc_status(0, evn::ONE_CYCLE, 1ms);
        $root.treeTB.display_key.get();
        $display("Get EVR with topo id %x compensation ONE_CYCLE state at %t\n", TOPO_ID, $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();
        generator.wait_dc_status(0, evn::FINE, 100ms);
        $root.treeTB.display_key.get();
        $display("Get EVR with topo id %x compensation FINE state at %t\n", TOPO_ID, $realtime);
        #1us;
        generator.dump();
        $root.treeTB.display_key.put();
    endtask

    task enable_dc();
        localparam POOL_DURATION = 100us;
        evn::delay_t rd_tgt_delay;
        do begin
            generator.get_tgt_delay(rd_tgt_delay);
        end while(rd_tgt_delay == 0);
        generator.enable_dc();
    endtask

    task periodic_dump();
        forever begin
            $root.treeTB.display_key.get();
            $display("Periodic Dump EVR with topo id %x", TOPO_ID);
            generator.dump();
            $root.treeTB.display_key.put();
            #1ms;
        end
    endtask
endmodule

module ev_generator(
    input  logic     app_clk,
    input  logic     app_rst,
    output evn::ev_t ev 
);  
    int ev_cnt = 0;
    always_ff @(posedge app_clk) begin
        if(ev_cnt == 0) begin
            ev     <= app_rst ? 0 : 'h123456;
            ev_cnt <= 4;
        end else begin
            ev     <= '0;
            ev_cnt <= ev_cnt - 1;
        end
    end
endmodule

module trig_generator(
    input  logic       app_clk,
    input  logic       app_rst,
    output evn::trig_t trig 
);  
    int trig_cnt = 0;
    always_ff @(posedge app_clk) begin
        if(trig_cnt == 0) begin
            trig     <= app_rst ? 0 : 'h123456;
            trig_cnt <= 1000;
        end else begin
            trig     <= '0;
            trig_cnt <= trig_cnt - 1;
        end
    end
endmodule

module ev_monitor(
    input  evn::ev_t    tx_ev,
    input  logic        tx_app_clk,
    input  evn::delay_t target_delay,
    input  evn::ev_t    rx_ev
);
    import evn::*;

    typedef logic [DELAY_INT_W-1:0] cnt_t;

    ev_t  rx_ev_sync;
    always_ff @(posedge tx_app_clk) rx_ev_sync <= rx_ev;

    ev_t  ev_in_line [$];
    cnt_t cnt_for_ev [$];
    int len = 0;

    always_ff @(posedge tx_app_clk) begin
        if(tx_ev != '0) begin
            ev_in_line.push_back(tx_ev);
            cnt_for_ev.push_back('0);
            len <= len +1;
        end
        if(rx_ev_sync == ev_in_line[0]) begin
            ev_in_line.pop_front();
            cnt_for_ev.pop_front();
            len <= len -1;
        end
        foreach(cnt_for_ev[i]) begin
            cnt_for_ev[i] += 1;
            //assert(cnt_for_ev[i] < ((target_delay >> DELAY_FRAC_W) + 200)) else $display("event %x expired at time %t at %m", ev_in_line[i], $realtime);
        end
    end
endmodule

module trig_monitor(
    input  evn::trig_t  tx_trig,
    input  logic        tx_app_clk,
    input  evn::delay_t target_delay,
    input  evn::trig_t  rx_trig
);
    import evn::*;

    typedef logic [DELAY_INT_W-1:0] cnt_t;

    ev_t  rx_trig_sync;
    always_ff @(posedge tx_app_clk) rx_trig_sync <= rx_trig;

    ev_t  trig_in_line [$];
    cnt_t cnt_for_trig [$];

    always_ff @(posedge tx_app_clk) begin
        if(tx_trig != '0) begin
            trig_in_line.push_back(tx_trig);
            cnt_for_trig.push_back('0);
        end
        if(rx_trig_sync & trig_in_line[0] == rx_trig_sync) begin
            trig_in_line.pop_front();
            cnt_for_trig.pop_front();
        end
        foreach(cnt_for_trig[i]) begin
            cnt_for_trig[i] += 1;
            //assert(cnt_for_trig[i] < (target_delay >> DELAY_FRAC_W + 2)) else $display("trig %x expired at time %t at %m", trig_in_line[i], $realtime);
        end
    end
endmodule