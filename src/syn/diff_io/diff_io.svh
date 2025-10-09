
package diff_io_pkg;

import diff_io_axi_core_pkg::*;

localparam diff_io_axi_core__mode_t_e  TRI_EVAL          = diff_io_axi_core__mode_t__TRI;
localparam diff_io_axi_core__mode_t_e  FORCE_CLEAR_EVAL  = diff_io_axi_core__mode_t__FORCE_CLEAR;
localparam diff_io_axi_core__mode_t_e  FORCE_SET_EVAL    = diff_io_axi_core__mode_t__FORCE_SET;
localparam diff_io_axi_core__mode_t_e  GENERATOR_EVAL    = diff_io_axi_core__mode_t__GENERATOR;
localparam diff_io_axi_core__mode_t_e  GATE_EVAL         = diff_io_axi_core__mode_t__GATE;
localparam diff_io_axi_core__mode_t_e  FLIP_FLOP_EVAL    = diff_io_axi_core__mode_t__FLIP_FLOP;
localparam diff_io_axi_core__mode_t_e  CLK_EVAL          = diff_io_axi_core__mode_t__CLK;

localparam diff_io_axi_core__polarity_t_e  POSITIVE_EVAL = diff_io_axi_core__polarity_t__POSITIVE;
localparam diff_io_axi_core__polarity_t_e  NEGATIVE_EVAL = diff_io_axi_core__polarity_t__NEGATIVE;

localparam unsigned MODE_TRI         = unsigned'(TRI_EVAL);
localparam unsigned MODE_FORCE_CLEAR = unsigned'(FORCE_CLEAR_EVAL);
localparam unsigned MODE_FORCE_SET   = unsigned'(FORCE_SET_EVAL);
localparam unsigned MODE_GENERATOR   = unsigned'(GENERATOR_EVAL);
localparam unsigned MODE_GATE        = unsigned'(GATE_EVAL);
localparam unsigned MODE_FLIP_FLOP   = unsigned'(FLIP_FLOP_EVAL);
localparam unsigned MODE_CLK         = unsigned'(CLK_EVAL);

localparam unsigned POLARITY_POSITIVE   = unsigned'(POSITIVE_EVAL);
localparam unsigned POLARITY_NEGATIVE   = unsigned'(NEGATIVE_EVAL);

typedef enum{
    TRI         = MODE_TRI,
    FORCE_CLEAR = MODE_FORCE_CLEAR,
    FORCE_SET   = MODE_FORCE_SET,
    GENERATOR   = MODE_GENERATOR,
    GATE        = MODE_GATE,
    FLIP_FLOP   = MODE_FLIP_FLOP,
    CLK         = MODE_CLK
} mode_t;

typedef enum{
    POSITIVE    = POLARITY_POSITIVE,
    NEGATIVE    = POLARITY_NEGATIVE
} polarity_t;

function combine_polarity(polarity_t pol1, polarity_t pol2);
    return pol1 ^ pol2;
endfunction

typedef logic [4:0] odelay_taps_t;

typedef enum{
    COMMON = 0,
    PRECISE = 1
} delay_adj_t;

endpackage