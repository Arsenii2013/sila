`ifndef _EVN_
`define _EVN_

localparam EVENT_COMMA     = 8'h5C;
localparam TRIGGER_COMMA   = 8'h7C;
localparam PACKET_COMMA    = 8'hDC;
localparam ALIGNMENT_COMMA = 8'hBC;

localparam BEACON_WORD     = {EVENT_COMMA,      EVENT_COMMA, 8'h00, 8'h00};
localparam BEACON_IS_K     = 'hC;
localparam BEACON_PERIOD   = 2 ** 10;
typedef logic [$clog2(BEACON_PERIOD): 0] beacon_cnt_t;

localparam ALIGNMENT_WORD   = {ALIGNMENT_COMMA,  8'h00,      8'h00, 8'h00};
localparam ALIGNMENT_IS_K   = 'h8;
localparam ALIGNMENT_PERIOD = 4;
typedef logic [$clog2(ALIGNMENT_PERIOD): 0] alignment_cnt_t;

localparam DELAY_INT_W      = 16;
localparam DELAY_FRAC_W     = 16;

localparam TOPO_ID_W        = 32;
`endif //_EVN_ 