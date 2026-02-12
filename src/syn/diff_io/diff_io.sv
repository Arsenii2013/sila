`include "diff_io.svh"

module diff_io #(
    parameter unsigned OUTPUT_N     = 16,
    parameter unsigned DUPLICATE_N  = 8,
    parameter diff_io_pkg::polarity_t     STATIC_POLARITY [OUTPUT_N] = '{default: diff_io_pkg::POSITIVE},
    parameter diff_io_pkg::diff_io_mode_t DIFF_IO_MODES   [OUTPUT_N] = '{default: diff_io_pkg::COMMON}
)(
    input  logic    app_clk,
    input  logic    clear_clk,
    input  logic    iodelayctrl_refclk, // 200 MHz
    input  logic    app_rst,
    axi4_lite_if.s  mmr,

    input  logic    o1[OUTPUT_N],
    input  logic    o2[OUTPUT_N],
    output logic    in_logic[OUTPUT_N],

    inout  logic    IO_P[OUTPUT_N],
    inout  logic    IO_N[OUTPUT_N],
    inout  logic    IO_D[DUPLICATE_N],

    output logic    SER,
    output logic    SRCLK,
    output logic    RCLK
);
    import diff_io_pkg::*;

    localparam ODELAY_GROUP = "ODELAY_GROUP";

    (* IODELAY_GROUP = ODELAY_GROUP *) 
    IDELAYCTRL IDELAYCTRL_inst (
        .RDY(),
        .REFCLK(iodelayctrl_refclk),
        .RST(app_rst)
    );

    logic inputs[OUTPUT_N];
    mode_t modes[OUTPUT_N];
    polarity_t polarites[OUTPUT_N];

    genvar output_i;
    generate
    for(output_i = 0; output_i < OUTPUT_N; output_i++ ) begin : outputs
        localparam STATIC_DELAY_TAPS = 10;
        single_output #(
            .STATIC_ODELAY_TAPS(STATIC_DELAY_TAPS),
            .ODELAY_GROUP(ODELAY_GROUP),
            .STATIC_POLARITY(STATIC_POLARITY[output_i]),
            .DIFF_OUT(1),
            .USE_ODELAY(1)
        ) single_output_inst (
            .app_clk(app_clk),
            .clear_clk(clear_clk),
            .app_rst(app_rst),

            .o1(o1[output_i]),
            .o2(o2[output_i]),
            .in(inputs[output_i]),
            .mode(modes[output_i]),
            .polarity(polarites[output_i]),
            .IO_P(IO_P[output_i]),
            .IO_N(IO_N[output_i])
        );
        if(output_i < DUPLICATE_N) begin
            single_output #(
                .STATIC_ODELAY_TAPS(STATIC_DELAY_TAPS),
                .ODELAY_GROUP(ODELAY_GROUP),
                .STATIC_POLARITY(POSITIVE),
                .DIFF_OUT(0),
                .USE_ODELAY(0)
            ) duplicate_output_inst (
                .app_clk(app_clk),
                .clear_clk(clear_clk),
                .app_rst(app_rst),

                .o1(o1[output_i]),
                .o2(o2[output_i]),
                .in(),
                .mode(modes[output_i]),
                .polarity(polarites[output_i]),
                .IO_P(IO_D[output_i]),
                .IO_N()
            );
        end
        assign in_logic[output_i] = STATIC_POLARITY[output_i] == POSITIVE ? inputs[output_i] : !inputs[output_i];
    end
    endgenerate

    localparam int unsigned PRECISE_CNT = 8;
    localparam int unsigned SN74HC595_CNT = PRECISE_CNT * PRECISE_DELAY_ADJ_W / 8;
    logic [7                    : 0] sn74hc595_Q                  [SN74HC595_CNT];
    logic                            sn74hc595_Q_upd;
    logic [PRECISE_DELAY_ADJ_W-1: 0] hwif_precise_delay_adj     [PRECISE_CNT];
    logic                            hwif_precise_delay_adj_upd [PRECISE_CNT];

    logic [SN74HC595_CNT-1: 0][7                    : 0] sn74hc595_Q_flat;
    logic [PRECISE_CNT  -1: 0][PRECISE_DELAY_ADJ_W-1: 0] hwif_precise_delay_adj_flat;
    assign hwif_precise_delay_adj_flat  = {<<10{hwif_precise_delay_adj}};
    assign sn74hc595_Q_flat             = hwif_precise_delay_adj_flat;
    assign sn74hc595_Q                  = {>>{sn74hc595_Q_flat}};
    //assign sn74hc595_Q_upd              = hwif_precise_delay_adj_upd.or();
    always_comb begin
        sn74hc595_Q_upd = 0;
        foreach (hwif_precise_delay_adj_upd[i]) begin
            sn74hc595_Q_upd |= hwif_precise_delay_adj_upd[i];
        end
    end

    sn74hc595_controller #(
        .CASCADE_LEN(SN74HC595_CNT),
        .SRCLK_PRESCALER(1000)
    ) sn74hc595_controller_inst (
        .clk(app_clk),
        .reset(app_rst),

        .Q(sn74hc595_Q),
        .send_Q(sn74hc595_Q_upd),

        .SER(SER),
        .RCLK(RCLK),
        .SRCLK(SRCLK)
    );

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

        if(DIFF_IO_MODES[hwif_i] == PRECISE) begin
            assign hwif_precise_delay_adj[hwif_i]     = hwif_out.out_regs[hwif_i].precise_delay_adj.value.value;
            assign hwif_precise_delay_adj_upd[hwif_i] = hwif_out.out_regs[hwif_i].precise_delay_adj.value.swmod;
            assign hwif_in.out_regs[hwif_i].precise_delay_adj.value.next = hwif_precise_delay_adj[hwif_i];
        end

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