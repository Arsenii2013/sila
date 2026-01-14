`timescale 1ns/1ps

module fifo_wrapper 
#(
    parameter DEPTH = 1024
)
(
    input  logic         app_rst,
    input  logic         app_clk,
    input  logic         rx_clk,

    input  logic [32: 0] data_in,
    output logic [32: 0] data_out,
    input  logic [ 3: 0] isk_in,
    output logic [ 3: 0] isk_out,


    input  logic         fifo_inc,
    input  logic         fifo_dec,

    output logic         rst_busy
);
    import evn::*;

    logic wr_rst;
    xpm_cdc_async_rst _reset_cdc_i(
        .dest_clk(rx_clk),
        .dest_arst(wr_rst),
        .src_arst(app_rst)
    );

    logic rd_rst_busy, wr_rst_busy;
    logic almost_empty, almost_full;
    logic fifo_inc_sync, fifo_dec_sync;

    xpm_cdc_pulse fifo_dec_sunchronizer_i(
        .dest_clk(rx_clk),
        .dest_pulse(fifo_dec_sync),
        .dest_rst(wr_rst),
        .src_clk(app_clk),
        .src_pulse(fifo_dec),
        .src_rst(app_rst)
    );

    assign fifo_inc_sync = fifo_inc;

    logic rd_rst_busy_app_clk;
    xpm_cdc_async_rst rd_rst_busy_cdc_i(
        .dest_clk(app_clk),
        .dest_arst(rd_rst_busy_app_clk),
        .src_arst(rd_rst_busy)
    );
    logic wr_rst_busy_app_clk;
    xpm_cdc_async_rst wr_rst_busy_cdc_i(
        .dest_clk(app_clk),
        .dest_arst(wr_rst_busy_app_clk),
        .src_arst(wr_rst_busy)
    );
    assign rst_busy = rd_rst_busy_app_clk || wr_rst_busy_app_clk;

    logic rd_dis;
    assign rd_dis = rd_rst_busy || almost_empty;
    logic wr_dis;
    assign wr_dis = wr_rst_busy || almost_full;

    logic rd_dis_by_dec;
    assign rd_dis_by_dec = fifo_inc_sync && !is_beacon(data_out, isk_out);
    logic wr_dis_by_inc;
    assign wr_dis_by_inc = fifo_dec_sync && !is_beacon(data_in, isk_in);

    xpm_fifo_async #(
        .CASCADE_HEIGHT(0),
        .CDC_SYNC_STAGES(2),
        .DOUT_RESET_VALUE("0"),
        .FIFO_MEMORY_TYPE("block"),
        .FIFO_READ_LATENCY(1),
        .FIFO_WRITE_DEPTH(DEPTH),
        .READ_DATA_WIDTH(36),
        .READ_MODE("std"),
        .RELATED_CLOCKS(0),
        .SIM_ASSERT_CHK(1),
        .USE_ADV_FEATURES("0F0F"),
        .WRITE_DATA_WIDTH(36)
    ) xpm_fifo_async_inst (
        .rd_clk(app_clk),
        .rd_en(!rd_dis && !rd_dis_by_dec),
        .dout({data_out, isk_out}),

        .wr_clk(rx_clk),
        .wr_en(!wr_dis && !wr_dis_by_inc),
        .din({data_in, isk_in}),

        .almost_empty(almost_empty),
        .almost_full(almost_full),
        .rst(wr_rst),
        .rd_rst_busy(rd_rst_busy),
        .wr_rst_busy(wr_rst_busy)
    );
endmodule
