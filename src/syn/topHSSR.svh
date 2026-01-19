
`ifndef __TOP_HSSR__
`define __TOP_HSSR__

package HSSR_axi_params;

import HSSR_reg_map_pkg::*;

localparam HSSR_reg_map__device_numbers_e    DEVICE_INFO_EVAL  = HSSR_reg_map__device_numbers__DEVICE_INFO;
localparam HSSR_reg_map__device_numbers_e    HSSR_EVAL          = HSSR_reg_map__device_numbers__HSSR;
localparam HSSR_reg_map__device_numbers_e    TIMESTAMPER_EVAL  = HSSR_reg_map__device_numbers__TIMESTAMPER;
localparam HSSR_reg_map__device_numbers_e    EV_MAP_EVAL       = HSSR_reg_map__device_numbers__EV_MAP;
localparam HSSR_reg_map__ev_comp_params_e    EV_COMP_N_EVAL    = HSSR_reg_map__ev_comp_params__EV_COMP_N;
localparam HSSR_reg_map__device_numbers_e    SIG_GEN_CTRL_EVAL = HSSR_reg_map__device_numbers__SIG_GEN_CTRL;
localparam HSSR_reg_map__signal_gen_params_e SIG_GEN_N_EVAL    = HSSR_reg_map__signal_gen_params__SIGNAL_GEN_N;
localparam HSSR_reg_map__device_numbers_e    SIG_GEN_MAP_EVAL  = HSSR_reg_map__device_numbers__SIG_GEN_MAP;
localparam HSSR_reg_map__device_numbers_e    DIFF_IO_EVAL      = HSSR_reg_map__device_numbers__DIFF_IO;
localparam HSSR_reg_map__diff_io_params_e    DIFF_IO_N_EVAL    = HSSR_reg_map__diff_io_params__DIFF_IO_N;
localparam HSSR_reg_map__device_numbers_e    I2C_MUX_EVAL      = HSSR_reg_map__device_numbers__I2C_MUX;

localparam DEVICE_INFO    = unsigned'(DEVICE_INFO_EVAL);
localparam HSSR            = unsigned'(HSSR_EVAL);
localparam TIMESTAMPER    = unsigned'(TIMESTAMPER_EVAL);
localparam EV_MAP         = unsigned'(EV_MAP_EVAL);
localparam EV_COMP_N      = unsigned'(EV_COMP_N_EVAL);
localparam SIG_GEN_CTRL   = unsigned'(SIG_GEN_CTRL_EVAL);
localparam SIG_GEN_N      = unsigned'(SIG_GEN_N_EVAL);
localparam SIG_GEN_MAP    = unsigned'(SIG_GEN_MAP_EVAL);
localparam DIFF_IO        = unsigned'(DIFF_IO_EVAL);
localparam DIFF_IO_N      = unsigned'(DIFF_IO_N_EVAL);
localparam I2C_MUX        = unsigned'(I2C_MUX_EVAL);

endpackage

package HSSR_reset_params;

localparam COMMON       = 0;
localparam DEVICE_INFO  = COMMON      + 1;
localparam TIMESTAMPER  = DEVICE_INFO + 1;
localparam GTWIZARD     = TIMESTAMPER + 1;
localparam HSSR          = GTWIZARD    + 1;
localparam EV_MAP       = HSSR         + 1;
localparam SIG_GEN_CTRL = EV_MAP      + 1;
localparam SIG_GEN_MAP  = SIG_GEN_CTRL+ 1;
localparam DIFF_IO      = SIG_GEN_MAP + 1;
localparam DEV_CNT      = DIFF_IO     + 1;


endpackage

package HSSR_aresetn_params;

localparam COMMON   = 0;
localparam DEV_CNT  = COMMON  + 1;

endpackage

`endif //__TOP_HSSR__