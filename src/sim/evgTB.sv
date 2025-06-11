`timescale 1ns/1ns
`include "top.svh"

module evgTB(

    );

    logic     sfp_tx_clk;
    logic     app_clk;
    logic     app_rst;

    axi_stream_if #(.DW(32)) in_packet();
    axi_stream_if #(.DW(32)) out_packet();

    sys_clk_gen
    #(
        .halfcycle (4000), // 5000 ps = 125 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (sfp_tx_clk)
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

    evg DUT(
        .beacon_clk(0),

        //------GTP signals-------
        .aligned(0),

        .tx_resetdone(1),
        .tx_clk(sfp_tx_clk),
        .tx_data(),
        .tx_charisk(),

        .rx_resetdone(0),
        .rx_clk(0),
        .rx_data(0),
        .rx_charisk(0),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_rst),
        
        .ev(ev), 
        .trig(),
        .in_packet(in_packet),
        .out_packet(out_packet)
    );

    initial begin
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk)
        app_rst <= 0;
    end

endmodule