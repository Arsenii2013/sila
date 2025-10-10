`timescale 1ns/1ns
`include "top.svh"

module topTB(

    );
    localparam time PROPAGATION_DELAY_DEEP_0_PORT_0 = 1231.56ns;
    localparam time PROPAGATION_DELAY_DEEP_0_PORT_1 = 560.12ns;
    localparam time PROPAGATION_DELAY_DEEP_1_PORT_0 = 337ns;
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

    semaphore display_key = new(1);

    logic evg_rx_n [gtx::EVG_PORT_N];
    logic evg_rx_p [gtx::EVG_PORT_N];
    logic evg_tx_n [gtx::EVG_PORT_N];
    logic evg_tx_p [gtx::EVG_PORT_N];

    logic fanout_rx_n [FANOUT_CNT][gtx::FANOUT_PORT_N];
    logic fanout_rx_p [FANOUT_CNT][gtx::FANOUT_PORT_N];
    logic fanout_tx_n [FANOUT_CNT][gtx::FANOUT_PORT_N];
    logic fanout_tx_p [FANOUT_CNT][gtx::FANOUT_PORT_N];

    logic evr_rx_n [EVR_CNT][gtx::EVR_PORT_N];
    logic evr_rx_p [EVR_CNT][gtx::EVR_PORT_N];
    logic evr_tx_n [EVR_CNT][gtx::EVR_PORT_N];
    logic evr_tx_p [EVR_CNT][gtx::EVR_PORT_N];

    EVG_board_emulator head_evg (
        .sfp_rx_n(evg_rx_n),
        .sfp_rx_p(evg_rx_p),
        .sfp_tx_n(evg_tx_n),
        .sfp_tx_p(evg_tx_p)
    );
    Fanout_board_emulator fanout_deep_0_port_0 (
        .sfp_rx_n(fanout_rx_n[0]),
        .sfp_rx_p(fanout_rx_p[0]),
        .sfp_tx_n(fanout_tx_n[0]),
        .sfp_tx_p(fanout_tx_p[0])
    );
    EVR_board_emulator evr_deep_0_port_1 (
        .sfp_rx_n(evr_rx_n[0]),
        .sfp_rx_p(evr_rx_p[0]),
        .sfp_tx_n(evr_tx_n[0]),
        .sfp_tx_p(evr_tx_p[0])
    );
    EVR_board_emulator evr_deep_1_port_0 (
        .sfp_rx_n(evr_rx_n[1]),
        .sfp_rx_p(evr_rx_p[1]),
        .sfp_tx_n(evr_tx_n[1]),
        .sfp_tx_p(evr_tx_p[1])
    );

    link_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY_DEEP_0_PORT_0)
    ) link_deep_0_port_0 (
        .up_rx_n(evg_rx_n[0]),
        .up_rx_p(evg_rx_p[0]),
        .up_tx_n(evg_tx_n[0]),
        .up_tx_p(evg_tx_p[0]),
        .down_rx_n(fanout_rx_n[0][0]),
        .down_rx_p(fanout_rx_p[0][0]),
        .down_tx_n(fanout_tx_n[0][0]),
        .down_tx_p(fanout_tx_p[0][0])
    );
    link_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY_DEEP_0_PORT_1)
    ) link_deep_0_port_1 (
        .up_rx_n(evg_rx_n[1]),
        .up_rx_p(evg_rx_p[1]),
        .up_tx_n(evg_tx_n[1]),
        .up_tx_p(evg_tx_p[1]),
        .down_rx_n(evr_rx_n[0][0]),
        .down_rx_p(evr_rx_p[0][0]),
        .down_tx_n(evr_tx_n[0][0]),
        .down_tx_p(evr_tx_p[0][0])
    );
    link_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY_DEEP_1_PORT_0)
    ) link_deep_1_port_0 (
        .up_rx_n(fanout_rx_n[0][1]),
        .up_rx_p(fanout_rx_p[0][1]),
        .up_tx_n(fanout_tx_n[0][1]),
        .up_tx_p(fanout_tx_p[0][1]),
        .down_rx_n(evr_rx_n[1][0]),
        .down_rx_p(evr_rx_p[1][0]),
        .down_tx_n(evr_tx_n[1][0]),
        .down_tx_p(evr_tx_p[1][0])
    );

initial begin
    #500ms;
    $stop();
end
endmodule

