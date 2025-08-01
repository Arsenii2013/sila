`timescale 1ns/1ns
`include "top.svh"

module linkTB(

    );
    localparam PROPAGATION_DELAY = 12345.56ns;

    logic     evg_tx_clk; // из опоры evg
    logic     evg_rx_clk; // = evr_tx_clk + набег фазы равный задержке 
    logic     evr_tx_clk; // = evr_rx_clk + набег фазы от вывода на джиттер клинер
    logic     evr_rx_clk; // = evg_tx_clk + набег фазы равный задержке 
    logic     evg_app_clk;
    logic     evr_app_clk;
    logic     app_rst;
    logic     beacon_clk;
    logic     aligned;

    sys_clk_gen
    #(
        .halfcycle (2857), // 5000 ps = 125 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (evg_tx_clk)
    );
    assign #1.5ns evr_rx_clk = evg_tx_clk;
    assign #1.5ns evr_tx_clk = evr_rx_clk;
    assign #1.5ns evg_rx_clk = evr_tx_clk;

    sys_clk_gen
    #(
        .halfcycle (2856.5), // 2856.5 ps ~ 175_039_383  Hz
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (beacon_clk)
    );

    int ev_cnt = 0;
    logic [23:0] ev;
    always_ff @(posedge evg_app_clk) begin
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
    always_ff @(posedge evr_app_clk) begin
        if(trig_cnt == 0) begin
            trig     <= 'h123456;
            trig_cnt <= 4;
        end else begin
            trig     <= '0;
            trig_cnt <= trig_cnt - 1;
        end
    end

    logic [31: 0] evg_tx_data;
    logic [ 3: 0] evg_tx_charisk;
    logic [31: 0] evg_rx_data = 0;
    logic [ 3: 0] evg_rx_charisk = 0;

    logic [31: 0] evr_tx_data;
    logic [ 3: 0] evr_tx_charisk;
    logic [31: 0] evr_rx_data = 0;
    logic [ 3: 0] evr_rx_charisk = 0;


    logic [31: 0] evg_tx_data_propagated = 0;
    logic [ 3: 0] evg_tx_charisk_propagated = 0;

    always @(evg_tx_data)    evg_tx_data_propagated    <= #(PROPAGATION_DELAY) evg_tx_data;
    always @(evg_tx_charisk) evg_tx_charisk_propagated <= #(PROPAGATION_DELAY) evg_tx_charisk;

    always_ff @(posedge evr_rx_clk) evr_rx_data    <= evg_tx_data_propagated;
    always_ff @(posedge evr_rx_clk) evr_rx_charisk <= evg_tx_charisk_propagated;


    logic [31: 0] evr_tx_data_propagated = 0;
    logic [ 3: 0] evr_tx_charisk_propagated = 0;
    always @(evr_tx_data)    evr_tx_data_propagated    <= #(PROPAGATION_DELAY) evr_tx_data;
    always @(evr_tx_charisk) evr_tx_charisk_propagated <= #(PROPAGATION_DELAY) evr_tx_charisk;

    always_ff @(posedge evg_rx_clk) evg_rx_data    <= evr_tx_data_propagated;
    always_ff @(posedge evg_rx_clk) evg_rx_charisk <= evr_tx_charisk_propagated;

    axi4_lite_if #(.AW(32), .DW(32)) evg_mmr();

    axi_stream_if #(.DW(32)) evg_in_packet();
    axi_stream_if #(.DW(32)) evg_out_packet();

    evg evgDUT(
        .beacon_clk(beacon_clk),

        //------GTP signals-------
        .aligned(aligned),

        .tx_resetdone(~app_rst),
        .tx_clk(evg_tx_clk),
        .tx_data(evg_tx_data),
        .tx_charisk(evg_tx_charisk),

        .rx_resetdone(~app_rst),
        .rx_clk(evg_rx_clk),
        .rx_data(evg_rx_data),
        .rx_charisk(evg_rx_charisk),

        //------Application signals-------
        .app_clk(evg_app_clk),
        .app_rst(app_rst),
        .mmr(evg_mmr),
        
        .ev(ev), 
        .trig(),
        .in_packet(evg_in_packet),
        .out_packet(evg_out_packet)
    );

    axi4_lite_if #(.AW(32), .DW(32)) evr_mmr();

    axi_stream_if #(.DW(32)) evr_in_packet();
    axi_stream_if #(.DW(32)) evr_out_packet();
    evr evrDUT(
        .beacon_clk(beacon_clk),

        //------GTP signals-------
        .aligned(aligned),

        .tx_resetdone(~app_rst),
        .tx_clk(evr_tx_clk),
        .tx_data(evr_tx_data),
        .tx_charisk(evr_tx_charisk),

        .rx_resetdone(~app_rst),
        .rx_clk(evr_rx_clk),
        .rx_data(evr_rx_data),
        .rx_charisk(evr_rx_charisk),

        //------Application signals-------
        .app_clk(evr_app_clk),
        .app_rst(app_rst),
        .mmr(evr_mmr),
        
        .ev(), 
        .trig(trig),
        .in_packet(evr_in_packet),
        .out_packet(evr_out_packet)
    );

    axi_master axi_master_evg(
        .aclk(evg_app_clk),
        .aresetn(app_rst),
        .axi(evg_mmr)
    );
    axi_master axi_master_evr(
        .aclk(evr_app_clk),
        .aresetn(app_rst),
        .axi(evr_mmr)
    );

    logic [31:0] status;
    logic [31:0] topo_id;
    logic [31:0] measured_delay;
    logic [31:0] delay_comp;

    initial begin
        app_rst <= 1;
        aligned <= 0;
        for(int i = 0; i < 10; i++)
            @(posedge evg_app_clk);
        app_rst <= 0;
        #10us;
        aligned <= 1;


        $timeformat(-3, 5, " ms");
        axi_master_evg.write('h18, PROPAGATION_DELAY * 2**16 + 'h10_8000_0000); // + 16.5 тактов

        wait(evgDUT.delay_st == 4'h1);
        $display("Get INITIAL state at %t\n", $realtime);
        #100us;
        axi_master_evr.write('h04, 'h1);

        axi_master_evg.read('h00, status);
        axi_master_evg.read('h10, topo_id);
        axi_master_evg.read('h14, measured_delay);
        $display("EVG status:\t %x", status);
        $display("EVG topology ID:\t %x", topo_id);
        $display("EVG link delay:\t %e", (measured_delay >> 16) / 175e6);

        axi_master_evr.read('h00, status);
        axi_master_evr.read('h10, topo_id);
        axi_master_evr.read('h14, measured_delay);
        $display("EVR status:\t %x", status);
        $display("EVR topology ID:\t %x", topo_id);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(evgDUT.delay_st == 4'h3);
        $display("Get ONE_CYCLE state at %t\n", $realtime);
        #100us;

        axi_master_evg.read('h00, status);
        axi_master_evg.read('h10, topo_id);
        axi_master_evg.read('h14, measured_delay);
        $display("EVG status:\t %x", status);
        $display("EVG topology ID:\t %x", topo_id);
        $display("EVG link delay:\t %e", (measured_delay >> 16) / 175e6);

        axi_master_evr.read('h00, status);
        axi_master_evr.read('h10, topo_id);
        axi_master_evr.read('h14, measured_delay);
        $display("EVR status:\t %x", status);
        $display("EVR topology ID:\t %x", topo_id);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(evgDUT.delay_st == 4'h7);
        $display("Get FINE state at %t\n", $realtime);
        #100us;
        axi_master_evg.read('h00, status);
        axi_master_evg.read('h10, topo_id);
        axi_master_evg.read('h14, measured_delay);
        $display("EVG status:\t %x", status);
        $display("EVG topology ID:\t %x", topo_id);
        $display("EVG link delay:\t %e", (measured_delay >> 16) / 175e6);

        axi_master_evr.read('h00, status);
        axi_master_evr.read('h10, topo_id);
        axi_master_evr.read('h14, measured_delay);
        $display("EVR status:\t %x", status);
        $display("EVR topology ID:\t %x", topo_id);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $stop();
    end

    initial begin
        wait(evrDUT.dc_status == 4'h1);
        $display("Get compensation INITIAL state at %t\n", $realtime);
        #100us;
        axi_master_evr.read('h00, status);
        axi_master_evr.read('h1C, delay_comp);
        $display("EVR status:\t %x", status);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $display("EVR delay comp:\t %e", (delay_comp >> 16) / 175e6);

        wait(evrDUT.dc_status == 4'h3);
        $display("Get compensation ONE_CYCLE state at %t\n", $realtime);
        #100us;
        axi_master_evr.read('h00, status);
        axi_master_evr.read('h1C, delay_comp);
        $display("EVR status:\t %x", status);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $display("EVR delay comp:\t %e", (delay_comp >> 16) / 175e6);

        wait(evrDUT.dc_status == 4'h7);
        $display("Get compensation FINE state at %t\n", $realtime);
        #100us;
        axi_master_evr.read('h00, status);
        axi_master_evr.read('h1C, delay_comp);
        $display("EVR status:\t %x", status);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $display("EVR delay comp:\t %e", (delay_comp >> 16) / 175e6);

        $stop();
    end

    initial begin
        #500ms;
        $display("Timeout! Cant get FINE state in %t\n", $realtime);
        $stop();
    end

endmodule
