
`ifndef __TOP_SVH__
`define __TOP_SVH__

//      Common
localparam CLK_PRD         = 8;

//      Processing system
localparam GP0_ADDR_W      = 21;
localparam GP0_DATA_W      = 32;

localparam MMR_DEV_CNT2    = 32; // 0x10000 per device

localparam MMR_ADDR_W      = GP0_ADDR_W - $clog2(MMR_DEV_CNT2);
localparam MMR_DATA_W      = GP0_DATA_W;

`endif //__TOP_SVH__