module ODDRDS(
    input  logic C,
    output logic O,
    output logic OB
);
    logic ODDR_out;
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) rx_clk_ODDR_inst (
        .Q(ODDR_out),
        .C(C),
        .CE(1),
        .D1(0),
        .D2(1),
        .R(0),
        .S(0)
    );
    OBUFDS rx_clk_OBUFDS_inst (
        .I(ODDR_out),
        .O(O),
        .OB(OB)
    );
endmodule