
`ifndef __TOP_EVG__
`define __TOP_EVG__

package axi_params;

import EVG_reg_map_pkg::*;

localparam EVG_reg_map__gp0_params_e     GP0_ADDR_W_EVAL   = EVG_reg_map__gp0_params__GP0_ADDR_W;
localparam EVG_reg_map__gp0_params_e     GP0_DATA_W_EVAL   = EVG_reg_map__gp0_params__GP0_DATA_W;
localparam EVG_reg_map__mmr_params_e     MMR_ADDR_W_EVAL   = EVG_reg_map__mmr_params__MMR_BLOCK_ADDR_W;
localparam EVG_reg_map__mmr_params_e     MMR_DATA_W_EVAL   = EVG_reg_map__mmr_params__MMR_BLOCK_DATA_W;
localparam EVG_reg_map__mmr_dev_params_e MMR_DEV_CNT2_EVAL = EVG_reg_map__mmr_dev_params__MMR_DEV_CNT;

localparam GP0_ADDR_W     = unsigned'(GP0_ADDR_W_EVAL);
localparam GP0_DATA_W     = unsigned'(GP0_DATA_W_EVAL);
localparam MMR_ADDR_W     = unsigned'(MMR_ADDR_W_EVAL);
localparam MMR_DATA_W     = unsigned'(MMR_DATA_W_EVAL);
localparam MMR_DEV_CNT2   = unsigned'(MMR_DEV_CNT2_EVAL);

typedef logic [GP0_ADDR_W-1:0] gp0_addr_t;
typedef logic [GP0_DATA_W-1:0] gp0_data_t;
typedef logic [MMR_ADDR_W-1:0] mmr_addr_t;
typedef logic [MMR_DATA_W-1:0] mmr_data_t;
endpackage

package EVG_axi_params;

import EVG_reg_map_pkg::*;

localparam EVG_reg_map__device_numbers_e DEVICE_INFO_EVAL  = EVG_reg_map__device_numbers__DEVICE_INFO;
localparam EVG_reg_map__device_numbers_e EVG_EVAL          = EVG_reg_map__device_numbers__EVG;
localparam EVG_reg_map__device_numbers_e TIMESTAMPER_EVAL  = EVG_reg_map__device_numbers__TIMESTAMPER;
localparam EVG_reg_map__device_numbers_e EV_SEQ_CTRL_EVAL  = EVG_reg_map__device_numbers__EV_SEQ_CTRL;
localparam EVG_reg_map__device_numbers_e EV_SEQ_0_EVAL     = EVG_reg_map__device_numbers__EV_SEQ_0;
localparam EVG_reg_map__ev_seq_params_e  EV_SEQ_N_EVAL     = EVG_reg_map__ev_seq_params__EV_SEQ_N;
localparam EVG_reg_map__device_numbers_e SFP_CONTROL_EVAL  = EVG_reg_map__device_numbers__SFP_CONTROL;
localparam EVG_reg_map__device_numbers_e EV_COMAPATOR_EVAL = EVG_reg_map__device_numbers__EVENT_COMPARATOR;

localparam DEVICE_INFO    = unsigned'(DEVICE_INFO_EVAL);
localparam EVG            = unsigned'(EVG_EVAL);
localparam TIMESTAMPER    = unsigned'(TIMESTAMPER_EVAL);
localparam EV_SEQ_CTRL    = unsigned'(EV_SEQ_CTRL_EVAL);
localparam EV_SEQ_0       = unsigned'(EV_SEQ_0_EVAL);
localparam EV_SEQ_N       = unsigned'(EV_SEQ_N_EVAL);
localparam SFP_CONTROL    = unsigned'(SFP_CONTROL_EVAL);
localparam EV_COMPARATOR  = unsigned'(EV_COMAPATOR_EVAL);

endpackage

`endif //__TOP_EVG__