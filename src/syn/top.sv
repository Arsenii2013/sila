`timescale 1ns/1ns

`include "axi4_lite_if.svh"
`include "top.svh"

module top(
    input  logic       sysclk_n,
    input  logic       sysclk_p,
    output logic [3:0] led
);
    logic sysclk;
    IBUFDS sysclk_ibuf_i (.O(sysclk), .I(sysclk_p), .IB(sysclk_n));

    blink #(
        .FREQ_HZ(200000000),
        .LED_PERIOD_NS(500000000)
    ) blink1 (
        .reset(0),
        .clk(sysclk),
        .led(led[0])
    );
    blink #(
        .FREQ_HZ(200000000),
        .LED_PERIOD_NS(1000000000)
    ) blink2 (
        .reset(0),
        .clk(sysclk),
        .led(led[1])
    );
    blink #(
        .FREQ_HZ(200000000),
        .LED_PERIOD_NS(1500000000)
    ) blink3 (
        .reset(0),
        .clk(sysclk),
        .led(led[2])
    );
    blink #(
        .FREQ_HZ(200000000),
        .LED_PERIOD_NS(2000000000)
    ) blink4 (
        .reset(0),
        .clk(sysclk),
        .led(led[3])
    );

endmodule
