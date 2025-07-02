`timescale 1ns/1ns

module event_generator(
    input  logic        clk,
    input  logic        rst,
    output logic [23:0] ev
);
    logic [15:0] cnt = '0;

    always_ff @(posedge clk) begin
        if(rst) begin
            cnt <= '0;
        end else begin
            cnt <= cnt + 1;
        end
    end

    assign ev = cnt == 0 ? 'hBEEF : 0;
endmodule