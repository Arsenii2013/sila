`timescale 1ns/1ns
`include "top.svh"

module topTB(

    );
    localparam PROPAGATION_DELAY = 1234.56ns;

    logic [3:0] led;
    logic     sysclk [2];

    sys_clk_gen
    #(
        .halfcycle (2500), // 2500 ps = 200 MHz on board system clock
        .offset    (0)
    ) CLK_GEN1 (
        .sys_clk (sysclk[0])
    );
    sys_clk_gen
    #(
        .halfcycle (2500.01), // 2500 ps = 200 MHz on board system clock
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (sysclk[1])
    );


    logic     REFCLK_SFP[2];

    sys_clk_gen
    #(
        .halfcycle (4000), // 4000 ps = 125 MHz
        .offset    (0)
    ) REFCLK_SFP_gen1 (
        .sys_clk (REFCLK_SFP[0])
    );
    sys_clk_gen
    #(
        .halfcycle (4000.01), // 4000 ps = 125 MHz
        .offset    (0)
    ) REFCLK_SFP_gen2 (
        .sys_clk (REFCLK_SFP[1])
    );

    logic sfp_rx_n [2][4];
    logic sfp_rx_p [2][4];
    logic sfp_tx_n [2][4];
    logic sfp_tx_p [2][4];

    always @(sfp_tx_p[0][0])    sfp_rx_p[1][0]    <= #(PROPAGATION_DELAY) sfp_tx_p[0][0];
    always @(sfp_tx_n[0][0])    sfp_rx_n[1][0]    <= #(PROPAGATION_DELAY) sfp_tx_n[0][0];
    always @(sfp_tx_p[1][0])    sfp_rx_p[0][0]    <= #(PROPAGATION_DELAY) sfp_tx_p[1][0];
    always @(sfp_tx_n[1][0])    sfp_rx_n[0][0]    <= #(PROPAGATION_DELAY) sfp_tx_n[1][0];

    topEVG DUT_EVG(
        .sysclk_n(~sysclk[0]),
        .sysclk_p(sysclk[0]),
        .REFCLK_SFP_n(~REFCLK_SFP[0]),
        .REFCLK_SFP_p(REFCLK_SFP[0]),

        .sfp_rx_n(sfp_rx_n[0]),
        .sfp_rx_p(sfp_rx_p[0]),
        .sfp_tx_n(sfp_tx_n[0]),
        .sfp_tx_p(sfp_tx_p[0]),
        .led(led)
    );

    topEVR DUT_EVR(
        .sysclk_n(~sysclk[1]),
        .sysclk_p(sysclk[1]),
        .REFCLK_SFP_n(~REFCLK_SFP[1]),
        .REFCLK_SFP_p(REFCLK_SFP[1]),

        .sfp_rx_n(sfp_rx_n[1]),
        .sfp_rx_p(sfp_rx_p[1]),
        .sfp_tx_n(sfp_tx_n[1]),
        .sfp_tx_p(sfp_tx_p[1]),
        .led()
    );

initial begin
    @(posedge led[3]);
    #500ms;
    $stop();
end
endmodule
