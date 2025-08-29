`timescale 1ns/1ns
`include "top.svh"
`include "evn.svh"

import evn::*;

module treeTB(

    );
    localparam PROPAGATION_DELAY = 12345.56ns;
    localparam EVR_CNT = 1;
    import evn::*;

    logic     evg_ref_clk;
    logic     evg_app_clk;
    gtx_if    evg_gtx[EVR_CNT]();
    ev_t      evg_ev;
    trig_t    evg_trig;

    logic     evr_ref_clk[EVR_CNT];
    logic     evr_app_clk[EVR_CNT];
    gtx_if    evr_gtx[EVR_CNT]();
    ev_t      evr_ev[EVR_CNT];
    trig_t    evr_trig[EVR_CNT];

    logic     app_rst;
    logic     beacon_clk;

    sys_clk_gen
    #(
        .halfcycle (2857), // 5000 ps = 125 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (evg_ref_clk)
    );
    genvar i;
    generate
    for(i = 0; i < EVR_CNT; i ++) begin : evr_ref_clocking
    sys_clk_gen
    #(
        .halfcycle (2857), // 5000 ps = 125 MHz
        .offset    (i * 1234)
    ) CLK_GEN (
        .sys_clk (evr_ref_clk[i])
    );
    end
    endgenerate
    sys_clk_gen
    #(
        .halfcycle (2856.5), // 2856.5 ps ~ 175_039_383  Hz
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (beacon_clk)
    );

    axi4_lite_if #(.AW(32), .DW(32)) evg_axi();
    axi4_lite_if #(.AW(32), .DW(32)) evr_axi();

    gtx_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY)
    ) evg_to_evr(
        .from(evg_gtx[0]),
        .from_ref_clk(evg_ref_clk),
        .to(evr_gtx[0]),
        .to_ref_clk(evr_ref_clk[0])
    );

    evg #(
        .PORT_N(EVR_CNT)
    ) DUT_EVG (
        .beacon_clk(beacon_clk),
        .gtx_if(evg_gtx),
        .app_clk(evg_app_clk),
        .app_rst(app_rst),
        .mmr(evg_axi),
        
        .ev(evg_ev),
        .trig(evg_trig)
    );

    evr #(
        .PORT_N(1)
    ) DUT_EVR (
        .beacon_clk(beacon_clk),
        .gtx_if(evr_gtx),
        .app_clk(evr_app_clk[0]),
        .app_rst(app_rst),
        .mmr(evr_axi),
        
        .ev(evr_ev[0]),
        .trig(evr_trig[0])
    );

    ev_generator evg_ev_generator(
        .app_clk(evg_app_clk),
        .app_rst(app_rst),
        .ev(evg_ev)
    );

    genvar j;
    generate
    for(j = 0; j < EVR_CNT; j ++) begin : evr_monitors
    /*ev_monitor ev_monitor_i(
        .tx_ev(evg_ev),
        .tx_app_clk(evg_app_clk),
        .target_delay(axi_monitor_i.evg_generator.time_to_delay_t(PROPAGATION_DELAY + 100ns)),
        .rx_ev(evr_ev[j])
    );
    trig_monitor trig_monitor_i(
        .tx_trig(evr_trig[j]),
        .tx_app_clk(evr_app_clk[j]),
        .target_delay(axi_monitor_i.evg_generator.time_to_delay_t(PROPAGATION_DELAY + 100ns)),
        .rx_trig(evg_trig)
    );*/
    trig_generator trig_generator_i(
        .app_clk(evr_app_clk[j]),
        .app_rst(app_rst),
        .trig(evr_trig[j])
    );
    end
    endgenerate

    axi_monitor axi_monitor_i(
        .evg_app_clk(evg_app_clk),
        .evg_axi(evg_axi),
        .evr_app_clk(evr_app_clk[0]),
        .evr_axi(evr_axi)
    );

    initial begin
        app_rst <= 1;
        repeat (100) @(posedge evg_app_clk);
        app_rst <= 0;
        #10us;

        $timeformat(-3, 5, " ms");
        fork
            begin
                axi_monitor_i.evrDelayMeasurementTest();
            end
            begin
                axi_monitor_i.evrDelayCompensationTest();
            end
            begin
                axi_monitor_i.setTgtDelayAndDCEna(PROPAGATION_DELAY + 100ns);
            end
            begin
                axi_monitor_i.periodicDump();
            end
        join
    end

    initial begin
        #500ms;
        $display("Timeout! Cant get FINE state in %t\n", $realtime);
        $stop();
    end
endmodule

module axi_monitor(
    input  logic   evg_app_clk,
    axi4_lite_if.m evg_axi,
    input  logic   evr_app_clk,
    axi4_lite_if.m evr_axi
);
    logic evg_app_rst;
    logic evr_app_rst;
    virtual_clock_if evg_clk_if (evg_app_clk, evg_app_rst);
    virtual_clock_if evr_clk_if (evr_app_clk, evr_app_rst);
    axi_driver evg_driver;
    axi_driver evr_driver;
    link_csr_generator evg_generator;
    link_csr_generator evr_generator;
    axi_transaction_pkg::item_mailbox_t evg_req_mbx = new(), evg_resp_mbx = new();
    axi_transaction_pkg::item_mailbox_t evr_req_mbx = new(), evr_resp_mbx = new();

    initial begin
        evg_driver    = new(evg_clk_if, evg_axi, evg_req_mbx, evg_resp_mbx);
        evg_generator = new(evg_clk_if, evg_req_mbx, evg_resp_mbx, 0);
        evr_driver    = new(evr_clk_if, evr_axi, evr_req_mbx, evr_resp_mbx);
        evr_generator = new(evr_clk_if, evr_req_mbx, evr_resp_mbx, 0);
        fork
            evg_driver.serve_mailboxes();
            evr_driver.serve_mailboxes();
        join_none
    end

    task evrDelayMeasurementTest();
        evr_generator.wait_delay_status(0, evn::INITIAL, 10us);
        $display("Get evr port 0 INITIAL state at %t\n", $realtime);
        #1us;
        evr_generator.dump();

        evr_generator.verify_topo_id(1);

        evr_generator.wait_delay_status(0, evn::ONE_CYCLE, 1ms);
        $display("Get evr port 0 ONE_CYCLE state at %t\n", $realtime);
        #1us;
        evr_generator.dump();
        evr_generator.wait_delay_status(0, evn::FINE, 100ms);
        $display("Get evr port 0 FINE state at %t\n", $realtime);
        #1us;
        evr_generator.dump();
    endtask

    task evrDelayCompensationTest();
        evr_generator.wait_dc_status(0, evn::INITIAL, 10us);
        $display("Get evr port 0 compensation INITIAL state at %t\n", $realtime);
        #1us;
        evr_generator.dump();
        evr_generator.wait_dc_status(0, evn::ONE_CYCLE, 1ms);
        $display("Get evr port 0 compensation ONE_CYCLE state at %t\n", $realtime);
        #1us;
        evr_generator.dump();
        evr_generator.wait_dc_status(0, evn::FINE, 100ms);
        $display("Get evr port 0 compensation FINE state at %t\n", $realtime);
        #1us;
        evr_generator.dump();
    endtask

    task setTgtDelayAndDCEna(input time tgt_delay);
        evg_generator.wait_delay_status(0, evn::INITIAL, 10us);
        #10us;
        evg_generator.set_tgt_delay(evg_generator.time_to_delay_t(tgt_delay));
        evr_generator.enable_dc();
    endtask

    task periodicDump();
        forever begin
            $display("Periodic Dump");
            evr_generator.dump();
            evg_generator.dump();
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
            trig_cnt <= 4;
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