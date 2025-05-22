`timescale 1ns/1ns
`include "top.svh"

module topTB(

    );

    logic [3:0] led;
    logic     sysclk;

    sys_clk_gen
    #(
        .halfcycle (5000), // 5000 ps = 100 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (sysclk)
    );

    logic     REFCLK_SFP;

    sys_clk_gen
    #(
        .halfcycle (4000), // 4000 ps = 125 MHz
        .offset    (0)
    ) REFCLK_SFP_gen (
        .sys_clk (REFCLK_SFP)
    );

    logic sfp_rx_n [4];
    logic sfp_rx_p [4];
    logic sfp_tx_n [4];
    logic sfp_tx_p [4];

    assign sfp_rx_n = sfp_tx_n;
    assign sfp_rx_p = sfp_tx_p;

    top DUT(
        .sysclk_n(~sysclk),
        .sysclk_p(sysclk),
        .REFCLK_SFP_n(~REFCLK_SFP),
        .REFCLK_SFP_p(REFCLK_SFP),

        .sfp_rx_n(sfp_rx_n),
        .sfp_rx_p(sfp_rx_p),
        .sfp_tx_n(sfp_tx_n),
        .sfp_tx_p(sfp_tx_p),
        .led(led)
    );

initial begin
    @(posedge led[3]);
    #5000;
    $stop();
end
endmodule
