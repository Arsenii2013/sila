set_property -dict { PACKAGE_PIN AF12   IOSTANDARD LVCMOS33 } [get_ports { LED[0] }];
set_property -dict { PACKAGE_PIN AE12   IOSTANDARD LVCMOS33 } [get_ports { LED[1] }];
set_property -dict { PACKAGE_PIN AB17   IOSTANDARD LVCMOS33 } [get_ports { LED[2] }];
set_property -dict { PACKAGE_PIN AB16   IOSTANDARD LVCMOS33 } [get_ports { LED[3] }];
set_property -dict { PACKAGE_PIN AC17   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_LINK[0] }];
set_property -dict { PACKAGE_PIN AC16   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_ACT[0] }];
set_property -dict { PACKAGE_PIN G14    IOSTANDARD LVDS } [get_ports { START_p[0] }];
set_property -dict { PACKAGE_PIN E10    IOSTANDARD LVDS } [get_ports { START_p[1] }];
set_property -dict { PACKAGE_PIN A15    IOSTANDARD LVDS } [get_ports { START_p[2] }];
set_property -dict { PACKAGE_PIN C11    IOSTANDARD LVDS } [get_ports { START_p[3] }];
set_property -dict { PACKAGE_PIN F15    IOSTANDARD LVDS } [get_ports { START_p[4] }];
set_property -dict { PACKAGE_PIN C12    IOSTANDARD LVDS } [get_ports { START_p[5] }];
set_property -dict { PACKAGE_PIN B17    IOSTANDARD LVDS } [get_ports { START_p[6] }];
set_property -dict { PACKAGE_PIN A13    IOSTANDARD LVDS } [get_ports { START_p[7] }];
set_property -dict { PACKAGE_PIN E16    IOSTANDARD LVDS } [get_ports { START_p[8] }];
set_property -dict { PACKAGE_PIN K13    IOSTANDARD LVDS } [get_ports { START_p[9] }];
set_property -dict { PACKAGE_PIN G16    IOSTANDARD LVDS } [get_ports { START_p[10] }];
set_property -dict { PACKAGE_PIN G12    IOSTANDARD LVDS } [get_ports { START_p[11] }];
set_property -dict { PACKAGE_PIN C14    IOSTANDARD LVDS } [get_ports { START_p[12] }];
set_property -dict { PACKAGE_PIN E11    IOSTANDARD LVDS } [get_ports { START_p[13] }];
set_property -dict { PACKAGE_PIN B16    IOSTANDARD LVDS } [get_ports { START_p[14] }];
set_property -dict { PACKAGE_PIN H13    IOSTANDARD LVDS } [get_ports { START_p[15] }];
set_property -dict { PACKAGE_PIN D14    IOSTANDARD LVDS } [get_ports { FPGA_OUTCLK_n }];
set_property -dict { PACKAGE_PIN D15    IOSTANDARD LVDS } [get_ports { FPGA_OUTCLK_p }];
create_clock -period 5.714 -name fpga_outclk -waveform {1.000 3.857} [get_ports FPGA_OUTCLK_p]
# памерял осциллографом задержку сигнала в джиттер клинере относительно DC_CLK

set_property -dict { PACKAGE_PIN W18    IOSTANDARD LVCMOS33 } [get_ports { SER }];
set_property -dict { PACKAGE_PIN AF19   IOSTANDARD LVCMOS33 } [get_ports { SRCLK }];
set_property -dict { PACKAGE_PIN W19    IOSTANDARD LVCMOS33 } [get_ports { RCLK }];

set_property -dict { PACKAGE_PIN C7   IOSTANDARD DIFF_SSTL15 } [get_ports { SYS_CLK_n }];
set_property -dict { PACKAGE_PIN C8   IOSTANDARD DIFF_SSTL15 } [get_ports { SYS_CLK_p }];
create_clock -period 5.000 -name sysclk -waveform {0.000 2.500} [get_ports SYS_CLK_p]

set_property -dict { PACKAGE_PIN G10   IOSTANDARD LVDS } [get_ports { RXCLK_p }];
set_property -dict { PACKAGE_PIN F10   IOSTANDARD LVDS } [get_ports { RXCLK_n }];
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVDS } [get_ports { DM_CLK_p }];
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVDS } [get_ports { DM_CLK_n }];
create_clock -period 5.714 -name dm_clk -waveform {0.000 2.857} [get_ports DM_CLK_p]
set_property -dict { PACKAGE_PIN E12   IOSTANDARD LVDS } [get_ports { DC_CLK_n }];
set_property -dict { PACKAGE_PIN F12   IOSTANDARD LVDS } [get_ports { DC_CLK_p }];

