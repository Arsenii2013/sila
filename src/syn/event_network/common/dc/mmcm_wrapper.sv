module mmcm_wrapper(
    input  logic  clk_in1,
    input  logic  clk_in2,
    input  logic  clk_in_sel,
    
    output logic  clk_out1,

    input  logic  ph_inc,
    input  logic  ph_dec,

    input  logic  reset,
    output logic  locked
);
    logic clk_in1_clk_wiz;
    logic clk_in2_clk_wiz;
    IBUF clkin1_ibufg
    (.O (clk_in1_clk_wiz), .I (clk_in1));

    IBUF clkin2_ibufg
    (.O (clk_in2_clk_wiz), .I (clk_in2));


    logic        clk_out1_clk_wiz;

    logic        clkfbout;
    logic        clkfbout_buf;

    logic        locked_int;


    logic        psclk;
    logic        psen;
    logic        psincdec;
    logic        psdone;
    logic        psreset;

    `ifdef SYNTHESIS // костыль, потому что у mmcm2 в симуляции не работает fine phase shift
    MMCME2_ADV
    `else            // а у mmcm3, работает
    MMCME3_ADV
    `endif
    #(.BANDWIDTH            ("OPTIMIZED"),
        .CLKOUT4_CASCADE      ("FALSE"),
        .COMPENSATION         ("ZHOLD"),
        .STARTUP_WAIT         ("FALSE"),
        .DIVCLK_DIVIDE        (1),
        .CLKFBOUT_MULT_F      (8.000),
        .CLKFBOUT_PHASE       (0.000),
        .CLKFBOUT_USE_FINE_PS ("FALSE"),
        .CLKOUT0_DIVIDE_F     (8.000),
        .CLKOUT0_PHASE        (0.000),
        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKOUT0_USE_FINE_PS  ("TRUE"),
        .CLKIN1_PERIOD        (5.714),
        .CLKIN2_PERIOD        (5.714)
    )
    mmcm_adv_inst
    (
        .CLKFBOUT            (clkfbout),
        .CLKFBOUTB           (),
        .CLKOUT0             (clk_out1_clk_wiz),
        .CLKOUT0B            (),
        .CLKOUT1             (),
        .CLKOUT1B            (),
        .CLKOUT2             (),
        .CLKOUT2B            (),
        .CLKOUT3             (),
        .CLKOUT3B            (),
        .CLKOUT4             (),
        .CLKOUT5             (),
        .CLKOUT6             (),
        .CLKFBIN             (clkfbout_buf),
        .CLKIN1              (clk_in1_clk_wiz),
        .CLKIN2              (clk_in2_clk_wiz),
        .CLKINSEL            (clk_in_sel),
        .DADDR               (7'h0),
        .DCLK                (1'b0),
        .DEN                 (1'b0),
        .DI                  (16'h0),
        .DO                  (),
        .DRDY                (),
        .DWE                 (1'b0),
        .PSCLK               (psclk),
        .PSEN                (psen),
        .PSINCDEC            (psincdec),
        .PSDONE              (psdone),
        .LOCKED              (locked_int),
        .CLKINSTOPPED        (),
        .CLKFBSTOPPED        (),
        .PWRDWN              (1'b0),
        .RST                 (reset || psreset)
    );

    assign locked = locked_int;

    BUFG clkf_buf
    (.O (clkfbout_buf),
        .I (clkfbout));

    BUFG clkout1_buf
    (.O   (clk_out1),
        .I   (clk_out1_clk_wiz));


    assign psclk = clk_out1;

    logic clk_in_sel_prev;
    always_ff @(posedge clk_in1) begin
        clk_in_sel_prev <= clk_in_sel;
    end
    assign psreset = clk_in_sel ^ clk_in_sel_prev;


    always_ff @(posedge psclk) begin
        if (ph_inc) begin
            psen        <= 1;
            psincdec    <= 1;
        end else if (ph_dec) begin
            psen        <= 1;
            psincdec    <= 0;
        end else 
            psen <= 0;
    end

endmodule
