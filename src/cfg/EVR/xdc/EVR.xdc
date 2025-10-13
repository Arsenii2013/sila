set_property -dict { PACKAGE_PIN AF12   IOSTANDARD LVCMOS33 } [get_ports { LED[0] }];
set_property -dict { PACKAGE_PIN AE12   IOSTANDARD LVCMOS33 } [get_ports { LED[1] }];
set_property -dict { PACKAGE_PIN AB17   IOSTANDARD LVCMOS33 } [get_ports { LED[2] }];
set_property -dict { PACKAGE_PIN AB16   IOSTANDARD LVCMOS33 } [get_ports { LED[3] }];
set_property -dict { PACKAGE_PIN AC17   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_LINK }];
set_property -dict { PACKAGE_PIN AC16   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_ACT }];
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

set_property -dict { PACKAGE_PIN C7   IOSTANDARD DIFF_SSTL15 } [get_ports { SYS_CLK_n }];
set_property -dict { PACKAGE_PIN C8   IOSTANDARD DIFF_SSTL15 } [get_ports { SYS_CLK_p }];
create_clock -period 5.000 -name sysclk -waveform {0.000 2.500} [get_ports SYS_CLK_p]

set_property PACKAGE_PIN AF8 [get_ports {SFP_TX_P[0]}]
set_property PACKAGE_PIN AD8 [get_ports {SFP_RX_P[0]}]

set_property -dict { PACKAGE_PIN AA14   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_DIS }];

set_property LOC GTXE2_CHANNEL_X0Y8 [get_cells gtwizard_i/gtwizard_port_0/inst/EVR_gtwizard_port_0_i/gt0_EVR_gtwizard_port_0_i/gtxe2_i]

set_property RXSLIDE_MODE PMA [get_cells -regexp -hierarchical .*gtxe2_i ]

set_property PACKAGE_PIN AA6 [get_ports {REFCLK_SFP_p}]
set_property PACKAGE_PIN AA5 [get_ports {REFCLK_SFP_n}]
create_clock -add -name REFCLK_SFP -period 8.00 -waveform {0 4} [get_ports { REFCLK_SFP_p }];
set_property LOC GTXE2_COMMON_X0Y2 [get_cells gtwizard_i/common0_i/gtxe2_common_i]

set_clock_groups -name exclusive_clk0_clk1 -physically_exclusive -group clk_out1_clk_wiz -group clk_out1_clk_wiz_1