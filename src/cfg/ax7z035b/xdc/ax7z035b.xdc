set_property -dict { PACKAGE_PIN AB15   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN AB14   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN AF13   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN AE13   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

set_property -dict { PACKAGE_PIN C7   IOSTANDARD DIFF_SSTL15 } [get_ports { sysclk_n }];
set_property -dict { PACKAGE_PIN C8   IOSTANDARD DIFF_SSTL15 } [get_ports { sysclk_p }];
create_clock -period 5.000 -name sysclk -waveform {0.000 2.500} [get_ports sysclk_p]
