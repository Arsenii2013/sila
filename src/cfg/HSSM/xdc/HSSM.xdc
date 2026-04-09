set_property -dict {PACKAGE_PIN AE23 IOSTANDARD LVCMOS33} [get_ports {LED[0]}]
set_property -dict {PACKAGE_PIN AD26 IOSTANDARD LVCMOS33} [get_ports {LED[1]}]
set_property -dict {PACKAGE_PIN AD23 IOSTANDARD LVCMOS33} [get_ports {LED[2]}]
set_property -dict {PACKAGE_PIN AC26 IOSTANDARD LVCMOS33} [get_ports {LED[3]}]

set_property -dict {PACKAGE_PIN AF23 IOSTANDARD LVCMOS33} [get_ports {KEY_POWER}]
set_property -dict {PACKAGE_PIN AF24 IOSTANDARD LVCMOS33} [get_ports {POWER_OFF}]


set_property -dict {PACKAGE_PIN AJ24 IOSTANDARD LVCMOS33} [get_ports {SFP_LED_LINK[0]}]
set_property -dict {PACKAGE_PIN AJ21 IOSTANDARD LVCMOS33} [get_ports {SFP_LED_ACT[0]}]
set_property -dict {PACKAGE_PIN AK23 IOSTANDARD LVCMOS33} [get_ports {SFP_LED_LINK[1]}]
set_property -dict {PACKAGE_PIN AH24 IOSTANDARD LVCMOS33} [get_ports {SFP_LED_ACT[1]}]
set_property -dict {PACKAGE_PIN AJ20 IOSTANDARD LVCMOS33} [get_ports {SFP_LED_LINK[2]}]
set_property -dict {PACKAGE_PIN AH21 IOSTANDARD LVCMOS33} [get_ports {SFP_LED_ACT[2]}]
set_property -dict {PACKAGE_PIN AG20 IOSTANDARD LVCMOS33} [get_ports {SFP_LED_LINK[3]}]
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS33} [get_ports {SFP_LED_ACT[3]}]
set_property -dict { PACKAGE_PIN AG17   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_LINK[4] }];
set_property -dict { PACKAGE_PIN AH18   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_ACT[4] }];
set_property -dict { PACKAGE_PIN AJ16   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_LINK[5] }];
set_property -dict { PACKAGE_PIN AE16   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_ACT[5] }];
set_property -dict { PACKAGE_PIN AA15   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_LINK[6] }];
set_property -dict { PACKAGE_PIN AD16   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_ACT[6] }];
set_property -dict { PACKAGE_PIN AG15   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_LINK[7] }];
set_property -dict { PACKAGE_PIN AK13   IOSTANDARD LVCMOS33 } [get_ports { SFP_LED_ACT[7] }];


set_property -dict {PACKAGE_PIN E8 IOSTANDARD DIFF_SSTL15} [get_ports SYS_CLK_n]
set_property -dict {PACKAGE_PIN F9 IOSTANDARD DIFF_SSTL15} [get_ports SYS_CLK_p]
create_clock -period 5.000 -name sysclk -waveform {0.000 2.500} [get_ports SYS_CLK_p]

set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVDS} [get_ports RXCLK_p]
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVDS} [get_ports RXCLK_n]
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVDS} [get_ports DM_CLK_p]
set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVDS} [get_ports DM_CLK_n]
create_clock -period 5.714 -name dm_clk -waveform {0.000 2.857 } [get_ports DM_CLK_p]

set_property PACKAGE_PIN N4  [get_ports {SFP_TX_P[4]}]
set_property PACKAGE_PIN P6  [get_ports {SFP_RX_P[4]}]
set_property PACKAGE_PIN P2  [get_ports {SFP_TX_P[5]}]
set_property PACKAGE_PIN T6  [get_ports {SFP_RX_P[5]}]
set_property PACKAGE_PIN R4  [get_ports {SFP_TX_P[6]}]
set_property PACKAGE_PIN U4  [get_ports {SFP_RX_P[6]}]
set_property PACKAGE_PIN T2  [get_ports {SFP_TX_P[7]}]
set_property PACKAGE_PIN V6  [get_ports {SFP_RX_P[7]}]

set_property -dict {PACKAGE_PIN AB17 IOSTANDARD LVCMOS33} [get_ports SFP_RS0]
set_property -dict {PACKAGE_PIN AB16 IOSTANDARD LVCMOS33} [get_ports SFP_RS1]

