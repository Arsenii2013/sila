`timescale 1ns/1ns
/*
This modile is porpused for:
    generating traffic for four transcievers
*/
module frame_gen(
    input  logic clk,
    input  logic rst,
    output logic [31:0] tx_data,
    output logic [3:0]  txcharisk,
    input  logic [31:0] data
);
    logic [1:0] cnt = '0;

    always_ff @(posedge clk) begin
        if(rst) begin
            cnt <= '0;
        end else begin
            cnt <= cnt + 1;
        end
    end

    always_comb begin
        if(cnt == 0) begin
            tx_data   = 'hBC;
            txcharisk = 1;
        end else begin
            tx_data   = data;
            txcharisk = 0;
        end
    end

endmodule