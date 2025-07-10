`timescale 1ns/1ns

module event_generator(
    input  logic        clk,
    input  logic        rst,
    output logic [23:0] ev
);
    localparam CNT_W = 12;
    logic [CNT_W-1:0] cnt = '0;

    always_ff @(posedge clk) begin
        if(rst) begin
            cnt <= '0;
        end else begin
            cnt <= cnt + 1;
        end
    end
    assign ev = cnt[CNT_W-3:0] == '0 ? cnt[CNT_W-1 -: 2] + 1 : 0;
endmodule