set_property PACKAGE_PIN AF8 [get_ports {SFP_TX_P[0]}]
set_property PACKAGE_PIN AD8 [get_ports {SFP_RX_P[0]}]

set_property -dict { PACKAGE_PIN AA14   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_DIS[0] }];
set_property -dict { PACKAGE_PIN AA15   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_FAULT[0] }];
set_property -dict { PACKAGE_PIN AE11   IOSTANDARD LVCMOS33 } [get_ports { SFP_DETECT[0] }];
set_property -dict { PACKAGE_PIN AB12   IOSTANDARD LVCMOS33 } [get_ports { SFP_RX_LOS[0] }];
set_property -dict { PACKAGE_PIN AF10   IOSTANDARD LVCMOS33 } [get_ports { SFP_RS0 }];
set_property -dict { PACKAGE_PIN AC11   IOSTANDARD LVCMOS33 } [get_ports { SFP_RS1 }];
set_property -dict { PACKAGE_PIN  W13   IOSTANDARD LVCMOS33 } [get_ports { SFP_SDA[0] }];
set_property -dict { PACKAGE_PIN  Y13   IOSTANDARD LVCMOS33 } [get_ports { SFP_SCL[0] }];

set_property -dict { PACKAGE_PIN AE15   IOSTANDARD LVCMOS33 } [get_ports { SI570_SDA }];
set_property -dict { PACKAGE_PIN AE16   IOSTANDARD LVCMOS33 } [get_ports { SI570_SCL }];

set_property -dict { PACKAGE_PIN AD15   IOSTANDARD LVCMOS33 } [get_ports { PLL_RST_N }];
set_property -dict { PACKAGE_PIN AE13   IOSTANDARD LVCMOS33 } [get_ports { PLL1_SDA }];
set_property -dict { PACKAGE_PIN AB11   IOSTANDARD LVCMOS33 } [get_ports { PLL1_SCL }];
set_property -dict { PACKAGE_PIN AF13   IOSTANDARD LVCMOS33 } [get_ports { PLL1_IN_SEL0 }];
set_property -dict { PACKAGE_PIN AB10   IOSTANDARD LVCMOS33 } [get_ports { PLL1_IN_SEL1 }];
set_property -dict { PACKAGE_PIN AE10   IOSTANDARD LVCMOS33 } [get_ports { PLL1_LOL_N }];
set_property -dict { PACKAGE_PIN AB14   IOSTANDARD LVCMOS33 } [get_ports { PLL2_SDA }];
set_property -dict { PACKAGE_PIN AB15   IOSTANDARD LVCMOS33 } [get_ports { PLL2_SCL }];
set_property -dict { PACKAGE_PIN AD16   IOSTANDARD LVCMOS33 } [get_ports { PLL2_LOL_N }];

set_property LOC GTXE2_CHANNEL_X0Y8 [get_cells gtwizard_i/gtwizard_port_0/inst/HSSR_gtwizard_port_0_i/gt0_HSSR_gtwizard_port_0_i/gtxe2_i]

set_property RXSLIDE_MODE PMA [get_cells -regexp -hierarchical .*gtxe2_i ]

set_property PACKAGE_PIN AA6 [get_ports {REFCLK_SFP_p}]
set_property PACKAGE_PIN AA5 [get_ports {REFCLK_SFP_n}]
create_clock -add -name REFCLK_SFP -period 8.00 -waveform {0 4} [get_ports { REFCLK_SFP_p }];
set_property PACKAGE_PIN  W6 [get_ports {MGTREFCLK_p}]
set_property PACKAGE_PIN  W5 [get_ports {MGTREFCLK_n}]
create_clock -add -name MGTREFCLK -period 5.714 -waveform {0 2.857} [get_ports { MGTREFCLK_p }];
set_property LOC GTXE2_COMMON_X0Y2 [get_cells gtwizard_i/common0_i/gtxe2_common_i]

set_clock_groups -name exclusive_fpgaoutclk -physically_exclusive -group local_clk -group fpga_outclk

set_multicycle_path -setup 5 -from [get_pins {evr_i/link_slave_i/dc_control_i/sampler_i/sample_reg[*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evr_i/link_slave_i/dc_control_i/sampler_i/sample_reg[*]/C}]

set_multicycle_path -setup 5 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/topo_id_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/topo_id_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -setup 5 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/meas_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/meas_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -setup 5 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/meas_delay_rx_fsm/param_reg[1][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/meas_delay_rx_fsm/param_reg[1][*]/C}]
set_multicycle_path -setup 5 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/up_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/up_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -setup 5 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/tgt_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evr_i/link_slave_i/system_packet_reciever_i/tgt_delay_rx_fsm/param_reg[0][*]/C}]