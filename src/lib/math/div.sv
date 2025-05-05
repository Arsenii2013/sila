`ifndef __DIV_SV__
`define __DIV_SV__

module div_m #(
    parameter DW = 32
)
(
    input  logic          clk,
    input  logic          rst,
    
    input  logic          start,
    output logic          ready,

    input  logic [DW-1:0] n,
    input  logic [DW-1:0] d,
    output logic [DW-1:0] q,
    output logic [DW-1:0] r
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Types
//
typedef logic [        DW-1:0] data_t;
typedef logic [$clog2(DW)-1:0] cnt_t;

typedef enum {
    IDLE,
    COUNT
} state_t;

//------------------------------------------------
//
//      Objects
//
cnt_t   cnt = '0;
state_t state = IDLE;

data_t  d_reg;
data_t  n_hi = '0;
data_t  n_lo = '0;

data_t  q_reg = '0;
data_t  r_reg = '0;

//------------------------------------------------
//
//      Logic
//
assign q = q_reg;
assign r = r_reg;

assign ready = state == IDLE;

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        cnt   <= '0;
    end
    else begin
        case (state)
            IDLE: begin
                cnt   <= '0;
                n_hi  <= n[DW-1];
                n_lo  <= {n[DW-2:0], 1'b0};
                d_reg <= d;
                if (start) state <= COUNT;
            end
            COUNT: begin
                automatic logic  res = (n_hi >= d_reg);
                automatic data_t tmp_hi = res ? (n_hi - d_reg) : n_hi;
                automatic data_t tmp_lo = n_lo;
                
                n_hi  <= {tmp_hi[DW-2:0], tmp_lo[DW-1]};
                n_lo  <= {tmp_lo[DW-2:0], 1'b0};
                q_reg <= {q_reg[DW-2:0], res};
                
                cnt <= cnt + cnt_t'(1);
                if (cnt == cnt_t'(DW-1)) begin
                    state <= IDLE;
                    r_reg <= tmp_hi;
                end
            end
        endcase
    end
end

//------------------------------------------------
endmodule : div_m

`endif//__DIV_SV__