set_property -dict {PACKAGE_PIN AC14 IOSTANDARD LVCMOS33} [get_ports {SFP_TX_DIS[0]}]
set_property -dict {PACKAGE_PIN AC13 IOSTANDARD LVCMOS33} [get_ports {SFP_TX_FAULT[0]}]
set_property -dict {PACKAGE_PIN AE12 IOSTANDARD LVCMOS33} [get_ports {SFP_RX_LOS[0]}]
set_property -dict {PACKAGE_PIN AG12 IOSTANDARD LVCMOS33} [get_ports {SFP_TX_DIS[1]}]
set_property -dict {PACKAGE_PIN AF12 IOSTANDARD LVCMOS33} [get_ports {SFP_TX_FAULT[1]}]
set_property -dict {PACKAGE_PIN AH12 IOSTANDARD LVCMOS33} [get_ports {SFP_RX_LOS[1]}]
set_property -dict {PACKAGE_PIN AH14 IOSTANDARD LVCMOS33} [get_ports {SFP_TX_DIS[2]}]
set_property -dict {PACKAGE_PIN AH13 IOSTANDARD LVCMOS33} [get_ports {SFP_TX_FAULT[2]}]
set_property -dict {PACKAGE_PIN AB12 IOSTANDARD LVCMOS33} [get_ports {SFP_RX_LOS[2]}]
set_property -dict {PACKAGE_PIN AD13 IOSTANDARD LVCMOS33} [get_ports {SFP_TX_DIS[3]}]
set_property -dict {PACKAGE_PIN AC12 IOSTANDARD LVCMOS33} [get_ports {SFP_TX_FAULT[3]}]
set_property -dict {PACKAGE_PIN AD14 IOSTANDARD LVCMOS33} [get_ports {SFP_RX_LOS[3]}]
set_property -dict { PACKAGE_PIN AF13   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_DIS[4] }];
set_property -dict { PACKAGE_PIN AE13   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_FAULT[4] }];
set_property -dict { PACKAGE_PIN AJ13   IOSTANDARD LVCMOS33 } [get_ports { SFP_RX_LOS[4] }];
set_property -dict { PACKAGE_PIN AB14   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_DIS[5] }];
set_property -dict { PACKAGE_PIN AJ14   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_FAULT[5] }];
set_property -dict { PACKAGE_PIN AB15   IOSTANDARD LVCMOS33 } [get_ports { SFP_RX_LOS[5] }];
set_property -dict { PACKAGE_PIN AF14   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_DIS[6] }];
set_property -dict { PACKAGE_PIN AG14   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_FAULT[6] }];
set_property -dict { PACKAGE_PIN AC16   IOSTANDARD LVCMOS33 } [get_ports { SFP_RX_LOS[6] }];
set_property -dict { PACKAGE_PIN AJ15   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_DIS[7] }];
set_property -dict { PACKAGE_PIN AC17   IOSTANDARD LVCMOS33 } [get_ports { SFP_TX_FAULT[7] }];
set_property -dict { PACKAGE_PIN AK15   IOSTANDARD LVCMOS33 } [get_ports { SFP_RX_LOS[7] }];

set_property -dict {PACKAGE_PIN AJ23 IOSTANDARD LVCMOS33} [get_ports {SFP_SDA[0]}]
set_property -dict {PACKAGE_PIN AK21 IOSTANDARD LVCMOS33} [get_ports {SFP_SCL[0]}]
set_property -dict {PACKAGE_PIN AK22 IOSTANDARD LVCMOS33} [get_ports {SFP_SDA[1]}]
set_property -dict {PACKAGE_PIN AH23 IOSTANDARD LVCMOS33} [get_ports {SFP_SCL[1]}]
set_property -dict {PACKAGE_PIN AK20 IOSTANDARD LVCMOS33} [get_ports {SFP_SDA[2]}]
set_property -dict {PACKAGE_PIN AG21 IOSTANDARD LVCMOS33} [get_ports {SFP_SCL[2]}]
set_property -dict {PACKAGE_PIN AF20 IOSTANDARD LVCMOS33} [get_ports {SFP_SDA[3]}]
set_property -dict {PACKAGE_PIN AB22 IOSTANDARD LVCMOS33} [get_ports {SFP_SCL[3]}]
set_property -dict {PACKAGE_PIN AG16 IOSTANDARD LVCMOS33} [get_ports {SFP_SDA[4]}]
set_property -dict {PACKAGE_PIN AJ18 IOSTANDARD LVCMOS33} [get_ports {SFP_SCL[4]}]
set_property -dict {PACKAGE_PIN AK16 IOSTANDARD LVCMOS33} [get_ports {SFP_SDA[5]}]
set_property -dict {PACKAGE_PIN AE15 IOSTANDARD LVCMOS33} [get_ports {SFP_SCL[5]}]
set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVCMOS33} [get_ports {SFP_SDA[6]}]
set_property -dict {PACKAGE_PIN AD15 IOSTANDARD LVCMOS33} [get_ports {SFP_SCL[6]}]
set_property -dict {PACKAGE_PIN AF15 IOSTANDARD LVCMOS33} [get_ports {SFP_SDA[7]}]
set_property -dict {PACKAGE_PIN AK12 IOSTANDARD LVCMOS33} [get_ports {SFP_SCL[7]}]

