
module stable_m #(
    parameter LEN = 31
)(
    input  logic clk,

    input  logic in,
    output logic out
);
    typedef logic [$clog2(LEN) - 1: 0] cnt_t;

    cnt_t cnt = LEN;
    always_ff @(posedge clk) begin
        if(in && cnt != '0) begin
            cnt <= cnt - 1;
        end else if(!in) begin
            cnt <= LEN;
        end
    end

    assign out = cnt == 0;
endmodule