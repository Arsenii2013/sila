

package event_generator_pkg;

localparam TIMESTAMP_WIDTH  = 64;
localparam ENTRY_NUM        = 2048;
localparam ENTRY_SIZE       = 3; // три 32 битных слова
localparam END_OF_SEQ       = 'h50DEAD;

//import axi_params::mmr_data_t;

typedef evn::ev_t                      ev_t;
typedef logic [TIMESTAMP_WIDTH -1:0]   timestamp_t;
typedef axi_params::mmr_data_t         mem_data_t;
typedef logic [$clog2(ENTRY_NUM)-1: 0] mem_addr_t;

import ev_seq_ctrl_axi_core_pkg::*;


localparam ev_seq_ctrl_axi_core__trig_src_t_e TRIG_PROG_EVAL    = ev_seq_ctrl_axi_core__trig_src_t__PROG;
localparam ev_seq_ctrl_axi_core__sq_mode_t_e  MODE_SINGLE_EVAL  = ev_seq_ctrl_axi_core__sq_mode_t__SINGLE;
localparam ev_seq_ctrl_axi_core__sq_mode_t_e  MODE_CYCLE_EVAL   = ev_seq_ctrl_axi_core__sq_mode_t__CYCLE;
localparam ev_seq_ctrl_axi_core__sq_mode_t_e  MODE_RECYCLE_EVAL = ev_seq_ctrl_axi_core__sq_mode_t__RECYCLE;

localparam TRIG_PROG    = unsigned'(TRIG_PROG_EVAL);
localparam MODE_SINGLE  = unsigned'(MODE_SINGLE_EVAL);
localparam MODE_CYCLE   = unsigned'(MODE_CYCLE_EVAL);
localparam MODE_RECYCLE = unsigned'(MODE_RECYCLE_EVAL);

typedef enum{
    PROG    = TRIG_PROG
} trig_source_t;
typedef enum{
    SINGLE  = MODE_SINGLE,
    CYCLE   = MODE_CYCLE,
    RECYCLE = MODE_RECYCLE
} seq_mode_t;

endpackage

module event_generator #(
    parameter EV_SEQ_N  = 1
) (
    input  logic                        app_clk,
    input  logic                        app_rst,
    axi4_lite_if.s                      mmr_ctrl,
    axi4_lite_if.s                      mmr_mem[EV_SEQ_N],

    output event_generator_pkg::ev_t    ev
);
    import event_generator_pkg::*;
    logic seq_enable[EV_SEQ_N];
    logic seq_start[EV_SEQ_N];
    logic seq_stop[EV_SEQ_N];
    logic seq_running[EV_SEQ_N];
    ev_t  seq_ev[EV_SEQ_N];

    ev_seq_ctrl #(
        .EV_SEQ_N(EV_SEQ_N)
    ) ev_seq_ctrl_i (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr_ctrl),

        .seq_enable(seq_enable),
        .seq_start(seq_start),
        .seq_stop(seq_stop),
        .seq_running(seq_running),
        .ev_in(seq_ev),
        .ev_out(ev)
    );

    genvar i;
    generate
    for(i = 0; i < EV_SEQ_N; i++) begin
    ev_seq ev_seq_i (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr_mem[i]),
        
        .disable_(!seq_enable[i]),
        .start(seq_start[i]),
        .stop(seq_stop[i]),
        .running(seq_running[i]),
        .ev(seq_ev[i])
    );
    end
    endgenerate
endmodule