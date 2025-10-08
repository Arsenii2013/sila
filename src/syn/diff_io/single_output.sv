
module single_output #(
    parameter diff_io_pkg::odelay_taps_t    STATIC_ODELAY_TAPS = 0, 
    // задержка в ODELAY, в точных каналах = 0, 
    // в обычных для уравнивания с точными ~= 2.2 нс.
    // При IDELAYCTRL REFCLK = 200 МГц один тап = 78 пс.
    // Тогда задержка либо 28 тапов = 2.18 нс, либо 29 = 2.26 нс
    parameter string                        ODELAY_GROUP = "",
    parameter diff_io_pkg::polarity_t       STATIC_POLARITY = diff_io_pkg::POSITIVE
)(
    input  diff_io_pkg::mode_t       mode,
    input  diff_io_pkg::polarity_t   polarity,

    input  logic                    o1,
    input  logic                    o2,
    output logic                    i,

    input  logic                    app_clk,
    input  logic                    clear_clk,
    input  logic                    app_rst,

    inout  logic                    IO_P,
    inout  logic                    IO_N
);
    import diff_io_pkg::*;

    logic DDR_Q;
    logic ODELAY_DATAOUT;
    logic tri_val;
    assign tri_val = mode == TRI;

    logic ddr_posedge_val;
    logic ddr_negedge_val;

    IOBUFDS IOBUFDS_inst (
        .O(i),
        .I(ODELAY_DATAOUT),
        .IO(IO_P),
        .IOB(IO_N),
        .T(tri_val)
    );

    (* IODELAY_GROUP = ODELAY_GROUP *)
    ODELAYE2 #(
        .CINVCTRL_SEL("FALSE"),
        .DELAY_SRC("ODATAIN"),
        .HIGH_PERFORMANCE_MODE("TRUE"),
        .ODELAY_TYPE("FIXED"),
        .ODELAY_VALUE(STATIC_ODELAY_TAPS),
        .PIPE_SEL("FALSE"),
        .REFCLK_FREQUENCY(200.0),
        .SIGNAL_PATTERN("DATA")
    ) ODELAYE2_inst (
        .CNTVALUEOUT(),
        .DATAOUT(ODELAY_DATAOUT),
        .C(clear_clk),
        .CE(0),
        .CINVCTRL(0),
        .CLKIN(0),
        .CNTVALUEIN('0),
        .INC(0),
        .LD(0),
        .LDPIPEEN(0),
        .ODATAIN(DDR_Q),
        .REGRST(app_rst)
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) ODDR_inst (
        .Q(DDR_Q),
        .C(clear_clk),
        .CE(!tri_val),
        .D1(ddr_posedge_val),
        .D2(ddr_negedge_val),
        .R(0),
        .S(0)
    );

    logic gated_val, flip_floped_val;

    assign gated_val = o1 && o2;
    always_ff @(posedge app_clk) begin
        if(o2 || app_rst) begin
            flip_floped_val <= 0;
        end else if(o1) begin
            flip_floped_val <= 1;
        end
    end

    logic ddr_posedge_no_polarity;
    logic ddr_negedge_no_polarity;

    assign ddr_posedge_val = combine_polarity(polarity, STATIC_POLARITY) == POSITIVE ? 
                                ddr_posedge_no_polarity : !ddr_posedge_no_polarity;

    assign ddr_negedge_val = combine_polarity(polarity, STATIC_POLARITY) == POSITIVE ? 
                                ddr_negedge_no_polarity : !ddr_negedge_no_polarity;

    always_comb begin
        case (mode)
            FORCE_SET : begin
                ddr_posedge_no_polarity = 1;
                ddr_negedge_no_polarity = 1;
            end
            GENERATOR : begin
                ddr_posedge_no_polarity = o1;
                ddr_negedge_no_polarity = o1;
            end
            GATE : begin
                ddr_posedge_no_polarity = gated_val;
                ddr_negedge_no_polarity = gated_val;
            end
            FLIP_FLOP : begin
                ddr_posedge_no_polarity = flip_floped_val;
                ddr_negedge_no_polarity = flip_floped_val;
            end
            CLK : begin
                ddr_posedge_no_polarity = 0;
                ddr_negedge_no_polarity = 1;
            end
            default: begin
                ddr_posedge_no_polarity = 0;
                ddr_negedge_no_polarity = 0;
            end
        endcase
    end
endmodule
