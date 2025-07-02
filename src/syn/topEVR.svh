
`ifndef __TOP_EVR__
`define __TOP_EVR__

//      MMR
localparam RESERVED1_EVR   = 0;
localparam RESERVED2_EVR   = RESERVED1_EVR + 1;
localparam RESERVED3_EVR   = RESERVED2_EVR + 1;
localparam EVR1            = RESERVED3_EVR + 1;
localparam MMR_DEV_CNT_EVR = EVR1      + 1;

`endif //__TOP_EVR__