
`ifndef __TOP_HSSM__
`define __TOP_HSSM__

package HSSM_axi_params;

import HSSM_reg_map_pkg::*;

localparam HSSM_reg_map__device_numbers_e DEVICE_INFO_EVAL  = HSSM_reg_map__device_numbers__DEVICE_INFO;
localparam HSSM_reg_map__device_numbers_e EVG_EVAL          = HSSM_reg_map__device_numbers__EVG;
localparam HSSM_reg_map__device_numbers_e TIMESTAMPER_EVAL  = HSSM_reg_map__device_numbers__TIMESTAMPER;
localparam HSSM_reg_map__device_numbers_e EV_SEQ_CTRL_EVAL  = HSSM_reg_map__device_numbers__EV_SEQ_CTRL;
localparam HSSM_reg_map__device_numbers_e EV_SEQ_0_EVAL     = HSSM_reg_map__device_numbers__EV_SEQ_0;
localparam HSSM_reg_map__ev_seq_params_e  EV_SEQ_N_EVAL     = HSSM_reg_map__ev_seq_params__EV_SEQ_N;
localparam HSSM_reg_map__device_numbers_e I2C_MUX_EVAL      = HSSM_reg_map__device_numbers__I2C_MUX;
localparam HSSM_reg_map__device_numbers_e XADC_EVAL         = HSSM_reg_map__device_numbers__XADC;
localparam HSSM_reg_map__device_numbers_e EV_COMAPATOR_EVAL = HSSM_reg_map__device_numbers__EVENT_COMPARATOR;

localparam DEVICE_INFO    = unsigned'(DEVICE_INFO_EVAL);
localparam EVG            = unsigned'(EVG_EVAL);
localparam TIMESTAMPER    = unsigned'(TIMESTAMPER_EVAL);
localparam EV_SEQ_CTRL    = unsigned'(EV_SEQ_CTRL_EVAL);
localparam EV_SEQ_0       = unsigned'(EV_SEQ_0_EVAL);
localparam EV_SEQ_N       = unsigned'(EV_SEQ_N_EVAL);
localparam I2C_MUX        = unsigned'(I2C_MUX_EVAL);
localparam XADC           = unsigned'(XADC_EVAL);
localparam EV_COMPARATOR  = unsigned'(EV_COMAPATOR_EVAL);

endpackage


package HSSM_reset_params;

localparam COMMON       = 0;
localparam DEVICE_INFO  = COMMON      + 1;
localparam TIMESTAMPER  = DEVICE_INFO + 1;
localparam GTWIZARD     = TIMESTAMPER + 1;
localparam EVG          = GTWIZARD    + 1;
localparam EV_SEQ_CTRL  = EVG         + 1;
localparam DEV_CNT      = EV_SEQ_CTRL + 1;

endpackage

package HSSM_aresetn_params;

localparam COMMON   = 0;
localparam DEV_CNT  = COMMON  + 1;

endpackage
`endif //__TOP_HSSM__