
`ifndef __TOP_EVR__
`define __TOP_EVR__

package EVR_axi_params;

import EVR_reg_map_pkg::*;

localparam EVR_reg_map__device_numbers_e    DEVICE_INFO_EVAL  = EVR_reg_map__device_numbers__DEVICE_INFO;
localparam EVR_reg_map__device_numbers_e    EVR_EVAL          = EVR_reg_map__device_numbers__EVR;
localparam EVR_reg_map__device_numbers_e    TIMESTAMPER_EVAL  = EVR_reg_map__device_numbers__TIMESTAMPER;
localparam EVR_reg_map__device_numbers_e    EV_MAP_EVAL       = EVR_reg_map__device_numbers__EV_MAP;
localparam EVR_reg_map__ev_comp_params_e    EV_COMP_N_EVAL    = EVR_reg_map__ev_comp_params__EV_COMP_N;
localparam EVR_reg_map__device_numbers_e    SIG_GEN_CTRL_EVAL = EVR_reg_map__device_numbers__SIG_GEN_CTRL;
localparam EVR_reg_map__signal_gen_params_e SIG_GEN_N_EVAL    = EVR_reg_map__signal_gen_params__SIGNAL_GEN_N;
localparam EVR_reg_map__device_numbers_e    SFP_CONTROL_EVAL  = EVR_reg_map__device_numbers__SFP_CONTROL;
localparam EVR_reg_map__device_numbers_e    EV_COMAPATOR_EVAL = EVR_reg_map__device_numbers__EVENT_COMPARATOR;

localparam DEVICE_INFO    = unsigned'(DEVICE_INFO_EVAL);
localparam EVR            = unsigned'(EVR_EVAL);
localparam TIMESTAMPER    = unsigned'(TIMESTAMPER_EVAL);
localparam EV_MAP         = unsigned'(EV_MAP_EVAL);
localparam EV_COMP_N      = unsigned'(EV_COMP_N_EVAL);
localparam SIG_GEN_CTRL   = unsigned'(SIG_GEN_CTRL_EVAL);
localparam SIG_GEN_N      = unsigned'(SIG_GEN_N_EVAL);
localparam SFP_CONTROL    = unsigned'(SFP_CONTROL_EVAL);
localparam EV_COMPARATOR  = unsigned'(EV_COMAPATOR_EVAL);

endpackage

`endif //__TOP_EVR__