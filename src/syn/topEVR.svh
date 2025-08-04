
`ifndef __TOP_EVR__
`define __TOP_EVR__

package EVR_axi_params;

localparam EVR_reg_map_pkg::EVR_reg_map__gp0_params_e     GP0_ADDR_W_EVAL   = EVR_reg_map_pkg::EVR_reg_map__gp0_params__GP0_ADDR_W;
localparam EVR_reg_map_pkg::EVR_reg_map__gp0_params_e     GP0_DATA_W_EVAL   = EVR_reg_map_pkg::EVR_reg_map__gp0_params__GP0_DATA_W;
localparam EVR_reg_map_pkg::EVR_reg_map__mmr_params_e     MMR_ADDR_W_EVAL   = EVR_reg_map_pkg::EVR_reg_map__mmr_params__MMR_BLOCK_ADDR_W;
localparam EVR_reg_map_pkg::EVR_reg_map__mmr_params_e     MMR_DATA_W_EVAL   = EVR_reg_map_pkg::EVR_reg_map__mmr_params__MMR_BLOCK_DATA_W;
localparam EVR_reg_map_pkg::EVR_reg_map__mmr_dev_params_e MMR_DEV_CNT2_EVAL = EVR_reg_map_pkg::EVR_reg_map__mmr_dev_params__MMR_DEV_CNT;
localparam EVR_reg_map_pkg::EVR_reg_map__device_numbers_e DEVICE_INFO_EVAL  = EVR_reg_map_pkg::EVR_reg_map__device_numbers__DEVICE_INFO;
localparam EVR_reg_map_pkg::EVR_reg_map__device_numbers_e RESERVED1_EVAL    = EVR_reg_map_pkg::EVR_reg_map__device_numbers__RESERVED1;
localparam EVR_reg_map_pkg::EVR_reg_map__device_numbers_e RESERVED2_EVAL    = EVR_reg_map_pkg::EVR_reg_map__device_numbers__RESERVED2;
localparam EVR_reg_map_pkg::EVR_reg_map__device_numbers_e EVR_EVAL          = EVR_reg_map_pkg::EVR_reg_map__device_numbers__EVR;

localparam GP0_ADDR_W     = unsigned'(GP0_ADDR_W_EVAL);
localparam GP0_DATA_W     = unsigned'(GP0_DATA_W_EVAL);
localparam MMR_ADDR_W     = unsigned'(MMR_ADDR_W_EVAL);
localparam MMR_DATA_W     = unsigned'(MMR_DATA_W_EVAL);
localparam MMR_DEV_CNT2   = unsigned'(MMR_DEV_CNT2_EVAL);

localparam DEVICE_INFO    = unsigned'(DEVICE_INFO_EVAL);
localparam RESERVED1      = unsigned'(RESERVED1_EVAL);
localparam RESERVED2      = unsigned'(RESERVED2_EVAL);
localparam EVR            = unsigned'(EVR_EVAL);

endpackage

`endif //__TOP_EVR__