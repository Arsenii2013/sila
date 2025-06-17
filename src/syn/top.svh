
`ifndef __TOP_SVH__
`define __TOP_SVH__

//      Common
localparam CLK_PRD         = 8;

//      Processing system
localparam GP0_ADDR_W      = 32;
localparam GP0_DATA_W      = 32;

//      MMR
localparam RESERVED1       = 0;
localparam RESERVED2       = RESERVED1 + 1;
localparam RESERVED3       = RESERVED2 + 1;
localparam EVG1            = RESERVED3 + 1;
localparam EVG2            = EVG1      + 1;
localparam EVR1            = EVG2      + 1;
localparam EVR2            = EVR1      + 1;
localparam MMR_DEV_CNT     = EVR2      + 1;

localparam MMR_DEV_CNT2    = 256; // 0x1000000 per device

localparam MMR_ADDR_W      = GP0_ADDR_W - $clog2(MMR_DEV_CNT2);
localparam MMR_DATA_W      = GP0_DATA_W;

`endif //__TOP_SVH__