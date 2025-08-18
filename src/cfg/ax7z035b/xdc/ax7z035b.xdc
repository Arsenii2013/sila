set_property -dict { PACKAGE_PIN AB15   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN AB14   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN AF13   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN AE13   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN Y11    IOSTANDARD LVCMOS33 } [get_ports { out_pulse[0] }];
set_property -dict { PACKAGE_PIN AC11   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[1] }];
set_property -dict { PACKAGE_PIN AA12   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[2] }];
set_property -dict { PACKAGE_PIN AF10   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[3] }];
set_property -dict { PACKAGE_PIN AC13   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[4] }];
set_property -dict { PACKAGE_PIN Y13    IOSTANDARD LVCMOS33 } [get_ports { out_pulse[5] }];
set_property -dict { PACKAGE_PIN AD11   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[6] }];
set_property -dict { PACKAGE_PIN AA14   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[7] }];
set_property -dict { PACKAGE_PIN Y10    IOSTANDARD LVCMOS33 } [get_ports { out_pulse[8] }];
set_property -dict { PACKAGE_PIN AE15   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[9] }];
set_property -dict { PACKAGE_PIN W15    IOSTANDARD LVCMOS33 } [get_ports { out_pulse[10] }];
set_property -dict { PACKAGE_PIN AC16   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[11] }];
set_property -dict { PACKAGE_PIN AD10   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[12] }];
set_property -dict { PACKAGE_PIN AE12   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[13] }];
set_property -dict { PACKAGE_PIN AB10   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[14] }];
set_property -dict { PACKAGE_PIN AB16   IOSTANDARD LVCMOS33 } [get_ports { out_pulse[15] }];

set_property -dict { PACKAGE_PIN C7   IOSTANDARD DIFF_SSTL15 } [get_ports { sysclk_n }];
set_property -dict { PACKAGE_PIN C8   IOSTANDARD DIFF_SSTL15 } [get_ports { sysclk_p }];
create_clock -period 5.000 -name sysclk -waveform {0.000 2.500} [get_ports sysclk_p]

set_property PACKAGE_PIN AF8 [get_ports {sfp_tx_p[0]}]
set_property PACKAGE_PIN AD8 [get_ports {sfp_rx_p[0]}]
set_property PACKAGE_PIN AF4 [get_ports {sfp_tx_p[1]}]
set_property PACKAGE_PIN AE6 [get_ports {sfp_rx_p[1]}]
set_property PACKAGE_PIN AE2 [get_ports {sfp_tx_p[2]}]
set_property PACKAGE_PIN AC6 [get_ports {sfp_rx_p[2]}]
set_property PACKAGE_PIN AC2 [get_ports {sfp_tx_p[3]}]
set_property PACKAGE_PIN AD4 [get_ports {sfp_rx_p[3]}]

set_property -dict { PACKAGE_PIN AF17   IOSTANDARD LVCMOS33 } [get_ports { sfp_tx_disable[0] }];
set_property -dict { PACKAGE_PIN AE17   IOSTANDARD LVCMOS33 } [get_ports { sfp_tx_disable[1] }];

set_property LOC GTXE2_CHANNEL_X0Y8 [get_cells gtwizard_i/gtwizard_8_i/inst/gtwizard_8_i/gt0_gtwizard_8_i/gtxe2_i]
set_property LOC GTXE2_CHANNEL_X0Y9 [get_cells gtwizard_i/gtwizard_9_i/inst/gtwizard_9_i/gt0_gtwizard_9_i/gtxe2_i]
set_property LOC GTXE2_CHANNEL_X0Y10 [get_cells gtwizard_i/gtwizard_10_i/inst/gtwizard_10_i/gt0_gtwizard_10_i/gtxe2_i]
set_property LOC GTXE2_CHANNEL_X0Y11 [get_cells gtwizard_i/gtwizard_11_i/inst/gtwizard_11_i/gt0_gtwizard_11_i/gtxe2_i]
set_property RXSLIDE_MODE PMA [get_cells -regexp -hierarchical .*gtxe2_i ]

set_property PACKAGE_PIN AA6 [get_ports {REFCLK_SFP_p}]
set_property PACKAGE_PIN AA5 [get_ports {REFCLK_SFP_n}]
create_clock -add -name REFCLK_SFP -period 8.00 -waveform {0 4} [get_ports { REFCLK_SFP_p }];
set_property LOC GTXE2_COMMON_X0Y2 [get_cells gtwizard_i/common0_i/gtxe2_common_i]