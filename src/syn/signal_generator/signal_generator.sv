package signal_generator_pkg;

import signal_gen_ctrl_axi_core_pkg::*;

localparam signal_gen_ctrl_axi_core__output_src_t_e SET_EVAL       = signal_gen_ctrl_axi_core__output_src_t__FORCE_SET;
localparam signal_gen_ctrl_axi_core__output_src_t_e CLEAR_EVAL     = signal_gen_ctrl_axi_core__output_src_t__FORCE_CLEAR;
localparam signal_gen_ctrl_axi_core__output_src_t_e GENERATOR_EVAL = signal_gen_ctrl_axi_core__output_src_t__GENERATOR;
localparam signal_gen_ctrl_axi_core__trig_src_t_e   EVENT_EVAL     = signal_gen_ctrl_axi_core__trig_src_t__EVENT;
localparam signal_gen_ctrl_axi_core__trig_src_t_e   PERIOD_EVAL    = signal_gen_ctrl_axi_core__trig_src_t__PERIOD;

localparam OUT_SET       = unsigned'(SET_EVAL);
localparam OUT_CLEAR     = unsigned'(CLEAR_EVAL);
localparam OUT_GENERATOR = unsigned'(GENERATOR_EVAL);
localparam TRIG_EVENT    = unsigned'(EVENT_EVAL);
localparam TRIG_PERIOD   = unsigned'(PERIOD_EVAL);

localparam PERIOD_W = 64;
localparam DELAY_W  = 64;
localparam WIDTH_W  = 64;

typedef enum {
    EVENT      = TRIG_EVENT,
    PERIOD     = TRIG_PERIOD
} trig_source_t;

typedef enum {
    FORCE_SET   = OUT_SET,
    FORCE_CLEAR = OUT_CLEAR,
    GENERATOR   = OUT_GENERATOR
} out_source_t;

typedef evn::ev_t            ev_t;
typedef logic [PERIOD_W-1:0] period_t;
typedef logic [DELAY_W-1:0]  delay_t;
typedef logic [WIDTH_W-1:0]  width_t;

endpackage

