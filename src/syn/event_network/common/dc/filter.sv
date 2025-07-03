
//------------------------------------------------
//
//      First order exponential FIR described by eq:
//      Yn = Yn-1 - Yn-1/T + Xn/T , where 
//      1. T is defined as 2^N for this module
//      2. Optimal N for f = 175 MHz, delta_f = 30 kHz, 
//         beacon_psc = 2**10, is 12
//------------------------------------------------
module filter #(
    parameter INT_W  = 16,
    parameter FRAC_W = 16,
    parameter N      = 12
)
(
    input  logic                     clk,
    input  logic                     rst,

    input  logic [INT_W+FRAC_W-1: 0] in,
    input  logic                     in_upd,
    output logic [INT_W+FRAC_W-1: 0] out,
    output logic                     out_upd
);

//------------------------------------------------
localparam ACC_W = INT_W + FRAC_W;

//------------------------------------------------
typedef logic [ACC_W -1: 0] acc_t;

//------------------------------------------------
acc_t acc = '0;
acc_t fdb;
acc_t sample;

assign out    = acc;

//------------------------------------------------
assign fdb    = acc >> N;
assign sample = in  >> N;

always_ff @(posedge clk) begin
    if (rst) begin
        acc <= '0;
    end
    else begin
        if (in_upd) begin
            acc     <= acc - fdb + sample;
            out_upd <= 1;
        end else begin
            out_upd <= 0;
        end
    end
end
endmodule 