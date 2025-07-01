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

    output logic         full,
    output logic         empty
);
    xpm_fifo_async #(
        .CASCADE_HEIGHT(0),
        .CDC_SYNC_STAGES(2),
        .DOUT_RESET_VALUE("0"),
        .FIFO_MEMORY_TYPE("block"),
        .FIFO_READ_LATENCY(1),
        .FIFO_WRITE_DEPTH(2**16),
        .READ_DATA_WIDTH(36),
        .READ_MODE("std"),
        .RELATED_CLOCKS(0),
        .SIM_ASSERT_CHK(1),
        .USE_ADV_FEATURES("0000"),
        .WRITE_DATA_WIDTH(36)
    ) xpm_fifo_async_inst (
        .rd_clk(app_clk),
        .rd_en(!fifo_inc),
        .dout({data_out, isk_out}),

        .wr_clk(rx_clk),
        .wr_en(!fifo_dec),
        .din({data_in, isk_in}),

        .empty(empty),
        .full(full),
        .rst(app_rst)
    );
endmodule
