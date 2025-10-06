
`ifndef __TOP_EVG__
`define __TOP_EVG__

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


package EVG_reset_params;

localparam COMMON       = 0;
localparam DEVICE_INFO  = COMMON      + 1;
localparam TIMESTAMPER  = DEVICE_INFO + 1;
localparam GTWIZARD     = TIMESTAMPER + 1;
localparam EVG          = GTWIZARD    + 1;
localparam EV_SEQ_CTRL  = EVG         + 1;
localparam DEV_CNT      = EV_SEQ_CTRL + 1;

endpackage

package EVG_aresetn_params;

localparam COMMON   = 0;
localparam DEV_CNT  = COMMON  + 1;

endpackage
`endif //__TOP_EVG__