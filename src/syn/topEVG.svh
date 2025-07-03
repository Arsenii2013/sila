
`ifndef __TOP_EVG__
`define __TOP_EVG__

//      MMR
localparam RESERVED1_EVG   = 0;
localparam RESERVED2_EVG   = RESERVED1_EVG + 1;
localparam RESERVED3_EVG   = RESERVED2_EVG + 1;
localparam EVG1            = RESERVED3_EVG + 1;
localparam MMR_DEV_CNT_EVG = EVG1      + 1;

`endif //__TOP_EVG__