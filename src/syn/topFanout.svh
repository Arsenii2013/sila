
`ifndef __TOP_FANOUT__
`define __TOP_FANOUT__

package Fanout_axi_params;

import Fanout_reg_map_pkg::*;

localparam Fanout_reg_map__device_numbers_e DEVICE_INFO_EVAL  = Fanout_reg_map__device_numbers__DEVICE_INFO;
localparam Fanout_reg_map__device_numbers_e FANOUT_EVAL       = Fanout_reg_map__device_numbers__FANOUT;
localparam Fanout_reg_map__device_numbers_e TIMESTAMPER_EVAL  = Fanout_reg_map__device_numbers__TIMESTAMPER;
localparam Fanout_reg_map__device_numbers_e SFP_CONTROL_EVAL  = Fanout_reg_map__device_numbers__SFP_CONTROL;

localparam DEVICE_INFO    = unsigned'(DEVICE_INFO_EVAL);
localparam FANOUT         = unsigned'(FANOUT_EVAL);
localparam TIMESTAMPER    = unsigned'(TIMESTAMPER_EVAL);
localparam SFP_CONTROL    = unsigned'(SFP_CONTROL_EVAL);

endpackage

`endif //__TOP_FANOUT__