module EVG_board_emulator(
    input  logic       sfp_rx_n[gtx::EVG_PORT_N],
    input  logic       sfp_rx_p[gtx::EVG_PORT_N],
    output logic       sfp_tx_n[gtx::EVG_PORT_N],
    output logic       sfp_tx_p[gtx::EVG_PORT_N]
);
    localparam REFCLK_OFFSET = 0;
    logic     sysclk;
    logic     REFCLK_SFP;
    sys_clk_gen
    #(
        .halfcycle (2500), // 2500 ps = 200 MHz on board system clock
        .offset    (0)
    ) CLK_GEN1 (
        .sys_clk (sysclk)
    );
    sys_clk_gen
    #(
        .halfcycle (4000), // 4000 ps = 125 MHz
        .offset    (REFCLK_OFFSET)
    ) REFCLK_SFP_gen1 (
        .sys_clk (REFCLK_SFP)
    );

    topEVG DUT_EVG(
        .sysclk_n(~sysclk),
        .sysclk_p(sysclk),
        .REFCLK_SFP_n(~REFCLK_SFP),
        .REFCLK_SFP_p(REFCLK_SFP),

        .sfp_rx_n(sfp_rx_n),
        .sfp_rx_p(sfp_rx_p),
        .sfp_tx_n(sfp_tx_n),
        .sfp_tx_p(sfp_tx_p)
    );
endmodule

module Fanout_board_emulator(
    input  logic       sfp_rx_n[gtx::FANOUT_PORT_N],
    input  logic       sfp_rx_p[gtx::FANOUT_PORT_N],
    output logic       sfp_tx_n[gtx::FANOUT_PORT_N],
    output logic       sfp_tx_p[gtx::FANOUT_PORT_N]
);
    localparam REFCLK_OFFSET = 0;
    logic     sysclk;
    logic     REFCLK_SFP;
    logic     RXCLK;
    sys_clk_gen
    #(
        .halfcycle (2500), // 2500 ps = 200 MHz on board system clock
        .offset    (0)
    ) CLK_GEN1 (
        .sys_clk (sysclk)
    );
    sys_clk_gen
    #(
        .halfcycle (4000), // 4000 ps = 125 MHz
        .offset    (REFCLK_OFFSET)
    ) REFCLK_SFP_gen1 (
        .sys_clk (REFCLK_SFP)
    );

    topFanout DUT_FANOUT(
        .sysclk_n(~sysclk),
        .sysclk_p(sysclk),
        .REFCLK_SFP_n(~REFCLK_SFP),
        .REFCLK_SFP_p(REFCLK_SFP),
        .RXCLK_p(RXCLK),
        .REFCLK_FROM_RX_n(~RXCLK),
        .REFCLK_FROM_RX_p(RXCLK),

        .sfp_rx_n(sfp_rx_n),
        .sfp_rx_p(sfp_rx_p),
        .sfp_tx_n(sfp_tx_n),
        .sfp_tx_p(sfp_tx_p)
    );
endmodule


module EVR_board_emulator(
    input  logic       sfp_rx_n[gtx::EVR_PORT_N],
    input  logic       sfp_rx_p[gtx::EVR_PORT_N],
    output logic       sfp_tx_n[gtx::EVR_PORT_N],
    output logic       sfp_tx_p[gtx::EVR_PORT_N],
    inout  logic       START[EVR_board_pkg::START_N]
);
    import EVR_board_pkg::START_N;
    import EVR_board_pkg::START_POLARITY;
    import EVR_board_pkg::polarity_t;
    import EVR_board_pkg::POSITIVE;
    import EVR_board_pkg::NEGATIVE;
    
    localparam REFCLK_OFFSET = 0;
    logic      REFCLK_SFP;
    sys_clk_gen
    #(
        .halfcycle (4000), // 4000 ps = 125 MHz
        .offset    (REFCLK_OFFSET)
    ) REFCLK_SFP_gen1 (
        .sys_clk (REFCLK_SFP)
    );
    logic     SYS_CLK;
    sys_clk_gen
    #(
        .halfcycle (2500), // 2500 ps = 200 MHz on board system clock
        .offset    (0)
    ) CLK_GEN1 (
        .sys_clk (SYS_CLK)
    );

    wire START_p[START_N];
    wire START_n[START_N];

    topEVR DUT_EVR(
        .REFCLK_SFP_n(~REFCLK_SFP),
        .REFCLK_SFP_p(REFCLK_SFP),

        .SYS_CLK_n(~SYS_CLK),
        .SYS_CLK_p(SYS_CLK),

        .SFP_RX_N(sfp_rx_n),
        .SFP_RX_P(sfp_rx_p),
        .SFP_TX_N(sfp_tx_p),
        .SFP_TX_P(sfp_tx_n),
        .START_p(START_p),
        .START_n(START_n)
    );

    genvar START_i;
    generate
        for(START_i = 0; START_i < START_N; START_i ++) begin
            assign START[START_i] = START_POLARITY[START_i] == POSITIVE ? START_p[START_i] : START_n[START_i];
        end
    endgenerate
endmodule