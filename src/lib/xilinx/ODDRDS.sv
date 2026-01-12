module ODDRDS #(
    parameter string POL = "P"
)(
    input  logic C,
    output logic O,
    output logic OB
);
    logic ODDR_out;
    generate
    if(POL == "P") begin
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
    end else if(POL == "N") begin
        ODDR #(
            .DDR_CLK_EDGE("SAME_EDGE"),
            .INIT(1'b0),
            .SRTYPE("SYNC")
        ) rx_clk_ODDR_inst (
            .Q(ODDR_out),
            .C(C),
            .CE(1),
            .D1(1),
            .D2(0),
            .R(0),
            .S(0)
        );
    end else begin
        $error("Unknown paraneter value");
    end
    endgenerate
    OBUFDS rx_clk_OBUFDS_inst (
        .I(ODDR_out),
        .O(O),
        .OB(OB)
    );

endmodule