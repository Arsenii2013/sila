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

    logic evg_rx_n [gtx::EVG_PORT_N];
    logic evg_rx_p [gtx::EVG_PORT_N];
    logic evg_tx_n [gtx::EVG_PORT_N];
    logic evg_tx_p [gtx::EVG_PORT_N];

    logic evr_rx_n [gtx::EVR_PORT_N];
    logic evr_rx_p [gtx::EVR_PORT_N];
    logic evr_tx_n [gtx::EVR_PORT_N];
    logic evr_tx_p [gtx::EVR_PORT_N];

    link_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY)
    ) link_evg_evr (
        .up_rx_n(evg_rx_n[0]),
        .up_rx_p(evg_rx_p[0]),
        .up_tx_n(evg_tx_n[0]),
        .up_tx_p(evg_tx_p[0]),
        .down_rx_n(evr_rx_n[0]),
        .down_rx_p(evr_rx_p[0]),
        .down_tx_n(evr_tx_n[0]),
        .down_tx_p(evr_tx_p[0])
    );

    topEVG DUT_EVG(
        .sysclk_n(~sysclk[0]),
        .sysclk_p(sysclk[0]),
        .REFCLK_SFP_n(~REFCLK_SFP[0]),
        .REFCLK_SFP_p(REFCLK_SFP[0]),

        .sfp_rx_n(evg_rx_n),
        .sfp_rx_p(evg_rx_p),
        .sfp_tx_n(evg_tx_n),
        .sfp_tx_p(evg_tx_p),
        .led(led)
    );

    topEVR DUT_EVR(
        .sysclk_n(~sysclk[1]),
        .sysclk_p(sysclk[1]),
        .REFCLK_SFP_n(~REFCLK_SFP[1]),
        .REFCLK_SFP_p(REFCLK_SFP[1]),

        .sfp_rx_n(evr_rx_n),
        .sfp_rx_p(evr_rx_p),
        .sfp_tx_n(evr_tx_n),
        .sfp_tx_p(evr_tx_p),
        .led()
    );

initial begin
    @(posedge led[3]);
    #500ms;
    $stop();
end
endmodule

