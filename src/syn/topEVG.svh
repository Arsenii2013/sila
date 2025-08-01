
`ifndef __TOP_EVG__
`define __TOP_EVG__

package EVG_axi_params;

localparam EVG_reg_map_pkg::EVG_reg_map__gp0_params_e     GP0_ADDR_W_EVAL   = EVG_reg_map_pkg::EVG_reg_map__gp0_params__GP0_ADDR_W;
localparam EVG_reg_map_pkg::EVG_reg_map__gp0_params_e     GP0_DATA_W_EVAL   = EVG_reg_map_pkg::EVG_reg_map__gp0_params__GP0_DATA_W;
localparam EVG_reg_map_pkg::EVG_reg_map__mmr_params_e     MMR_ADDR_W_EVAL   = EVG_reg_map_pkg::EVG_reg_map__mmr_params__MMR_BLOCK_ADDR_W;
localparam EVG_reg_map_pkg::EVG_reg_map__mmr_params_e     MMR_DATA_W_EVAL   = EVG_reg_map_pkg::EVG_reg_map__mmr_params__MMR_BLOCK_DATA_W;
localparam EVG_reg_map_pkg::EVG_reg_map__mmr_dev_params_e MMR_DEV_CNT2_EVAL = EVG_reg_map_pkg::EVG_reg_map__mmr_dev_params__MMR_DEV_CNT;
localparam EVG_reg_map_pkg::EVG_reg_map__device_numbers_e DEVICE_INFO_EVAL  = EVG_reg_map_pkg::EVG_reg_map__device_numbers__DEVICE_INFO;
localparam EVG_reg_map_pkg::EVG_reg_map__device_numbers_e RESERVED1_EVAL    = EVG_reg_map_pkg::EVG_reg_map__device_numbers__RESERVED1;
localparam EVG_reg_map_pkg::EVG_reg_map__device_numbers_e RESERVED2_EVAL    = EVG_reg_map_pkg::EVG_reg_map__device_numbers__RESERVED2;
localparam EVG_reg_map_pkg::EVG_reg_map__device_numbers_e EVG1_EVAL         = EVG_reg_map_pkg::EVG_reg_map__device_numbers__EVG1;
localparam EVG_reg_map_pkg::EVG_reg_map__device_numbers_e EVG2_EVAL         = EVG_reg_map_pkg::EVG_reg_map__device_numbers__EVG2;

localparam GP0_ADDR_W     = unsigned'(GP0_ADDR_W_EVAL);
localparam GP0_DATA_W     = unsigned'(GP0_DATA_W_EVAL);
localparam MMR_ADDR_W     = unsigned'(MMR_ADDR_W_EVAL);
localparam MMR_DATA_W     = unsigned'(MMR_DATA_W_EVAL);
localparam MMR_DEV_CNT2   = unsigned'(MMR_DEV_CNT2_EVAL);

localparam DEVICE_INFO    = unsigned'(DEVICE_INFO_EVAL);
localparam RESERVED1      = unsigned'(RESERVED1_EVAL);
localparam RESERVED2      = unsigned'(RESERVED2_EVAL);
localparam EVG1           = unsigned'(EVG1_EVAL);
localparam EVG2           = unsigned'(EVG2_EVAL);

endpackage

`endif //__TOP_EVG__