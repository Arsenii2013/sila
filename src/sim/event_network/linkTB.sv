`timescale 1ns/1ns
`include "top.svh"
`include "evn.svh"

import evn::*;

module linkTB(

    );
    localparam PROPAGATION_DELAY = 12345.56ns;

    logic     master_tx_clk; // из опоры master
    logic     master_rx_clk; // = slave_tx_clk + набег фазы равный задержке 
    logic     slave_tx_clk; // = slave_rx_clk + набег фазы от вывода на джиттер клинер
    logic     slave_rx_clk; // = master_tx_clk + набег фазы равный задержке 
    logic     master_app_clk;
    logic     slave_app_clk;
    logic     app_rst;
    logic     beacon_clk;
    logic     aligned;

    sys_clk_gen
    #(
        .halfcycle (2857), // 5000 ps = 125 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (master_tx_clk)
    );
    assign #1.5ns slave_rx_clk = master_tx_clk;
    assign #1.5ns slave_tx_clk = slave_rx_clk;
    assign #1.5ns master_rx_clk = slave_tx_clk;

    sys_clk_gen
    #(
        .halfcycle (2856.5), // 2856.5 ps ~ 175_039_383  Hz
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (beacon_clk)
    );

    int ev_cnt = 0;
    logic [23:0] ev;
    always_ff @(posedge master_app_clk) begin
        if(ev_cnt == 0) begin
            ev     <= 'h123456;
            ev_cnt <= 4;
        end else begin
            ev     <= '0;
            ev_cnt <= ev_cnt - 1;
        end
    end


    int trig_cnt = 0;
    logic [23:0] trig;
    always_ff @(posedge slave_app_clk) begin
        if(trig_cnt == 0) begin
            trig     <= 'h123456;
            trig_cnt <= 4;
        end else begin
            trig     <= '0;
            trig_cnt <= trig_cnt - 1;
        end
    end

    logic [31: 0] master_tx_data;
    logic [ 3: 0] master_tx_charisk;
    logic [31: 0] master_rx_data = 0;
    logic [ 3: 0] master_rx_charisk = 0;

    logic [31: 0] slave_tx_data;
    logic [ 3: 0] slave_tx_charisk;
    logic [31: 0] slave_rx_data = 0;
    logic [ 3: 0] slave_rx_charisk = 0;


    logic [31: 0] master_tx_data_propagated = 0;
    logic [ 3: 0] master_tx_charisk_propagated = 0;

    always @(master_tx_data)    master_tx_data_propagated    <= #(PROPAGATION_DELAY) master_tx_data;
    always @(master_tx_charisk) master_tx_charisk_propagated <= #(PROPAGATION_DELAY) master_tx_charisk;

    always_ff @(posedge slave_rx_clk) slave_rx_data    <= master_tx_data_propagated;
    always_ff @(posedge slave_rx_clk) slave_rx_charisk <= master_tx_charisk_propagated;


    logic [31: 0] slave_tx_data_propagated = 0;
    logic [ 3: 0] slave_tx_charisk_propagated = 0;
    always @(slave_tx_data)    slave_tx_data_propagated    <= #(PROPAGATION_DELAY) slave_tx_data;
    always @(slave_tx_charisk) slave_tx_charisk_propagated <= #(PROPAGATION_DELAY) slave_tx_charisk;

    always_ff @(posedge master_rx_clk) master_rx_data    <= slave_tx_data_propagated;
    always_ff @(posedge master_rx_clk) master_rx_charisk <= slave_tx_charisk_propagated;

    axi_stream_if #(.DW(32)) master_in_packet();
    axi_stream_if #(.DW(32)) master_out_packet();
    link_data master_data();

    link_master masterDUT(
        .beacon_clk(beacon_clk),

        //------GTP signals-------
        .aligned(aligned),

        .tx_resetdone(~app_rst),
        .tx_clk(master_tx_clk),
        .tx_data(master_tx_data),
        .tx_charisk(master_tx_charisk),

        .rx_resetdone(~app_rst),
        .rx_clk(master_rx_clk),
        .rx_data(master_rx_data),
        .rx_charisk(master_rx_charisk),

        //------Application signals-------
        .app_clk(master_app_clk),
        .app_rst(app_rst),
        
        .ev(ev), 
        .trig(),
        .in_packet(master_in_packet),
        .out_packet(master_out_packet),
        .link_data(master_data)
    );

    axi_stream_if #(.DW(32)) slave_in_packet();
    axi_stream_if #(.DW(32)) slave_out_packet();
    link_data slave_data();

    link_slave slaveDUT(
        .beacon_clk(beacon_clk),

        //------GTP signals-------
        .aligned(aligned),

        .tx_resetdone(~app_rst),
        .tx_clk(slave_tx_clk),
        .tx_data(slave_tx_data),
        .tx_charisk(slave_tx_charisk),

        .rx_resetdone(~app_rst),
        .rx_clk(slave_rx_clk),
        .rx_data(slave_rx_data),
        .rx_charisk(slave_rx_charisk),

        //------Application signals-------
        .app_clk(slave_app_clk),
        .app_rst(app_rst),
        
        .ev(), 
        .trig(trig),
        .in_packet(slave_in_packet),
        .out_packet(slave_out_packet),
        .link_data(slave_data)
    );

    link_monitor link_monitor_i(
        .master_tx_clk(master_tx_clk),
        .master_rx_clk(master_rx_clk),
        .master_app_clk(master_app_clk),
        .slave_tx_clk(slave_tx_clk),
        .slave_rx_clk(slave_rx_clk),
        .slave_app_clk(slave_app_clk),
        .app_rst(app_rst),

        .s_d(slave_data),
        .m_d(master_data)
    );

    logic [31:0] rd_word;
    localparam SR_ADDR = 32'h0;
    localparam CR_ADDR = 32'h4;
    localparam CR_S_ADDR = 32'h8;
    localparam CR_C_ADDR = 32'hc;
    localparam TOPO_ID_ADDR = 32'h10;
    localparam LINK_DELAY_ADDR = 32'h14;
    localparam UPSTREAM_DELAY_ADDR = 32'h18;
    localparam SUBTREE_DELAY_ADDR = 32'h1c;
    localparam TGT_DELAY_ADDR = 32'h20;
    localparam DELAY_COMP_ADDR = 32'h24;

    logic slave_sub_delay_src    = 0;
    delay_t slave_sub_delay_tb   = '0;
    logic slave_sub_delay_upd_tb = 0;
    assign slave_data.sub_delay      = slave_sub_delay_src == 0 ? slave_data.up_delay     : slave_sub_delay_tb;
    assign slave_data.sub_delay_upd  = slave_sub_delay_src == 0 ? slave_data.up_delay_upd : slave_sub_delay_upd_tb;

    initial begin
        slave_data.delay_comp_ena   <= 0;
        master_data.topo_id         <= 'h1234;
        master_data.up_delay        <= 'h5678;
        master_data.tgt_delay       <= 'h9abc;
        slave_sub_delay_src         <= 1;
        slave_sub_delay_tb          <= 'hdef0;
        master_data.topo_id_upd     <= 0;
        master_data.up_delay_upd    <= 0;
        master_data.tgt_delay_upd   <= 0;

        app_rst <= 1;
        aligned <= 0;
        for(int i = 0; i < 10; i++)
            @(posedge master_app_clk);
        app_rst <= 0;
        #10us;
        aligned <= 1;

        $timeformat(-3, 5, " ms");
        fork
            begin
                masterDelayMeasurementTest();
            end
            begin
                slaveDelayMeasurementTest();
            end
            begin
                wait(slave_data.link_delay_st >= 4'h1);
                @(posedge slave_app_clk);
                slave_sub_delay_upd_tb  <= 1;
                @(posedge slave_app_clk);
                slave_sub_delay_upd_tb  <= 0;
                #100us;
                master_data.topo_id         <= 'h12345678;
                master_data.topo_id_upd     <= 1;
                master_data.up_delay        <= 'h0;
                master_data.up_delay_upd    <= 1;
                master_data.tgt_delay       <= PROPAGATION_DELAY * 2**16 + 'h10_8000_0000; // + 16.5 тактов
                master_data.tgt_delay_upd   <= 1;
                slave_sub_delay_src    <= 0;
                @(posedge master_app_clk);
                master_data.topo_id_upd     <= 0;
                master_data.up_delay_upd    <= 0;
                master_data.tgt_delay_upd   <= 0;

                #100us;
                $display("Test topo_id and up/sub/tgt delay");
                slave_data.dump();
                master_data.dump();
                slave_data.delay_comp_ena   <= 1;
                slaveDelayCompensationTest();
            end
        join
    end

    initial begin
        #500ms;
        $display("Timeout! Cant get FINE state in %t\n", $realtime);
        $stop();
    end

    task masterDelayMeasurementTest();
        wait(master_data.link_delay_st >= 4'h1);
        $display("Get master INITIAL state at %t\n", $realtime);
        #1us;
        master_data.dump();
        wait(master_data.link_delay_st >= 4'h3);
        $display("Get master ONE_CYCLE state at %t\n", $realtime);
        #1us;
        master_data.dump();
        wait(master_data.link_delay_st >= 4'h7);
        $display("Get master FINE state at %t\n", $realtime);
        #1us;
        master_data.dump();
    endtask

    task slaveDelayMeasurementTest();
        wait(slave_data.link_delay_st >= 4'h1);
        $display("Get slave INITIAL state at %t\n", $realtime);
        #1us;
        slave_data.dump();
        wait(slave_data.link_delay_st >= 4'h3);
        $display("Get slave ONE_CYCLE state at %t\n", $realtime);
        #1us;
        slave_data.dump();
        wait(slave_data.link_delay_st >= 4'h7);
        $display("Get slave FINE state at %t\n", $realtime);
        #1us;
        slave_data.dump();
    endtask

    task slaveDelayCompensationTest();
        wait(slave_data.delay_comp_st >= 4'h1);
        $display("Get slave compensation INITIAL state at %t\n", $realtime);
        #1us;
        slave_data.dump();
        wait(slave_data.delay_comp_st >= 4'h3);
        $display("Get slave compensation ONE_CYCLE state at %t\n", $realtime);
        #1us;
        slave_data.dump();
        wait(slave_data.delay_comp_st >= 4'h7);
        $display("Get slave  FINE state at %t\n", $realtime);
        #1us;
        slave_data.dump();
    endtask
endmodule


module link_monitor#(
    parameter PROPAGATION_DELAY_CYCLES = 2160
)(
    input logic     master_tx_clk,
    input logic     master_rx_clk,
    input logic     master_app_clk,
    input logic     slave_tx_clk,
    input logic     slave_rx_clk,
    input logic     slave_app_clk,
    input logic     app_rst,

    link_data       m_d,
    link_data       s_d
);
    localparam TIMEOUT = PROPAGATION_DELAY_CYCLES + 100;

    link_data m_d_prop();
    link_data s_d_prop();

    always @(m_d.topo_id)    m_d_prop.topo_id    <= repeat (TIMEOUT) @(posedge master_app_clk) m_d.topo_id;
    always @(m_d.link_delay) m_d_prop.link_delay <= repeat (TIMEOUT) @(posedge master_app_clk) m_d.link_delay;
    always @(m_d.up_delay)   m_d_prop.up_delay   <= repeat (TIMEOUT) @(posedge master_app_clk) m_d.up_delay;
    always @(m_d.tgt_delay)  m_d_prop.tgt_delay  <= repeat (TIMEOUT) @(posedge master_app_clk) m_d.tgt_delay;
    always @(s_d.sub_delay)  s_d_prop.sub_delay  <= repeat (TIMEOUT) @(posedge slave_app_clk)  s_d.sub_delay;

    assert property (@(posedge slave_app_clk)  m_d.topo_id_upd   |=> ##[PROPAGATION_DELAY_CYCLES:TIMEOUT] s_d.topo_id_upd);
    assert property (@(posedge slave_app_clk)  m_d.up_delay_upd  |=> ##[PROPAGATION_DELAY_CYCLES:TIMEOUT] s_d.up_delay_upd);
    assert property (@(posedge slave_app_clk)  m_d.tgt_delay_upd |=> ##[PROPAGATION_DELAY_CYCLES:TIMEOUT] s_d.tgt_delay_upd);
    assert property (@(posedge master_app_clk) s_d.sub_delay_upd |=> ##[PROPAGATION_DELAY_CYCLES:TIMEOUT] m_d.sub_delay_upd);

    assert property (@(posedge slave_app_clk)  m_d.topo_id_upd   |=> ##TIMEOUT (s_d.topo_id   == m_d_prop.topo_id));
    assert property (@(posedge slave_app_clk)  m_d.up_delay_upd  |=> ##TIMEOUT (s_d.up_delay  >= m_d_prop.up_delay));
    assert property (@(posedge slave_app_clk)  m_d.tgt_delay_upd |=> ##TIMEOUT (s_d.tgt_delay == m_d_prop.tgt_delay));
    assert property (@(posedge master_app_clk) s_d.sub_delay_upd |=> ##TIMEOUT (m_d.sub_delay == s_d_prop.sub_delay));
endmodule