

module single_outputTB();
    import diff_io_pkg::*;

    localparam TEST_GROUP = "TEST_GROUP";

    logic app_clk;
    logic idelayctrl_refclk;
    logic clear_clk;
    logic app_rst;

    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) APP_CLK_GEN (
        .sys_clk (app_clk)
    );
    sys_clk_gen
    #(
        .halfcycle (2500), // 5000 ps = 200 MHz
        .offset    (0)
    ) REFCLK_GEN (
        .sys_clk (idelayctrl_refclk)
    );

    assign clear_clk = app_clk;

    logic o1;
    logic o2;
    logic i;
    logic i_max_tap;
    logic i_negative;

    mode_t mode;
    polarity_t polarity;

    wire IO_P;
    wire IO_N;

    wire IO_P_max_tap;
    wire IO_N_max_tap;

    wire IO_P_negative;
    wire IO_N_negative;

    (* IODELAY_GROUP = TEST_GROUP *) 

    IDELAYCTRL IDELAYCTRL_inst (
        .RDY(),
        .REFCLK(idelayctrl_refclk),
        .RST(app_rst)
    );

    single_output #(
        .STATIC_ODELAY_TAPS(0),
        .ODELAY_GROUP(TEST_GROUP)
    ) DUT (
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_rst),

        .o1(o1),
        .o2(o2),
        .i(i),
        .mode(mode),
        .polarity(polarity),
        .IO_P(IO_P),
        .IO_N(IO_N)
    );

    single_output #(
        .STATIC_ODELAY_TAPS(31),
        .ODELAY_GROUP(TEST_GROUP)
    ) DUT_MAX_TAP (
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_rst),

        .o1(o1),
        .o2(o2),
        .i(i_max_tap),
        .mode(mode),
        .polarity(polarity),
        .IO_P(IO_P_max_tap),
        .IO_N(IO_N_max_tap)
    );

    single_output #(
        .STATIC_ODELAY_TAPS(0),
        .ODELAY_GROUP(TEST_GROUP),
        .STATIC_POLARITY(NEGATIVE)
    ) DUT_NEGATIVE (
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_rst),

        .o1(o1),
        .o2(o2),
        .i(i_negative),
        .mode(mode),
        .polarity(polarity),
        .IO_P(IO_P_negative),
        .IO_N(IO_N_negative)
    );

    single_output_monitor #(
        .STATIC_DELAY_PS(0ps)
    ) monitor (
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_rst),

        .o1(o1),
        .o2(o2),
        .i(i),
        .mode(mode),
        .polarity(polarity),
        .IO_P(IO_P),
        .IO_N(IO_N)
    );

    single_output_monitor  #(
        .STATIC_DELAY_PS(2418ps)
    ) monitor_max_tap(
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_rst),

        .o1(o1),
        .o2(o2),
        .i(i_max_tap),
        .mode(mode),
        .polarity(polarity),
        .IO_P(IO_P_max_tap),
        .IO_N(IO_N_max_tap)
    );

    single_output_monitor  #(
        .STATIC_DELAY_PS(0ps),
        .STATIC_POLARITY(NEGATIVE)
    ) monitor_negative(
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_rst),

        .o1(o1),
        .o2(o2),
        .i(i_negative),
        .mode(mode),
        .polarity(polarity),
        .IO_P(IO_P_negative),
        .IO_N(IO_N_negative)
    );

    initial begin
        mode <= TRI;
        polarity <= POSITIVE;
        reset();
        test_mode(TRI);
        test_mode(FORCE_CLEAR);
        test_mode(FORCE_SET);
        test_mode(GENERATOR);
        test_mode(GATE);
        test_mode(FLIP_FLOP);
        test_mode(CLK);
        $stop();
    end

    task reset();
        app_rst <= 1;
        repeat (10) @(posedge app_clk);
        app_rst <= 0;
    endtask

    task iterate_o1_o2();
        @(posedge app_clk);
        o1 <= 0;
        o2 <= 0;
        repeat (10) @(posedge app_clk);
        o1 <= 1;
        o2 <= 0;
        repeat (10) @(posedge app_clk);
        o1 <= 0;
        o2 <= 1;
        repeat (10) @(posedge app_clk);
        o1 <= 1;
        o2 <= 1;
        repeat (10) @(posedge app_clk);
        o1 <= 0;
        o2 <= 0;
        repeat (10) @(posedge app_clk);
    endtask

    task test_mode(mode_t _mode);
        mode     <= _mode;
        polarity <= POSITIVE;
        iterate_o1_o2();
        polarity <= NEGATIVE;
        iterate_o1_o2();
    endtask

endmodule

