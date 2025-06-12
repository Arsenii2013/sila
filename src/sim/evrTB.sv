`timescale 1ns/1ns
`include "top.svh"
`include "evn.svh"

module evrTB(

    );

    logic     sfp_tx_clk;
    logic     sfp_rx_clk;
    logic     app_clk;
    logic     app_rst;
    logic     beacon_clk;

    axi4_lite_if #(.AW(GP0_ADDR_W), .DW(GP0_DATA_W)) mmr();

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

    int trig_cnt = 0;
    logic [23:0] trig;
    always_ff @(posedge app_clk) begin
        if(trig_cnt == 0) begin
            trig     <= 'h123456;
            trig_cnt <= 4;
        end else begin
            trig     <= '0;
            trig_cnt <= trig_cnt - 1;
        end
    end

    logic         tx_resetdone = 0;
    logic [31: 0] tx_data;
    logic [ 3: 0] tx_charisk;
    logic         rx_resetdone = 0;
    logic [31: 0] rx_data = 0;
    logic [ 3: 0] rx_charisk = 0;


    int rx_data_cnt = 0;
    always_ff @(posedge sfp_rx_clk) begin
        if(rx_data_cnt == 0) begin
            rx_data     <= ALIGNMENT_WORD;
            rx_charisk  <= ALIGNMENT_IS_K;
            rx_data_cnt <= 4;
        end else if(rx_data_cnt == 1) begin
            rx_data     <= BEACON_WORD;
            rx_charisk  <= BEACON_IS_K;
            rx_data_cnt <= rx_data_cnt - 1;
        end else if(rx_data_cnt == 2) begin
            rx_data     <= {EVENT_COMMA, 24'h123456};
            rx_charisk  <= 'h8;
            rx_data_cnt <= rx_data_cnt - 1;
        end else begin
            rx_data     <= '0;
            rx_charisk  <= '0;
            rx_data_cnt <= rx_data_cnt - 1;
        end
    end

    evr DUT(
        .beacon_clk(beacon_clk),

        //------GTP signals-------
        .aligned(~app_rst),

        .tx_resetdone(~app_rst),
        .tx_clk(sfp_tx_clk),
        .tx_data(tx_data),
        .tx_charisk(tx_charisk),

        .rx_resetdone(~app_rst),
        .rx_clk(sfp_rx_clk),
        .rx_data(rx_data),
        .rx_charisk(rx_charisk),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        
        .ev(), 
        .trig(trig),
        .in_packet(in_packet),
        .out_packet(out_packet)
    );

    initial begin
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk)
        app_rst <= 0;

        #100us;
        $stop();
    end

endmodule