set_property -dict {PACKAGE_PIN AC24 IOSTANDARD LVCMOS33} [get_ports SI570_SDA]
set_property -dict {PACKAGE_PIN AA24 IOSTANDARD LVCMOS33} [get_ports SI570_SCL]

set_property -dict {PACKAGE_PIN Y23 IOSTANDARD LVCMOS33} [get_ports PLL_RST_N]
set_property -dict {PACKAGE_PIN AA23 IOSTANDARD LVCMOS33} [get_ports PLL_SDA]
set_property -dict {PACKAGE_PIN AA22 IOSTANDARD LVCMOS33} [get_ports PLL_SCL]
set_property -dict {PACKAGE_PIN AF29 IOSTANDARD LVCMOS33} [get_ports PLL_IN_SEL0]
set_property -dict {PACKAGE_PIN AB24 IOSTANDARD LVCMOS33} [get_ports PLL_IN_SEL1]
set_property -dict {PACKAGE_PIN Y22 IOSTANDARD LVCMOS33} [get_ports PLL_LOL_N]

set_property -dict { PACKAGE_PIN B14    IOSTANDARD LVDS } [get_ports { EXTIN_p[0] }];
set_property -dict { PACKAGE_PIN B15    IOSTANDARD LVDS } [get_ports { EXTIN_p[1] }];
set_property -dict { PACKAGE_PIN F15    IOSTANDARD LVDS } [get_ports { EXTIN_p[2] }];
set_property -dict { PACKAGE_PIN E13    IOSTANDARD LVDS } [get_ports { EXTIN_p[3] }];

set_property LOC GTXE2_CHANNEL_X0Y7 [get_cells gtwizard_i/gtwizard_port_0/inst/HSSM_gtwizard_port_0_i/gt0_HSSM_gtwizard_port_0_i/gtxe2_i]
set_property PACKAGE_PIN AD6 [get_ports {SFP_RX_P[0]}]
set_property PACKAGE_PIN AD2 [get_ports {SFP_TX_P[0]}]
set_property LOC GTXE2_CHANNEL_X0Y6 [get_cells gtwizard_i/gtwizard_port_1/inst/HSSM_gtwizard_port_1_i/gt0_HSSM_gtwizard_port_1_i/gtxe2_i]
set_property PACKAGE_PIN AF6 [get_ports {SFP_RX_P[1]}]
set_property PACKAGE_PIN AE4 [get_ports {SFP_TX_P[1]}]
set_property LOC GTXE2_CHANNEL_X0Y5 [get_cells gtwizard_i/gtwizard_port_2/inst/HSSM_gtwizard_port_2_i/gt0_HSSM_gtwizard_port_2_i/gtxe2_i]
set_property PACKAGE_PIN AG4 [get_ports {SFP_RX_P[2]}]
set_property PACKAGE_PIN AF2 [get_ports {SFP_TX_P[2]}]
set_property LOC GTXE2_CHANNEL_X0Y4 [get_cells gtwizard_i/gtwizard_port_3/inst/HSSM_gtwizard_port_3_i/gt0_HSSM_gtwizard_port_3_i/gtxe2_i]
set_property PACKAGE_PIN AH6 [get_ports {SFP_RX_P[3]}]
set_property PACKAGE_PIN AH2 [get_ports {SFP_TX_P[3]}]
set_property RXSLIDE_MODE PMA [get_cells -regexp -hierarchical .*gtxe2_i]

