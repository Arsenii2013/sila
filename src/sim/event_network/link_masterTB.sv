`timescale 1ns/1ns
`include "top.svh"

module link_masterTB(

    );

    logic     sfp_tx_clk;
    logic     sfp_rx_clk;
    logic     app_clk;
    logic     app_rst;
    logic     beacon_clk;

    axi4_lite_if #(.AW(32), .DW(32)) mmr();

    axi_stream_if #(.DW(32)) in_packet();
    axi_stream_if #(.DW(32)) out_packet();

    sys_clk_gen
    #(
        .halfcycle (2857), // 5000 ps = 125 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (sfp_tx_clk)
    );
    assign #1.5ns sfp_rx_clk = sfp_tx_clk;

    sys_clk_gen
    #(
        .halfcycle (2856.5), // 2856.5 ps ~ 175_039_383  Hz
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (beacon_clk)
    );

    int ev_cnt = 0;
    logic [23:0] ev;
    always_ff @(posedge app_clk) begin
        if(ev_cnt == 0) begin
            ev     <= 'h123456;
            ev_cnt <= 4;
        end else begin
            ev     <= '0;
            ev_cnt <= ev_cnt - 1;
        end
    end

    logic         tx_resetdone;
    logic [31: 0] tx_data;
    logic [ 3: 0] tx_charisk;
    logic         rx_resetdone;
    logic [31: 0] rx_data;
    logic [ 3: 0] rx_charisk;

    link_master DUT(
        .beacon_clk(beacon_clk),

        //------GTP signals-------
        .aligned(tx_resetdone),

        .tx_resetdone(tx_resetdone),
        .tx_clk(sfp_tx_clk),
        .tx_data(tx_data),
        .tx_charisk(tx_charisk),

        .rx_resetdone(rx_resetdone),
        .rx_clk(sfp_rx_clk),
        .rx_data(rx_data),
        .rx_charisk(rx_charisk),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        
        .ev(ev), 
        .trig(),
        .in_packet(in_packet),
        .out_packet(out_packet)
    );

    axi_master axi_master_i(
        .aclk(app_clk),
        .aresetn(app_rst),
        .axi(mmr)
    );

    link_model link_i (
        .tx_resetdone(tx_resetdone),
        .tx_clk(sfp_tx_clk),
        .tx_data(tx_data),
        .tx_charisk(tx_charisk),

        .rx_resetdone(rx_resetdone),
        .rx_clk(sfp_rx_clk),
        .rx_data(rx_data),
        .rx_charisk(rx_charisk),

        .app_clk(app_clk),
        .app_rst(app_rst)
    );

    logic [31:0] status;
    logic [31:0] topo_id;
    logic [31:0] measured_delay;

    initial begin
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk)
        app_rst <= 0;

        $timeformat(-3, 5, " ms");

        wait(DUT.delay_st == 5'h1);
        $display("Get INITIAL state at %t\n", $realtime);
        #10us;
        axi_master_i.read('h00, status);
        axi_master_i.read('h10, topo_id);
        axi_master_i.read('h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %x", measured_delay);

        wait(DUT.delay_st == 5'h3);
        $display("Get ONE_CYCLE state at %t\n", $realtime);
        #10us;
        axi_master_i.read('h00, status);
        axi_master_i.read('h10, topo_id);
        axi_master_i.read('h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %x", measured_delay);

        wait(DUT.delay_st == 5'h7);
        $display("Get FINE state at %t\n", $realtime);
        #10us;
        axi_master_i.read('h00, status);
        axi_master_i.read('h10, topo_id);
        axi_master_i.read('h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %x", measured_delay);
        $stop();
    end

    initial begin
        #500ms;
        $display("Timeout! Cant get FINE state in %t\n", $realtime);
        $stop();
    end

endmodule

module link_model #(
    localparam PROPAGATION_DELAY = 1234.56ns
)(
    output logic         tx_resetdone,
    input  logic         tx_clk,
    input  logic [31: 0] tx_data,
    input  logic [ 3: 0] tx_charisk,

    output logic         rx_resetdone,
    input  logic         rx_clk,
    output logic [31: 0] rx_data,
    output logic [ 3: 0] rx_charisk,
    
    input  logic         app_clk,
    input  logic         app_rst
);
    always_ff @(posedge app_clk) begin
        tx_resetdone <= ~app_rst;
        rx_resetdone <= ~app_rst;
    end
    
    logic [31: 0] tx_data_propagated = '0;
    always @(tx_data) tx_data_propagated <= #(PROPAGATION_DELAY) tx_data;
    always_ff @(posedge rx_clk) rx_data <= tx_data_propagated;

    logic [3: 0] tx_charisk_propagated = '0;
    always @(tx_charisk) tx_charisk_propagated <= #(PROPAGATION_DELAY) tx_charisk;
    always_ff @(posedge rx_clk) rx_charisk <= tx_charisk_propagated;

endmodule