module single_output_monitor #(
    parameter realtime                STATIC_DELAY_PS = 0ps,
    parameter diff_io_pkg::polarity_t STATIC_POLARITY = diff_io_pkg::POSITIVE
)(
    input  diff_io_pkg::mode_t       mode,
    input  diff_io_pkg::polarity_t   polarity,

    input  logic                    o1,
    input  logic                    o2,
    input  logic                    i,

    input  logic                    app_clk,
    input  logic                    clear_clk,
    input  logic                    app_rst,

    input  logic                    IO_P,
    input  logic                    IO_N
);
    import diff_io_pkg::*;

    logic IO_P_comp, IO_N_comp, i_comp;
    single_output_golden_model #(
        .STATIC_DELAY_PS(STATIC_DELAY_PS),
        .STATIC_POLARITY(STATIC_POLARITY)
    ) model (
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_rst),

        .o1(o1),
        .o2(o2),
        .i(i_comp),
        .mode(mode),
        .polarity(polarity),
        .IO_P(IO_P_comp),
        .IO_N(IO_N_comp)
    );

    //assert property (@(mode) !$isunknown(mode));
    //assert property (@(polarity) !$isunknown(polarity));

    logic mode_stable;
    mode_t mode_reg0, mode_reg1, mode_reg2;

    assign mode_stable = (mode      == mode_reg0) && 
                         (mode_reg0 == mode_reg1) && 
                         (mode_reg1 == mode_reg2);

    always_ff @(posedge app_clk) begin
        mode_reg0 <= mode;
        mode_reg1 <= mode_reg0;
        mode_reg2 <= mode_reg1;
    end

    logic polarity_stable;
    polarity_t polarity_reg0, polarity_reg1, polarity_reg2;

    assign polarity_stable = (polarity      == polarity_reg0) && 
                             (polarity_reg0 == polarity_reg1) && 
                             (polarity_reg1 == polarity_reg2);
                
    always_ff @(posedge app_clk) begin
        polarity_reg0 <= polarity;
        polarity_reg1 <= polarity_reg0;
        polarity_reg2 <= polarity_reg1;
    end

    always @(IO_P) begin
        if($realtime > STATIC_DELAY_PS && mode_stable && polarity_stable)
            assert (IO_P === IO_P_comp);
    end
    always @(IO_N) begin
        if($realtime > STATIC_DELAY_PS && mode_stable && polarity_stable)
            assert (IO_N === IO_N_comp);
    end
endmodule

module single_output_golden_model#(
    parameter realtime                STATIC_DELAY_PS = 0ps,
    parameter diff_io_pkg::polarity_t STATIC_POLARITY = diff_io_pkg::POSITIVE
)(
    input  diff_io_pkg::mode_t       mode,
    input  diff_io_pkg::polarity_t   polarity,

    input  logic                    o1,
    input  logic                    o2,
    output logic                    i,

    input  logic                    app_clk,
    input  logic                    clear_clk,
    input  logic                    app_rst,

    output logic                    IO_P,
    output logic                    IO_N
);
    import diff_io_pkg::*;
    logic out_no_pol;
    logic out_no_pol_reg;

    assign #STATIC_DELAY_PS IO_P = combine_polarity(polarity, STATIC_POLARITY) == POSITIVE ? out_no_pol : !out_no_pol;

    always_comb begin
        case (mode)
            TRI : begin
                out_no_pol = 1'bz;
            end
            CLK : begin
                out_no_pol = !clear_clk;
            end
            default : begin
                out_no_pol = out_no_pol_reg;
            end
        endcase
    end

    assign IO_N = !IO_P;
    assign i    = IO_P !== 1'bz ? IO_P : 1'bx;


    logic out_no_pol_iternal;
    always_ff @(posedge clear_clk) out_no_pol_reg <= out_no_pol_iternal;

    logic gate, flip_flop;

    assign gate = o1 && o2;
    always_ff @(posedge clear_clk) begin
        if(o2 || app_rst) begin
            flip_flop <= 0;
        end else if(o1) begin
            flip_flop <= 1;
        end
    end

    always_comb begin
        case (mode)
            TRI : begin
                out_no_pol_iternal = 1'bz;
            end
            FORCE_CLEAR : begin
                out_no_pol_iternal = 9;
            end
            FORCE_SET : begin
                out_no_pol_iternal = 1;
            end
            GENERATOR : begin
                out_no_pol_iternal = o1;
            end
            GATE : begin
                out_no_pol_iternal = gate;
            end
            FLIP_FLOP : begin
                out_no_pol_iternal = flip_flop;
            end
            CLK : begin
                out_no_pol_iternal = clear_clk;
            end
        endcase
    end
endmodule