set_property PACKAGE_PIN AC8 [get_ports REFCLK_SFP_p]
set_property PACKAGE_PIN AC7 [get_ports REFCLK_SFP_n]
create_clock -period 8.000 -name REFCLK_SFP -waveform {0.000 4.000} -add [get_ports REFCLK_SFP_p]
set_property PACKAGE_PIN U8 [get_ports REFCLK_p]
set_property PACKAGE_PIN U7 [get_ports REFCLK_n]
create_clock -period 5.714 -name REFCLK -waveform {0.000 2.857} -add [get_ports REFCLK_p]
set_property LOC GTXE2_COMMON_X0Y1 [get_cells gtwizard_i/common0_i/gtxe2_common_i]
set_property LOC GTXE2_COMMON_X0Y3 [get_cells gtwizard_i/common1_i/gtxe2_common_i]

set_property -dict {PACKAGE_PIN AJ28 IOSTANDARD LVCMOS33} [get_ports PHY0_RST]
set_property -dict {PACKAGE_PIN AJ29 IOSTANDARD LVCMOS33} [get_ports PHY1_RST]


set_property -dict {PACKAGE_PIN AD30 IOSTANDARD LVCMOS33} [get_ports {TIME_UART_TX}]
set_property -dict {PACKAGE_PIN AG29 IOSTANDARD LVCMOS33} [get_ports {TIME_UART_RX}]

# 5 - время пересинхронизации valid сигнала
# 1024 - период измерения sample. 1018 = 1024 - 5 - 1
set_multicycle_path -setup 5    -from [get_pins {evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/sample_reg[*]/C}]
set_multicycle_path -hold  1018 -from [get_pins {evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/sample_reg[*]/C}]
set_multicycle_path -setup 5    -from [get_pins {evg_i/link_master_insts[*].link_master_i/system_packet_reciever_i/sub_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -hold  1018 -from [get_pins {evg_i/link_master_insts[*].link_master_i/system_packet_reciever_i/sub_delay_rx_fsm/param_reg[0][*]/C}]
set_false_path -to [get_pins evg_i/BUFGMUX_CTRL_inst/S0]
set_false_path -to [get_pins evg_i/BUFGMUX_CTRL_inst/S1]

set_clock_groups -name exclusive_local_clk -physically_exclusive \ 
-group [get_clocks local_clk] \
-group [get_clocks gtwizard_i/gtwizard_port_0/inst/HSSM_gtwizard_port_0_i/gt0_HSSM_gtwizard_port_0_i/gtxe2_i/TXOUTCLK]


set_multicycle_path -setup 5 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/dc_control_i/sampler_i/sample_reg[*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/dc_control_i/sampler_i/sample_reg[*]/C}]
set_multicycle_path -setup 5 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/topo_id_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/topo_id_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -setup 5 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/meas_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/meas_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -setup 5 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/meas_delay_rx_fsm/param_reg[1][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/meas_delay_rx_fsm/param_reg[1][*]/C}]
set_multicycle_path -setup 5 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/up_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/up_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -setup 5 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/tgt_delay_rx_fsm/param_reg[0][*]/C}]
set_multicycle_path -hold  4 -from [get_pins {evg_i/link_master_insts[0].link_slave_i/system_packet_reciever_i/tgt_delay_rx_fsm/param_reg[0][*]/C}]

set_case_analysis 0 [get_pins evg_i/BUFGMUX_CTRL_inst/S0]
set_case_analysis 1 [get_pins evg_i/BUFGMUX_CTRL_inst/S1]

set_false_path \
-from [get_pins evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/beacon_cdc_i/start_expand_reg/C] \
-to [get_pins evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/beacon_cdc_i/start_syncstage_ff_reg[0]/D]
set_max_delay 5.714 -datapath_only \
-from [get_pins evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/beacon_cdc_i/start_expand_reg/C] \
-to [get_pins evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/beacon_cdc_i/start_syncstage_ff_reg[0]/D]
set_false_path \
-from [get_pins evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/beacon_cdc_i/stop_expand_reg/C] \
-to [get_pins evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/beacon_cdc_i/stop_syncstage_ff_reg[0]/D]
set_max_delay 5.714 -datapath_only \
-from [get_pins evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/beacon_cdc_i/stop_expand_reg/C] \
-to [get_pins evg_i/link_master_insts[*].link_master_i/measure_i/sampler_i/beacon_cdc_i/stop_syncstage_ff_reg[0]/D]