set_property -dict { PACKAGE_PIN AJ16   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN AK16   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN AE16   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN AE15   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

set_property -dict { PACKAGE_PIN E8   IOSTANDARD DIFF_SSTL15 } [get_ports { sysclk_n }];
set_property -dict { PACKAGE_PIN F9   IOSTANDARD DIFF_SSTL15 } [get_ports { sysclk_p }];
create_clock -period 5.000 -name sysclk -waveform {0.000 2.500} [get_ports sysclk_p]

set_property PACKAGE_PIN AH2 [get_ports {sfp_tx_p[0]}]
set_property PACKAGE_PIN AH6 [get_ports {sfp_rx_p[0]}]
set_property PACKAGE_PIN AF2 [get_ports {sfp_tx_p[1]}]
set_property PACKAGE_PIN AG4 [get_ports {sfp_rx_p[1]}]
set_property PACKAGE_PIN AE4 [get_ports {sfp_tx_p[2]}]
set_property PACKAGE_PIN AF6 [get_ports {sfp_rx_p[2]}]
set_property PACKAGE_PIN AD2 [get_ports {sfp_tx_p[3]}]
set_property PACKAGE_PIN AD6 [get_ports {sfp_rx_p[3]}]

set_property -dict { PACKAGE_PIN AE18   IOSTANDARD LVCMOS33 } [get_ports { sfp_tx_disable[0] }];
set_property -dict { PACKAGE_PIN AE17   IOSTANDARD LVCMOS33 } [get_ports { sfp_tx_disable[1] }];

set_property LOC GTXE2_CHANNEL_X0Y4 [get_cells gtwizard_i/gtwizard_port_0/inst/Fanout_gtwizard_port_0_i/gt0_Fanout_gtwizard_port_0_i/gtxe2_i]
set_property LOC GTXE2_CHANNEL_X0Y5 [get_cells gtwizard_i/gtwizard_port_1/inst/Fanout_gtwizard_port_1_i/gt0_Fanout_gtwizard_port_1_i/gtxe2_i]
set_property LOC GTXE2_CHANNEL_X0Y6 [get_cells gtwizard_i/gtwizard_port_2/inst/Fanout_gtwizard_port_2_i/gt0_Fanout_gtwizard_port_2_i/gtxe2_i]
set_property LOC GTXE2_CHANNEL_X0Y7 [get_cells gtwizard_i/gtwizard_port_3/inst/Fanout_gtwizard_port_3_i/gt0_Fanout_gtwizard_port_3_i/gtxe2_i]
set_property RXSLIDE_MODE PMA [get_cells -regexp -hierarchical .*gtxe2_i ]

set_property PACKAGE_PIN AC8 [get_ports {REFCLK_SFP_p}]
set_property PACKAGE_PIN AC7 [get_ports {REFCLK_SFP_n}]
create_clock -add -name REFCLK_SFP -period 8.00 -waveform {0 4} [get_ports { REFCLK_SFP_p }];

set_property PACKAGE_PIN U8 [get_ports {REFCLK_FROM_RX_p}]
set_property PACKAGE_PIN U7 [get_ports {REFCLK_FROM_RX_n}]
create_clock -add -name REFCLK_FROM_RX -period 8.00 -waveform {0 4} [get_ports { REFCLK_FROM_RX_p }];


set_property -dict { PACKAGE_PIN D15    IOSTANDARD DIFF_SSTL15 } [get_ports { RXCLK_p }];
set_property -dict { PACKAGE_PIN D14    IOSTANDARD DIFF_SSTL15 } [get_ports { RXCLK_n }];

set_property LOC GTXE2_COMMON_X0Y1 [get_cells gtwizard_i/common0_i/gtxe2_common_i]

set_clock_groups -name exclusive_clk0_clk1 -physically_exclusive -group clk_out1_clk_wiz -group clk_out1_clk_wiz_1