module signal_generator #(
    parameter N        = 16
) (
    input  logic                 app_clk,
    input  logic                 app_rst,
    axi4_lite_if.s               mmr,

    input  logic                 set[N],
    input  logic                 clear[N],
    input  logic                 trigger[N],
    input  logic                 cnt_reset[N],
    output logic                 gen_out[N]
);
    import signal_generator_pkg::*;

    period_t        period[N];
    delay_t         delay[N];
    width_t         width[N];
    logic           polarity[N];
    trig_source_t   trig_source[N];
    out_source_t output_source[N];

    logic           set_ena[N];
    logic           clear_ena[N];
    logic           trigger_ena[N];
    logic           cnt_reset_ena[N];

    genvar i;
    generate
    for(i = 0; i < N; i++) begin
    signal_gen_channel signal_gen_channel_i (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .set(set[i] && set_ena[i]),
        .clear(clear[i] && clear_ena[i]),
        .trigger(trigger[i] && trigger_ena[i]),
        .cnt_reset(cnt_reset[i] && cnt_reset_ena[i]),
        .delay(delay[i]),
        .width(width[i]),
        .period(period[i]),
        .polarity(polarity[i]),
        .gen_out(gen_out[i]),
        .trig_src(trig_source[i]),
        .out_src(output_source[i])
    );
    end
    endgenerate

    signal_gen_ctrl_axi_core_pkg::signal_gen_ctrl_axi_core__in_t  hwif_in;
    signal_gen_ctrl_axi_core_pkg::signal_gen_ctrl_axi_core__out_t hwif_out;

    assign hwif_in.cr.reserved.next      = (hwif_out.cr.reserved.value | hwif_out.cr_s.reserved.value) & ~hwif_out.cr_c.reserved.value;
    assign hwif_in.cr_s.reserved.next    = '0;
    assign hwif_in.cr_c.reserved.next    = '0;

    genvar j;
    generate
    for(j = 0; j < N; j++) begin
        assign hwif_in.sr.gen_output.next[j]           = gen_out[j];
        assign hwif_in.gen_regs[j].gen_sr.output_.next = gen_out[j];

        assign set_ena[j]       = (hwif_out.gen_regs[j].gen_cr.set_ena.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.set_ena.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.set_ena.value;
        assign clear_ena[j]     = (hwif_out.gen_regs[j].gen_cr.clear_ena.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.clear_ena.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.clear_ena.value;
        assign trigger_ena[j]   = (hwif_out.gen_regs[j].gen_cr.trigger_ena.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.trigger_ena.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.trigger_ena.value;
        assign cnt_reset_ena[j] = (hwif_out.gen_regs[j].gen_cr.cnt_reset_ena.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.cnt_reset_ena.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.cnt_reset_ena.value;
        assign polarity[j]      = (hwif_out.gen_regs[j].gen_cr.polarity.value || 
                                   hwif_out.gen_regs[j].gen_cr_s.polarity.value) && 
                                  ~hwif_out.gen_regs[j].gen_cr_c.polarity.value;
        assign trig_source[j]   = trig_source_t'((hwif_out.gen_regs[j].gen_cr.trig_src.value | 
                                                  hwif_out.gen_regs[j].gen_cr_s.trig_src.value) & 
                                                 ~hwif_out.gen_regs[j].gen_cr_c.trig_src.value);
        assign output_source[j] = out_source_t'((hwif_out.gen_regs[j].gen_cr.out_src.value | 
                                                    hwif_out.gen_regs[j].gen_cr_s.out_src.value) & 
                                                   ~hwif_out.gen_regs[j].gen_cr_c.out_src.value);

        assign hwif_in.gen_regs[j].gen_cr.set_ena.next       = set_ena[j]; 
        assign hwif_in.gen_regs[j].gen_cr.clear_ena.next     = clear_ena[j];
        assign hwif_in.gen_regs[j].gen_cr.trigger_ena.next   = trigger_ena[j];
        assign hwif_in.gen_regs[j].gen_cr.cnt_reset_ena.next = cnt_reset_ena[j];
        assign hwif_in.gen_regs[j].gen_cr.polarity.next      = polarity[j];
        assign hwif_in.gen_regs[j].gen_cr.trig_src.next      = trig_source[j];
        assign hwif_in.gen_regs[j].gen_cr.out_src.next       = output_source[j];

        assign hwif_in.gen_regs[j].gen_cr_s.set_ena.next       = 0; 
        assign hwif_in.gen_regs[j].gen_cr_s.clear_ena.next     = 0;
        assign hwif_in.gen_regs[j].gen_cr_s.trigger_ena.next   = 0;
        assign hwif_in.gen_regs[j].gen_cr_s.cnt_reset_ena.next = 0;
        assign hwif_in.gen_regs[j].gen_cr_s.polarity.next      = 0;
        assign hwif_in.gen_regs[j].gen_cr_s.trig_src.next      = '0;
        assign hwif_in.gen_regs[j].gen_cr_s.out_src.next       = '0;

        assign hwif_in.gen_regs[j].gen_cr_c.set_ena.next       = 0; 
        assign hwif_in.gen_regs[j].gen_cr_c.clear_ena.next     = 0;
        assign hwif_in.gen_regs[j].gen_cr_c.trigger_ena.next   = 0;
        assign hwif_in.gen_regs[j].gen_cr_c.cnt_reset_ena.next = 0;
        assign hwif_in.gen_regs[j].gen_cr_c.polarity.next      = 0;
        assign hwif_in.gen_regs[j].gen_cr_c.trig_src.next      = '0;
        assign hwif_in.gen_regs[j].gen_cr_c.out_src.next       = '0;

        assign delay[j]  = {hwif_out.gen_regs[j].delay_msb.delay_msb.value,   hwif_out.gen_regs[j].delay_lsb.delay_lsb.value};
        assign width[j]  = {hwif_out.gen_regs[j].width_msb.width_msb.value,   hwif_out.gen_regs[j].width_lsb.width_lsb.value};
        assign period[j] = {hwif_out.gen_regs[j].period_msb.period_msb.value, hwif_out.gen_regs[j].period_lsb.period_lsb.value};
    end
    endgenerate
    
    signal_gen_ctrl_axi_core signal_gen_ctrl_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

endmodule
