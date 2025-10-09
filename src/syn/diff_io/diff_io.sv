module diff_io #(
    parameter unsigned OUTPUT_N = 16,
    parameter diff_io_pkg::polarity_t  STATIC_POLARITY [OUTPUT_N] = '{default: diff_io_pkg::POSITIVE},
    parameter diff_io_pkg::delay_adj_t DELAY_ADJ       [OUTPUT_N] = '{default: diff_io_pkg::COMMON}
)(
    input  logic    app_clk,
    input  logic    clear_clk,
    input  logic    iodelayctrl_refclk, // 200 MHz
    input  logic    app_rst,
    axi4_lite_if.s  mmr,

    input  logic    o1[OUTPUT_N],
    input  logic    o2[OUTPUT_N],

    inout  logic    IO_P[OUTPUT_N],
    inout  logic    IO_N[OUTPUT_N]
);
    import diff_io_pkg::*;

    localparam ODELAY_GROUP = "ODELAY_GROUP";

    (* IODELAY_GROUP = ODELAY_GROUP *) 
    IDELAYCTRL IDELAYCTRL_inst (
        .RDY(),
        .REFCLK(idelayctrl_refclk),
        .RST(app_rst)
    );

    logic inputs[OUTPUT_N];
    mode_t modes[OUTPUT_N];
    polarity_t polarites[OUTPUT_N];

    genvar output_i;
    generate
    for(output_i = 0; output_i < OUTPUT_N; output_i++ ) begin : outputs
        localparam STATIC_DELAY_TAPS = DELAY_ADJ[output_i] == COMMON ? 29 : 0;
        single_output #(
            .STATIC_ODELAY_TAPS(STATIC_DELAY_TAPS),
            .ODELAY_GROUP(ODELAY_GROUP),
            .STATIC_POLARITY(STATIC_POLARITY[output_i])
        ) single_output_inst (
            .app_clk(app_clk),
            .clear_clk(clear_clk),
            .app_rst(app_rst),

            .o1(o1[output_i]),
            .o2(o2[output_i]),
            .i(inputs[output_i]),
            .mode(modes[output_i]),
            .polarity(polarites[output_i]),
            .IO_P(IO_P[output_i]),
            .IO_N(IO_N[output_i])
        );
    end
    endgenerate

    diff_io_axi_core_pkg::diff_io_axi_core__in_t  hwif_in;
    diff_io_axi_core_pkg::diff_io_axi_core__out_t hwif_out;

    assign hwif_in.sr.value.next        = {>> {inputs}};

    assign hwif_in.cr.reserved.next     = (hwif_out.cr.reserved.value | hwif_out.cr_s.reserved.value) & ~hwif_out.cr_c.reserved.value;
    assign hwif_in.cr_s.reserved.next   = '0;
    assign hwif_in.cr_c.reserved.next   = '0;

    genvar hwif_i;
    generate
    for(hwif_i = 0; hwif_i < OUTPUT_N; hwif_i++ ) begin
        assign hwif_in.out_regs[hwif_i].out_sr.value.next       = inputs[hwif_i];
        assign hwif_in.out_regs[hwif_i].out_cr.polarity.next    = polarites[hwif_i];
        assign hwif_in.out_regs[hwif_i].out_cr.mode.next        = modes[hwif_i];
        assign hwif_in.out_regs[hwif_i].out_cr_s.polarity.next  = '0;
        assign hwif_in.out_regs[hwif_i].out_cr_s.mode.next      = '0;
        assign hwif_in.out_regs[hwif_i].out_cr_c.polarity.next  = '0;
        assign hwif_in.out_regs[hwif_i].out_cr_c.mode.next      = '0;


        assign polarites[hwif_i] = polarity_t'((hwif_out.out_regs[hwif_i].out_cr.polarity.value | 
                                                hwif_out.out_regs[hwif_i].out_cr_s.polarity.value) & 
                                               ~hwif_out.out_regs[hwif_i].out_cr_c.polarity.value);

        assign modes[hwif_i]     =     mode_t'((hwif_out.out_regs[hwif_i].out_cr.mode.value | 
                                                hwif_out.out_regs[hwif_i].out_cr_s.mode.value) & 
                                               ~hwif_out.out_regs[hwif_i].out_cr_c.mode.value);

    end
    endgenerate

    diff_io_axi_core diff_io_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

endmodule