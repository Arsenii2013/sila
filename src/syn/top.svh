
`ifndef __TOP_SVH__
`define __TOP_SVH__

package axi_params;

import rdl_axi_params_pkg::*;

localparam rdl_axi_params__gp0_params_e     GP0_ADDR_W_EVAL   = rdl_axi_params__gp0_params__GP0_ADDR_W;
localparam rdl_axi_params__gp0_params_e     GP0_DATA_W_EVAL   = rdl_axi_params__gp0_params__GP0_DATA_W;
localparam rdl_axi_params__mmr_params_e     MMR_ADDR_W_EVAL   = rdl_axi_params__mmr_params__MMR_BLOCK_ADDR_W;
localparam rdl_axi_params__mmr_params_e     MMR_DATA_W_EVAL   = rdl_axi_params__mmr_params__MMR_BLOCK_DATA_W;
localparam rdl_axi_params__mmr_dev_params_e MMR_DEV_CNT2_EVAL = rdl_axi_params__mmr_dev_params__MMR_DEV_CNT;

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

package emio_params;

localparam EMIO_0_WIDTH = 64;

endpackage

`endif //__TOP_SVH__