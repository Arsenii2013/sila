
`ifndef __TOP_EVR__
`define __TOP_EVR__

package EVR_axi_params;

import EVR_reg_map_pkg::*;
import device_info_axi_core_pkg::*;

localparam EVR_reg_map__gp0_params_e        GP0_ADDR_W_EVAL   = EVR_reg_map__gp0_params__GP0_ADDR_W;
localparam EVR_reg_map__gp0_params_e        GP0_DATA_W_EVAL   = EVR_reg_map__gp0_params__GP0_DATA_W;
localparam EVR_reg_map__mmr_params_e        MMR_ADDR_W_EVAL   = EVR_reg_map__mmr_params__MMR_BLOCK_ADDR_W;
localparam EVR_reg_map__mmr_params_e        MMR_DATA_W_EVAL   = EVR_reg_map__mmr_params__MMR_BLOCK_DATA_W;
localparam EVR_reg_map__mmr_dev_params_e    MMR_DEV_CNT2_EVAL = EVR_reg_map__mmr_dev_params__MMR_DEV_CNT;
localparam EVR_reg_map__device_numbers_e    DEVICE_INFO_EVAL  = EVR_reg_map__device_numbers__DEVICE_INFO;
localparam EVR_reg_map__device_numbers_e    TIMESTAMPER_EVAL  = EVR_reg_map__device_numbers__TIMESTAMPER;
localparam EVR_reg_map__device_numbers_e    EV_MAP_EVAL       = EVR_reg_map__device_numbers__EV_MAP;
localparam EVR_reg_map__ev_comp_params_e    EV_COMP_N_EVAL    = EVR_reg_map__ev_comp_params__EV_COMP_N;
localparam EVR_reg_map__device_numbers_e    SIG_GEN_CTRL_EVAL = EVR_reg_map__device_numbers__SIG_GEN_CTRL;
localparam EVR_reg_map__signal_gen_params_e SIG_GEN_N_EVAL    = EVR_reg_map__signal_gen_params__SIGNAL_GEN_N;
localparam EVR_reg_map__device_numbers_e    SFP_CONTROL_EVAL  = EVR_reg_map__device_numbers__SFP_CONTROL;
localparam EVR_reg_map__device_numbers_e    EVR_EVAL          = EVR_reg_map__device_numbers__EVR;
localparam EVR_reg_map__device_numbers_e    EV_COMAPATOR_EVAL = EVR_reg_map__device_numbers__EVENT_COMPARATOR;


localparam device_info_axi_core__device_type_encoding_e DEVICE_TYPE_EVAL = device_info_axi_core__device_type_encoding__EVR;

localparam GP0_ADDR_W     = unsigned'(GP0_ADDR_W_EVAL);
localparam GP0_DATA_W     = unsigned'(GP0_DATA_W_EVAL);
localparam MMR_ADDR_W     = unsigned'(MMR_ADDR_W_EVAL);
localparam MMR_DATA_W     = unsigned'(MMR_DATA_W_EVAL);
localparam MMR_DEV_CNT2   = unsigned'(MMR_DEV_CNT2_EVAL);

localparam DEVICE_TYPE    = unsigned'(DEVICE_TYPE_EVAL);

localparam DEVICE_INFO    = unsigned'(DEVICE_INFO_EVAL);
localparam TIMESTAMPER    = unsigned'(TIMESTAMPER_EVAL);
localparam EV_MAP         = unsigned'(EV_MAP_EVAL);
localparam EV_COMP_N      = unsigned'(EV_COMP_N_EVAL);
localparam SIG_GEN_CTRL   = unsigned'(SIG_GEN_CTRL_EVAL);
localparam SIG_GEN_N      = unsigned'(SIG_GEN_N_EVAL);
localparam SFP_CONTROL    = unsigned'(SFP_CONTROL_EVAL);
localparam EVR            = unsigned'(EVR_EVAL);
localparam EV_COMPARATOR  = unsigned'(EV_COMAPATOR_EVAL);

endpackage

`endif //__TOP_EVR__