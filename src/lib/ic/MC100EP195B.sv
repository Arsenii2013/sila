
module mc100ep195b_emulator(
    input  tri0  [9: 0] D,
    input  tri0         IN,
    input  tri0         LEN,
    input  tri0         SETMIN,
    input  tri0         SETMAX,
    output logic        CASCADE,
    input  tri0         EN_N,
    output logic        Q
);
    always @(LEN or SETMIN or SETMAX or EN_N) begin
        assert (LEN == 0 && SETMIN == 0 && SETMAX == 0 && EN_N == 0) 
        else begin
            $error("mc100ep195b_emulator implies only transparent mode");
        end
    end

    assign  #(D * 10ps + 2.2ns) Q = IN;
endmodule


