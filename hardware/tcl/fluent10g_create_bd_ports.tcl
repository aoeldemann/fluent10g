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
# Creates block design ports.

# FPGA_SYSCLK (200 MHz)
create_bd_port -dir I -type clk fpga_sysclk_p
create_bd_port -dir I -type clk fpga_sysclk_n

# DDR3_SYSCLK (233.33 MHz)
create_bd_port -dir I -type clk ddr3_sysclk_p
create_bd_port -dir I -type clk ddr3_sysclk_n

# PCIE_SYSCLK (100 MHz)
create_bd_port -dir I -type clk pcie_sysclk_p
create_bd_port -dir I -type clk pcie_sysclk_n

# SFP_CLK (156.25 MHz)
create_bd_port -dir I -type clk sfp_clk_p
create_bd_port -dir I -type clk sfp_clk_n

# fpga reset
create_bd_port -dir I -type rst reset
set_property -dict [list CONFIG.POLARITY {ACTIVE_HIGH}] [get_bd_ports reset]

# PCIE reset
create_bd_port -dir I pcie_sys_resetn

# PCIE lanes
create_bd_port -dir O -from 0 -to 7 pcie_7x_mgt_txn
create_bd_port -dir O -from 0 -to 7 pcie_7x_mgt_txp
create_bd_port -dir I -from 0 -to 7 pcie_7x_mgt_rxp
create_bd_port -dir I -from 0 -to 7 pcie_7x_mgt_rxn

# mig ddr3A
create_bd_port -dir IO -from 63 -to 0 ddr3a_dq
create_bd_port -dir IO -from 7  -to 0 ddr3a_dqs_n
create_bd_port -dir IO -from 7  -to 0 ddr3a_dqs_p
create_bd_port -dir O  -from 15 -to 0 ddr3a_addr
create_bd_port -dir O  -from 3  -to 0 ddr3a_ba
create_bd_port -dir O ddr3a_ras_n
create_bd_port -dir O ddr3a_cas_n
create_bd_port -dir O ddr3a_we_n
create_bd_port -dir O ddr3a_reset_n
create_bd_port -dir O ddr3a_ck_p
create_bd_port -dir O ddr3a_ck_n
create_bd_port -dir O ddr3a_cke
create_bd_port -dir O ddr3a_cs_n
create_bd_port -dir O  -from 7 -to 0 ddr3a_dm
create_bd_port -dir O ddr3a_odt

# mig ddr3B
create_bd_port -dir IO -from 63 -to 0 ddr3b_dq
create_bd_port -dir IO -from 7  -to 0 ddr3b_dqs_n
create_bd_port -dir IO -from 7  -to 0 ddr3b_dqs_p
create_bd_port -dir O  -from 15 -to 0 ddr3b_addr
create_bd_port -dir O  -from 3  -to 0 ddr3b_ba
create_bd_port -dir O ddr3b_ras_n
create_bd_port -dir O ddr3b_cas_n
create_bd_port -dir O ddr3b_we_n
create_bd_port -dir O ddr3b_reset_n
create_bd_port -dir O ddr3b_ck_p
create_bd_port -dir O ddr3b_ck_n
create_bd_port -dir O ddr3b_cke
create_bd_port -dir O ddr3b_cs_n
create_bd_port -dir O  -from 7 -to 0 ddr3b_dm
create_bd_port -dir O ddr3b_odt

# network if 0
create_bd_port -dir O if0_rx_led
create_bd_port -dir O if0_tx_led
create_bd_port -dir I if0_tx_abs
create_bd_port -dir I if0_tx_fault
create_bd_port -dir O if0_tx_disable
create_bd_port -dir I if0_rxn
create_bd_port -dir I if0_rxp
create_bd_port -dir O if0_txn
create_bd_port -dir O if0_txp

# network if 1
create_bd_port -dir O if1_rx_led
create_bd_port -dir O if1_tx_led
create_bd_port -dir I if1_tx_abs
create_bd_port -dir I if1_tx_fault
create_bd_port -dir O if1_tx_disable
create_bd_port -dir I if1_rxn
create_bd_port -dir I if1_rxp
create_bd_port -dir O if1_txn
create_bd_port -dir O if1_txp

# network if 2
create_bd_port -dir O if2_rx_led
create_bd_port -dir O if2_tx_led
create_bd_port -dir I if2_tx_abs
create_bd_port -dir I if2_tx_fault
create_bd_port -dir O if2_tx_disable
create_bd_port -dir I if2_rxn
create_bd_port -dir I if2_rxp
create_bd_port -dir O if2_txn
create_bd_port -dir O if2_txp

# network if 3
create_bd_port -dir O if3_rx_led
create_bd_port -dir O if3_tx_led
create_bd_port -dir I if3_tx_abs
create_bd_port -dir I if3_tx_fault
create_bd_port -dir O if3_tx_disable
create_bd_port -dir I if3_rxn
create_bd_port -dir I if3_rxp
create_bd_port -dir O if3_txn
create_bd_port -dir O if3_txp
