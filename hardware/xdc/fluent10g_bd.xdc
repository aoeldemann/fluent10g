# The MIT License
#
# Copyright (c) 2017-2018 by the author(s)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Author(s):
#   - Andreas Oeldemann <andreas.oeldemann@tum.de>
#
# Description:
#
# Constraint file

set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS FALSE [current_design]

# FPGA_SYSCLK (200 MHz)
set_property PACKAGE_PIN G18 [get_ports fpga_sysclk_n]
set_property PACKAGE_PIN H19 [get_ports fpga_sysclk_p]
set_property VCCAUX_IO DONTCARE [get_ports fpga_sysclk_n]
set_property VCCAUX_IO DONTCARE [get_ports fpga_sysclk_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports fpga_sysclk_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports fpga_sysclk_n]
create_clock -period 5.000 -name fpga_sysclk [get_ports fpga_sysclk_p]

# DDR3_SYSCLK (233.33 MHz)
set_property PACKAGE_PIN E35 [get_ports ddr3_sysclk_n]
set_property PACKAGE_PIN E34 [get_ports ddr3_sysclk_p]
set_property VCCAUX_IO DONTCARE [get_ports ddr3_sysclk_n]
set_property VCCAUX_IO DONTCARE [get_ports ddr3_sysclk_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports ddr3_sysclk_n]
set_property IOSTANDARD DIFF_SSTL15 [get_ports ddr3_sysclk_p]
create_clock -period 4.288 -name ddr3_sysclk [get_ports ddr3_sysclk_p]

# PCIE_SYSCLK (100 MHz)
set_property PACKAGE_PIN AB7 [get_ports pcie_sysclk_n]
set_property PACKAGE_PIN AB8 [get_ports pcie_sysclk_p]
set_property LOC IBUFDS_GTE2_X1Y11 [get_cells fluent10g_i/pcie_0/util_ds_buf_0/U0/USE_IBUFDS_GTE2.GEN_IBUFDS_GTE2[0].IBUFDS_GTE2_I]
create_clock -period 10.000 -name pcie_sysclk \
  [get_pins -hier -filter name=~*IBUFDS_GTE2*/O]

# SFP_SYSCLK (156.25 MHz)
set_property PACKAGE_PIN E10 [get_ports sfp_clk_p]
set_property PACKAGE_PIN E9 [get_ports sfp_clk_n]

# reset
set_property PACKAGE_PIN AR13 [get_ports reset]
set_property IOSTANDARD LVCMOS15 [get_ports reset]
set_false_path -from [get_ports reset]

# PCIE reset
set_property PACKAGE_PIN AY35 [get_ports pcie_sys_resetn]
set_property IOSTANDARD LVCMOS18 [get_ports pcie_sys_resetn]
set_property PULLUP true [get_ports pcie_sys_resetn]
set_false_path -from [get_ports pcie_sys_resetn]

# pcie contraints
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets fluent10g_i/pcie_0/xdma_0/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/pipe_txoutclk_out]

# ddr3 constraints
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets ddr3_sysclk_p]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_pins -hierarchical *pll*CLKIN1]
set_property CLOCK_DEDICATED_ROUTE FALSE \
  [get_pins -hierarchical *clk_ref_mmcm_gen.mmcm_i*CLKIN1]

# network interface 0
set_property PACKAGE_PIN M18 [get_ports if0_tx_disable]
set_property IOSTANDARD LVCMOS15 [get_ports if0_tx_disable]
set_property PACKAGE_PIN M19 [get_ports if0_tx_fault]
set_property IOSTANDARD LVCMOS15 [get_ports if0_tx_fault]
set_property PACKAGE_PIN N18 [get_ports if0_tx_abs]
set_property IOSTANDARD LVCMOS15 [get_ports if0_tx_abs]
set_property PACKAGE_PIN G13  [get_ports if0_tx_led]
set_property IOSTANDARD LVCMOS15 [get_ports if0_tx_led]
set_property PACKAGE_PIN L15  [get_ports if0_rx_led]
set_property IOSTANDARD LVCMOS15 [get_ports if0_rx_led]
set_property LOC GTHE2_CHANNEL_X1Y39 \
  [get_cells -hier -filter name=~*if_0*gthe2_i]

