`ifndef _EVN_
`define _EVN_

localparam EVENT_COMMA     = 8'h5C;
localparam TRIGGER_COMMA   = 8'h7C;
localparam PACKET_COMMA    = 8'hDC;
localparam ALIGNMENT_COMMA = 8'hBC;

localparam BEACON_WORD     = {EVENT_COMMA,      EVENT_COMMA, 8'h00, 8'h00};
localparam BEACON_IS_K     = 'hC;
localparam BEACON_PERIOD   = 2 ** 10 - 1;
typedef logic [$clog2(BEACON_PERIOD): 0] beacon_cnt_t;

localparam ALIGNMENT_WORD   = {ALIGNMENT_COMMA,  8'h00,      8'h00, 8'h00};
localparam ALIGNMENT_IS_K   = 'h8;
localparam ALIGNMENT_PERIOD = 4;
typedef logic [$clog2(ALIGNMENT_PERIOD): 0] alignment_cnt_t;

localparam DELAY_INT_W      = 16;
localparam DELAY_FRAC_W     = 16;
localparam DELAY_W          = DELAY_INT_W + DELAY_FRAC_W;

localparam TOPO_ID_W        = 32;

// System packets

localparam SYSTEM_PACKET_ID_START   = 8'h00;
localparam TOPO_ID_PACKET_ID        = SYSTEM_PACKET_ID_START + 8'h01;
localparam MEAS_DELAY_PACKET_ID     = TOPO_ID_PACKET_ID      + 8'h01;
localparam UP_DELAY_PACKET_ID       = MEAS_DELAY_PACKET_ID   + 8'h01;
localparam TGT_DELAY_PACKET_ID      = UP_DELAY_PACKET_ID     + 8'h01;

localparam TOPO_ID_PACKET_LEN    = 16'h0001;
localparam MEAS_DELAY_PACKET_LEN = 16'h0002;
localparam UP_DELAY_PACKET_LEN   = 16'h0002;
localparam TGT_DELAY_PACKET_LEN  = 16'h0001;

localparam TOPO_ID_PACKET_START  = {PACKET_COMMA, TOPO_ID_PACKET_ID,    TOPO_ID_PACKET_LEN   };
localparam MEAS_DELAY_START      = {PACKET_COMMA, MEAS_DELAY_PACKET_ID, MEAS_DELAY_PACKET_LEN};
localparam UP_DELAY_START        = {PACKET_COMMA, UP_DELAY_PACKET_ID,   UP_DELAY_PACKET_LEN  };
localparam TGT_DELAY_START       = {PACKET_COMMA, TGT_DELAY_PACKET_ID,  TGT_DELAY_PACKET_LEN };

localparam PACKET_START_IS_K     = 4'h8;

// User packets

localparam USER_ID_START    = 8'h80;
localparam TAMESTAMP_ID     = USER_ID_START + 1;
`endif //_EVN_ 