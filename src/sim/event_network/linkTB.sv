`timescale 1ns/1ns
`include "top.svh"

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

    axi4_lite_if #(.AW(32), .DW(32)) master_mmr();

    axi_stream_if #(.DW(32)) master_in_packet();
    axi_stream_if #(.DW(32)) master_out_packet();

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
        .mmr(master_mmr),
        
        .ev(ev), 
        .trig(),
        .in_packet(master_in_packet),
        .out_packet(master_out_packet)
    );

    axi4_lite_if #(.AW(32), .DW(32)) slave_mmr();

    axi_stream_if #(.DW(32)) slave_in_packet();
    axi_stream_if #(.DW(32)) slave_out_packet();
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
        .mmr(slave_mmr),
        
        .ev(), 
        .trig(trig),
        .in_packet(slave_in_packet),
        .out_packet(slave_out_packet)
    );

    axi_master axi_master_link_master(
        .aclk(master_app_clk),
        .aresetn(app_rst),
        .axi(master_mmr)
    );
    axi_master axi_master_link_slave(
        .aclk(slave_app_clk),
        .aresetn(app_rst),
        .axi(slave_mmr)
    );

    logic [31:0] status;
    logic [31:0] topo_id;
    logic [31:0] measured_delay;
    logic [31:0] delay_comp;

    initial begin
        app_rst <= 1;
        aligned <= 0;
        for(int i = 0; i < 10; i++)
            @(posedge master_app_clk);
        app_rst <= 0;
        #10us;
        aligned <= 1;


        $timeformat(-3, 5, " ms");
        axi_master_link_master.write('h18, PROPAGATION_DELAY * 2**16 + 'h10_8000_0000); // + 16.5 тактов

        wait(masterDUT.delay_st == 4'h1);
        $display("Get INITIAL state at %t\n", $realtime);
        #100us;
        axi_master_link_slave.write('h04, 'h1);

        axi_master_link_master.read('h00, status);
        axi_master_link_master.read('h10, topo_id);
        axi_master_link_master.read('h14, measured_delay);
        $display("EVG status:\t %x", status);
        $display("EVG topology ID:\t %x", topo_id);
        $display("EVG link delay:\t %e", (measured_delay >> 16) / 175e6);

        axi_master_link_slave.read('h00, status);
        axi_master_link_slave.read('h10, topo_id);
        axi_master_link_slave.read('h14, measured_delay);
        $display("EVR status:\t %x", status);
        $display("EVR topology ID:\t %x", topo_id);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(masterDUT.delay_st == 4'h3);
        $display("Get ONE_CYCLE state at %t\n", $realtime);
        #100us;

        axi_master_link_master.read('h00, status);
        axi_master_link_master.read('h10, topo_id);
        axi_master_link_master.read('h14, measured_delay);
        $display("EVG status:\t %x", status);
        $display("EVG topology ID:\t %x", topo_id);
        $display("EVG link delay:\t %e", (measured_delay >> 16) / 175e6);

        axi_master_link_slave.read('h00, status);
        axi_master_link_slave.read('h10, topo_id);
        axi_master_link_slave.read('h14, measured_delay);
        $display("EVR status:\t %x", status);
        $display("EVR topology ID:\t %x", topo_id);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(masterDUT.delay_st == 4'h7);
        $display("Get FINE state at %t\n", $realtime);
        #100us;
        axi_master_link_master.read('h00, status);
        axi_master_link_master.read('h10, topo_id);
        axi_master_link_master.read('h14, measured_delay);
        $display("EVG status:\t %x", status);
        $display("EVG topology ID:\t %x", topo_id);
        $display("EVG link delay:\t %e", (measured_delay >> 16) / 175e6);

        axi_master_link_slave.read('h00, status);
        axi_master_link_slave.read('h10, topo_id);
        axi_master_link_slave.read('h14, measured_delay);
        $display("EVR status:\t %x", status);
        $display("EVR topology ID:\t %x", topo_id);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $stop();
    end

    initial begin
        wait(slaveDUT.dc_status == 4'h1);
        $display("Get compensation INITIAL state at %t\n", $realtime);
        #100us;
        axi_master_link_slave.read('h00, status);
        axi_master_link_slave.read('h1C, delay_comp);
        $display("EVR status:\t %x", status);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $display("EVR delay comp:\t %e", (delay_comp >> 16) / 175e6);

        wait(slaveDUT.dc_status == 4'h3);
        $display("Get compensation ONE_CYCLE state at %t\n", $realtime);
        #100us;
        axi_master_link_slave.read('h00, status);
        axi_master_link_slave.read('h1C, delay_comp);
        $display("EVR status:\t %x", status);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $display("EVR delay comp:\t %e", (delay_comp >> 16) / 175e6);

        wait(slaveDUT.dc_status == 4'h7);
        $display("Get compensation FINE state at %t\n", $realtime);
        #100us;
        axi_master_link_slave.read('h00, status);
        axi_master_link_slave.read('h1C, delay_comp);
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
