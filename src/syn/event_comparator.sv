`timescale 1ns/1ns

module event_comparator(
    input  logic        clk,
    input  logic        rst,
    input  logic [23:0] ev,
    output logic        pulse
);
    pf_m pf_i (
        .clk(clk),
        .in(ev == 'hBEEF),
        .out(pulse)
    );
endmodule