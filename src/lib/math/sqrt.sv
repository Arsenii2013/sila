`ifndef __SQRT_SV__
`define __SQRT_SV__

module sqrt_m
#(
    parameter DW = 32
)
(
    input  logic            clk,
    input  logic            rst,

    input  logic            start,
    output logic            ready,

    input  logic [  DW-1:0] r,
    output logic [DW/2-1:0] q
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Types
//
typedef logic [DW-1:0] data_t;

typedef enum {
    IDLE,
    COUNT
} state_t;

//------------------------------------------------
//
//      Objects
//
state_t state = IDLE;
data_t  m     = data_t'(1) << DW-2;
data_t  x;
data_t  y;

//------------------------------------------------
//
//      Logic
//
assign ready = state == IDLE;
assign q     = y[DW/2-1:0];

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
    end
    else begin
        case (state)
            IDLE: begin
                if (start) begin
                    x     <= r;
                    y     <= '0;
                    m     <= data_t'(1) << DW-2;    
                    state <= COUNT;
                end
            end
            COUNT: begin
                if (m != '0) begin
                    automatic data_t b = y | m;
                    y <= (y >> 1);
                    if (x >= b) begin
                        x <= x - b;
                        y <= (y >> 1) | m;
                    end
                    m <= m >> 2;
                end
                else begin
                    state <= IDLE;
                end
            end
        endcase
    end
end

//------------------------------------------------
endmodule : sqrt_m

`endif//__SQRT_SV__