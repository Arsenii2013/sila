`timescale 1ns/10ps
`include "top.svh"
`include "evn.svh"

`define TEST_CONNECTED
`define TEST_30_KHZ_DIFF

module measureTB(

    );

    logic     sfp_tx_clk;
    logic     sfp_rx_clk;
    logic     app_clk;
    logic     beacon_clk;
    logic     app_rst;

    sys_clk_gen
    #(
        .halfcycle (2857), // 2857 ps ~ 175_008_750 Hz
        .offset    (0)
    ) CLK_GEN1 (
        .sys_clk (sfp_tx_clk)
    );

    sys_clk_gen
    #(
        `ifdef TEST_1_KHZ_DIFF
        .halfcycle (2856.99), // 2856.99 ps ~ 175_009_363  Hz
        `else
        .halfcycle (2856.5), // 2856.5 ps ~ 175_039_383  Hz
        `endif
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (beacon_clk)
    );

    assign app_clk = sfp_tx_clk;
    assign #1.5ns sfp_rx_clk = sfp_tx_clk;

    logic beacon_tx;
    logic beacon_rx;

    logic [4:0] delay_status;

    delay_measure DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
    
        .beacon_tx(beacon_tx),
        .tx_clk(sfp_tx_clk),
        .beacon_rx(beacon_rx),
        .rx_clk(sfp_rx_clk),
        .beacon_clk(beacon_clk),

        .delay_upd(),
        .delay(),
        .delay_status(delay_status)
    );

    beacon_generator bg(
        .sfp_tx_clk(sfp_tx_clk),
        .sfp_rx_clk(sfp_rx_clk),
        .beacon_tx(beacon_tx),
        .beacon_rx(beacon_rx),
        `ifdef TEST_NOT_CONNECTED
        .disconnect(1),
        .big_var(0),
        `elsif TEST_DISCONNECT_FINE
        .disconnect(delay_status == 5'h7),
        .big_var(0),
        `elsif TEST_DISCONNECT_ONECYCLE
        .disconnect(delay_status == 5'h3),
        .big_var(0),
        `elsif TEST_DISCONNECT_INITIAL
        .disconnect(delay_status == 5'h1),
        .big_var(0),
        `elsif TEST_BIG_VAR_FINE
        .disconnect(0),
        .big_var(delay_status == 5'h7),
        `elsif TEST_BIG_VAR_ONECYCLE
        .disconnect(0),
        .big_var(delay_status == 5'h3),
        `elsif TEST_BIG_VAR_INITIAL
        .disconnect(0),
        .big_var(delay_status == 5'h1),
        `else
        .disconnect(0),
        .big_var(0),
        `endif
        .rst(app_rst)
    );

    initial begin
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk)
        app_rst <= 0;

        wait(delay_status == 5'h7);
        #100000000;
        $stop();
    end

endmodule

module beacon_generator #(
    localparam PROPAGATION_DELAY = 1234.56ns
)
(
    input  logic sfp_tx_clk,
    input  logic sfp_rx_clk,
    output logic beacon_tx,
    output logic beacon_rx,
    input  logic disconnect,
    input  logic big_var,
    input  logic rst
);
    int cnt = BEACON_PERIOD;

    assign beacon_tx = cnt == 0;

    always_ff @(posedge sfp_tx_clk) begin
        if(beacon_tx)
            cnt <= BEACON_PERIOD;
        else 
            cnt <= cnt - 1;
    end

    logic beacon_tx_propagated;
    always @(beacon_tx) beacon_tx_propagated <= #(PROPAGATION_DELAY) beacon_tx;
    logic beacon_tx_prop_pulse;
    pf_m pf_i(
        .in(beacon_tx_propagated),
        .clk(sfp_tx_clk),
        .out(beacon_tx_prop_pulse)
    );

    logic beacon_rx_sync;
    xpm_cdc_pulse beacon_rst_sunchronizer_i(
        .dest_clk(sfp_rx_clk),
        .dest_pulse(beacon_rx_sync),
        .dest_rst(rst),
        .src_clk(sfp_tx_clk),
        .src_pulse(beacon_tx_prop_pulse),
        .src_rst(rst)
    );

    logic beacon_rx_dly;
    always @(beacon_rx_sync) beacon_rx_dly <= #(100) beacon_rx_sync;

    assign beacon_rx = disconnect ? 0 : big_var ? beacon_rx_dly : beacon_rx_sync;
endmodule