# network interface 1
set_property PACKAGE_PIN B31 [get_ports if1_tx_disable]
set_property IOSTANDARD LVCMOS15 [get_ports if1_tx_disable]
set_property PACKAGE_PIN C26 [get_ports if1_tx_fault]
set_property IOSTANDARD LVCMOS15 [get_ports if1_tx_fault]
set_property PACKAGE_PIN L19 [get_ports if1_tx_abs]
set_property IOSTANDARD LVCMOS15 [get_ports if1_tx_abs]
set_property PACKAGE_PIN AL22  [get_ports if1_tx_led]
set_property IOSTANDARD LVCMOS15 [get_ports if1_tx_led]
set_property PACKAGE_PIN BA20  [get_ports if1_rx_led]
set_property IOSTANDARD LVCMOS15 [get_ports if1_rx_led]
set_property LOC GTHE2_CHANNEL_X1Y38 \
  [get_cells -hier -filter name=~*if_1*gthe2_i]

# network interface 2
set_property PACKAGE_PIN J38 [get_ports if2_tx_disable]
set_property IOSTANDARD LVCMOS15 [get_ports if2_tx_disable]
set_property PACKAGE_PIN E39 [get_ports if2_tx_fault]
set_property IOSTANDARD LVCMOS15 [get_ports if2_tx_fault]
set_property PACKAGE_PIN J37 [get_ports if2_tx_abs]
set_property IOSTANDARD LVCMOS15 [get_ports if2_tx_abs]
set_property PACKAGE_PIN AY18  [get_ports if2_tx_led]
set_property IOSTANDARD LVCMOS15 [get_ports if2_tx_led]
set_property PACKAGE_PIN AY17  [get_ports if2_rx_led]
set_property IOSTANDARD LVCMOS15 [get_ports if2_rx_led]
set_property LOC GTHE2_CHANNEL_X1Y37 \
  [get_cells -hier -filter name=~*if_2*gthe2_i]

# network interface 3
set_property PACKAGE_PIN L21 [get_ports if3_tx_disable]
set_property IOSTANDARD LVCMOS15 [get_ports if3_tx_disable]
set_property PACKAGE_PIN J26 [get_ports if3_tx_fault]
set_property IOSTANDARD LVCMOS15 [get_ports if3_tx_fault]
set_property PACKAGE_PIN H36 [get_ports if3_tx_abs]
set_property IOSTANDARD LVCMOS15 [get_ports if3_tx_abs]
set_property PACKAGE_PIN P31  [get_ports if3_tx_led]
set_property IOSTANDARD LVCMOS15 [get_ports if3_tx_led]
set_property PACKAGE_PIN K32  [get_ports if3_rx_led]
set_property IOSTANDARD LVCMOS15 [get_ports if3_rx_led]
set_property LOC GTHE2_CHANNEL_X1Y36 \
  [get_cells -hier -filter name=~*if_3*gthe2_i]

# false paths
set_false_path -from [get_clocks sfp_clk_p] -to \
  [get_clocks clk_out1_fluent10g_clk_wiz_0_0]
set_false_path -from [get_clocks clk_out1_fluent10g_clk_wiz_0_0] -to \
  [get_clocks sfp_clk_p]
set_false_path -from [get_clocks userclk1] -to [get_clocks pcie_sysclk]
set_false_path -from [get_clocks pcie_sysclk] -to [get_clocks userclk1]
set_false_path -from [get_clocks userclk1] -to [get_clocks sfp_clk_p]
set_false_path -from [get_clocks sfp_clk_p] -to [get_clocks userclk1]
set_false_path -from [get_clocks userclk1] -to \
  [get_clocks clk_out1_fluent10g_clk_wiz_0_0]
set_false_path -from [get_clocks clk_out1_fluent10g_clk_wiz_0_0] -to \
  [get_clocks userclk1]
set_false_path -from [get_clocks rxclk_125mhz_x0y1] -to [get_clocks userclk2]
set_false_path -from [get_clocks rxclk_250mhz_x0y1] -to [get_clocks userclk2]
set_false_path -from [get_clocks rxclk_rxout_x0y1] -to [get_clocks userclk2]
