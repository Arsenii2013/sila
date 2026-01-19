`timescale 1ns/1ps
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
    localparam HSSR_CNT = 2;

    semaphore display_key = new(1);

    logic evg_rx_n [gtx::HSSM_PORT_N];
    logic evg_rx_p [gtx::HSSM_PORT_N];
    logic evg_tx_n [gtx::HSSM_PORT_N];
    logic evg_tx_p [gtx::HSSM_PORT_N];

    logic fanout_rx_n [FANOUT_CNT][gtx::FANOUT_PORT_N];
    logic fanout_rx_p [FANOUT_CNT][gtx::FANOUT_PORT_N];
    logic fanout_tx_n [FANOUT_CNT][gtx::FANOUT_PORT_N];
    logic fanout_tx_p [FANOUT_CNT][gtx::FANOUT_PORT_N];

    logic evr_rx_n [HSSR_CNT][gtx::HSSR_PORT_N];
    logic evr_rx_p [HSSR_CNT][gtx::HSSR_PORT_N];
    logic evr_tx_n [HSSR_CNT][gtx::HSSR_PORT_N];
    logic evr_tx_p [HSSR_CNT][gtx::HSSR_PORT_N];

    HSSM_board_emulator head_evg (
        .sfp_rx_n(evg_rx_n),
        .sfp_rx_p(evg_rx_p),
        .sfp_tx_n(evg_tx_n),
        .sfp_tx_p(evg_tx_p)
    );
    /*Fanout_board_emulator fanout_deep_0_port_0 (
        .sfp_rx_n(fanout_rx_n[0]),
        .sfp_rx_p(fanout_rx_p[0]),
        .sfp_tx_n(fanout_tx_n[0]),
        .sfp_tx_p(fanout_tx_p[0])
    );*/
    HSSR_board_emulator evr_deep_0_port_1 (
        .sfp_rx_n(evr_rx_n[0]),
        .sfp_rx_p(evr_rx_p[0]),
        .sfp_tx_n(evr_tx_n[0]),
        .sfp_tx_p(evr_tx_p[0])
    );
    HSSR_board_emulator evr_deep_1_port_0 (
        .sfp_rx_n(evr_rx_n[1]),
        .sfp_rx_p(evr_rx_p[1]),
        .sfp_tx_n(evr_tx_n[1]),
        .sfp_tx_p(evr_tx_p[1])
    );

    link_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY_DEEP_0_PORT_1)
    ) link_deep_0_port_0 (
        .up_rx_n(evg_rx_n[0]),
        .up_rx_p(evg_rx_p[0]),
        .up_tx_n(evg_tx_n[0]),
        .up_tx_p(evg_tx_p[0]),
        .down_rx_n(evr_rx_n[0][0]),
        .down_rx_p(evr_rx_p[0][0]),
        .down_tx_n(evr_tx_n[0][0]),
        .down_tx_p(evr_tx_p[0][0])
    );
    link_emulator #(
        .PROPAGATION_DELAY(PROPAGATION_DELAY_DEEP_0_PORT_1)
    ) link_deep_0_port_1 (
        .up_rx_n(evg_rx_n[1]),
        .up_rx_p(evg_rx_p[1]),
        .up_tx_n(evg_tx_n[1]),
        .up_tx_p(evg_tx_p[1]),
        .down_rx_n(evr_rx_n[1][0]),
        .down_rx_p(evr_rx_p[1][0]),
        .down_tx_n(evr_tx_n[1][0]),
        .down_tx_p(evr_tx_p[1][0])
    );
    /*link_emulator #(
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
    );*/

initial begin
    #500ms;
    $stop();
end
endmodule

module HSSM_board_emulator(
    input  logic       sfp_rx_n[gtx::HSSM_PORT_N],
    input  logic       sfp_rx_p[gtx::HSSM_PORT_N],
    output logic       sfp_tx_n[gtx::HSSM_PORT_N],
    output logic       sfp_tx_p[gtx::HSSM_PORT_N]
);
    localparam REFCLK_OFFSET = 0;

    logic     SYS_CLK;
    logic     REFCLK;
    logic     DM_CLK;
    sys_clk_gen #(
        .halfcycle (2500), // 2500 ps = 200 MHz on board system clock
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (SYS_CLK)
    );
    sys_clk_gen #(
        .halfcycle (2857), // 2857 ps = 125 MHz
        .offset    (REFCLK_OFFSET)
    ) REFCLK_gen (
        .sys_clk (REFCLK)
    );
    sys_clk_gen #(
        .halfcycle (2856), // 2857 ps = 125 MHz
        .offset    (0)
    ) DM_CLK_gen (
        .sys_clk (DM_CLK)
    );

    logic SFP_RX_LOSS[gtx::HSSM_PORT_N] = '{1, 1, 1, 1};
    generate
    for(genvar i = 0; i < gtx::HSSR_PORT_N; i ++) begin
        initial begin 
            repeat (5000) @(posedge sfp_rx_p[i]);
            SFP_RX_LOSS[i] <= 0;
        end
    end
    endgenerate

    logic PLL_LOL_N = 0;
    initial begin 
        repeat (5000) @(posedge REFCLK);
        PLL_LOL_N <= 1;
    end

    topHSSM DUT_HSSM(
        .SYS_CLK_n(~SYS_CLK),
        .SYS_CLK_p(SYS_CLK),
        .REFCLK_n(~REFCLK),
        .REFCLK_p(REFCLK),

        .SFP_RX_N(sfp_rx_p),
        .SFP_RX_P(sfp_rx_n),
        .SFP_TX_N(sfp_tx_n),
        .SFP_TX_P(sfp_tx_p),

        .SFP_RX_LOS(SFP_RX_LOSS),
        
        .DM_CLK_n(DM_CLK),
        .DM_CLK_p(~DM_CLK),

        .PLL_LOL_N(PLL_LOL_N)
    );
endmodule

/*
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
*/

module HSSR_board_emulator(
    input  logic       sfp_rx_n[gtx::HSSR_PORT_N],
    input  logic       sfp_rx_p[gtx::HSSR_PORT_N],
    output logic       sfp_tx_n[gtx::HSSR_PORT_N],
    output logic       sfp_tx_p[gtx::HSSR_PORT_N],
    inout  logic       START[HSSR_board_pkg::START_N]
);
    import HSSR_board_pkg::START_N;
    import HSSR_board_pkg::START_POLARITY;
    import HSSR_board_pkg::START_MODES;
    import HSSR_board_pkg::polarity_t;
    import HSSR_board_pkg::POSITIVE;
    import HSSR_board_pkg::NEGATIVE;

    // On SOM clock generators
    logic      REFCLK_SFP;
    logic      SYS_CLK;
    sys_clk_gen
    #(
        .halfcycle (2857), // 2857 ps = 125 MHz
        .offset    (0)
    ) REFCLK_SFP_gen (
        .sys_clk (REFCLK_SFP)
    );
    sys_clk_gen
    #(
        .halfcycle (2500), // 2500 ps = 200 MHz 
        .offset    (0)
    ) CLK_GEN1 (
        .sys_clk (SYS_CLK)
    );

    // MOU si570 si5344 si5342

    logic      MGTREFCLK;
    logic      DM_CLK;
    logic      DC_CLK;
    logic      FPGA_OUTCLK;
    logic      PLL1_LOL_N = 0;
    logic      PLL2_LOL_N = 0;
    // TODO simulate MGTREFCLK clock switch
    sys_clk_gen
    #(
        .halfcycle (2857), // 2857 ps = 125 MHz
        .offset    (0)
    ) MGTREFCLK_gen (
        .sys_clk (MGTREFCLK)
    );
    sys_clk_gen
    #(
        .halfcycle (2856), // 2857 ps = 125 MHz
        .offset    (0)
    ) DM_CLK_gen (
        .sys_clk (DM_CLK)
    );
    assign #1ns FPGA_OUTCLK = DC_CLK;
    initial begin 
        repeat (5000) @(posedge FPGA_OUTCLK);
        PLL1_LOL_N <= 1;
    end
    initial begin 
        repeat (5000) @(posedge MGTREFCLK);
        PLL2_LOL_N <= 1;
    end

    logic SFP_RX_LOSS[gtx::HSSR_PORT_N] = '{1};
    generate
    for(genvar i = 0; i < gtx::HSSR_PORT_N; i ++) begin
        initial begin 
            repeat (5000) @(posedge sfp_rx_p[i]);
            SFP_RX_LOSS[i] <= 0;
        end
    end
    endgenerate

    tri0 START_p[START_N];
    tri1 START_n[START_N];

    logic SER, SRCLK, RCLK;

    topHSSR DUT_HSSR(
        .REFCLK_SFP_n(~REFCLK_SFP),
        .REFCLK_SFP_p(REFCLK_SFP),
        .MGTREFCLK_n(~MGTREFCLK),
        .MGTREFCLK_p(MGTREFCLK),

        .SYS_CLK_n(~SYS_CLK),
        .SYS_CLK_p(SYS_CLK),

        .DM_CLK_n(~DM_CLK),
        .DM_CLK_p(DM_CLK),
        .DC_CLK_p(DC_CLK),

        .SFP_RX_N(sfp_rx_p),
        .SFP_RX_P(sfp_rx_n),
        .SFP_TX_N(sfp_tx_p),
        .SFP_TX_P(sfp_tx_n),
        .SFP_RX_LOS(SFP_RX_LOSS),
        .START_p(START_p),
        .START_n(START_n),
        .FPGA_OUTCLK_n(~FPGA_OUTCLK),
        .FPGA_OUTCLK_p(FPGA_OUTCLK),

        .PLL1_LOL_N(PLL1_LOL_N),
        .PLL2_LOL_N(PLL2_LOL_N),

        .SER(SER),
        .RCLK(RCLK),
        .SRCLK(SRCLK)
    );

    localparam int unsigned PRECISE_CNT   = 8;
    localparam int unsigned SN74HC595_CNT = PRECISE_CNT * diff_io_pkg::PRECISE_DELAY_ADJ_W / 8;

    logic [SN74HC595_CNT-1: 0][7: 0] sn74hc595_Q;
    logic [PRECISE_CNT  -1: 0][9: 0] mc100ep195B_D;
    assign mc100ep195B_D = sn74hc595_Q;

    logic SERS [SN74HC595_CNT];
    assign SERS[0] = SER;
    generate 
    for(genvar i = 0; i < SN74HC595_CNT; i ++) begin
        if(i != SN74HC595_CNT - 1) begin
            sn74hc595_emulator sn74hc595_emulator_inst(
                .Q(sn74hc595_Q[i]),
                .Q_H_backtick(SERS[i+1]),

                .SER(SERS[i]),
                .RCLK(RCLK),
                .SRCLK(SRCLK),
                .OE_N(0),
                .SRCLR_N(1)
            );
        end else begin
            sn74hc595_emulator sn74hc595_emulator_inst(
                .Q(sn74hc595_Q[i]),
                .SER(SERS[i]),
                .RCLK(RCLK),
                .SRCLK(SRCLK),
                .OE_N(0),
                .SRCLR_N(1)
            );
        end
    end
    endgenerate

    generate
    for(genvar i = 0; i < START_N; i ++) begin
        if(START_MODES[i] == diff_io_pkg::PRECISE) begin
            if(START_POLARITY[i] == diff_io_pkg::POSITIVE) begin
                mc100ep195b_emulator mc100ep195b_emulator_inst(
                    .D(mc100ep195B_D[i]),
                    .IN(START_p[i]),
                    .Q(START[i])
                );
            end else begin
                mc100ep195b_emulator mc100ep195b_emulator_inst(
                    .D(mc100ep195B_D[i]),
                    .IN(START_n[i]),
                    .Q(START[i])
                );
            end
        end else begin
            if(START_POLARITY[i] == diff_io_pkg::POSITIVE) begin
                assign START[i] = START_p[i];
            end else begin
                assign START[i] = START_n[i];
            end
        end

    end
    endgenerate

endmodule