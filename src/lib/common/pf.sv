`ifndef __PF_SV__
`define __PF_SV__

module pf_m
#(
    parameter WIDTH = 4,
    parameter POR   = "ON"
)
(
    input  logic clk,
    input  logic in,
    output logic out
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Types
//
typedef logic [$clog2(WIDTH):0] cnt_t;

//------------------------------------------------
//
//      Objects
//
cnt_t cnt = POR == "ON" ? cnt_t'(WIDTH) : '0;

logic in_r;

//------------------------------------------------
//
//      Logic
//
assign out = cnt != '0;

always_ff @(posedge clk) begin
    in_r <= in;
    if (in & ~in_r)
        cnt <= cnt_t'(WIDTH);
    else if (cnt)
        cnt <= cnt_t'(cnt - 1);
end

//------------------------------------------------
endmodule : pf_m

`endif//__PF_SV__