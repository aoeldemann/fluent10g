# The MIT License
#
# Copyright (c) 2017-2019 by the author(s)
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
# Connect block design IP cores.

# connect FPGA_SYSCLK and DDR3_SYSCLK inputs to clock buffers
connect_bd_net [get_bd_ports fpga_sysclk_p] \
  [get_bd_pins clkbuf_fpga_sysclk/IBUF_DS_P]
connect_bd_net [get_bd_ports fpga_sysclk_n] \
  [get_bd_pins clkbuf_fpga_sysclk/IBUF_DS_N]
connect_bd_net [get_bd_ports ddr3_sysclk_p] \
  [get_bd_pins clkbuf_ddr3_sysclk/IBUF_DS_P]
connect_bd_net [get_bd_ports ddr3_sysclk_n] \
  [get_bd_pins clkbuf_ddr3_sysclk/IBUF_DS_N]

# connect PCIE_SYSCLK to PCIE core
connect_bd_net [get_bd_ports pcie_sysclk_n] [get_bd_pins pcie_0/pcie_sysclk_n]
connect_bd_net [get_bd_ports pcie_sysclk_p] [get_bd_pins pcie_0/pcie_sysclk_p]

# connect reset system
connect_bd_net [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_ports reset] [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_ports reset] [get_bd_pins clk_wiz_0/reset]
connect_bd_net [get_bd_ports reset] [get_bd_pins if_0/reset]
connect_bd_net [get_bd_pins clk_wiz_0/locked] \
  [get_bd_pins proc_sys_reset_0/dcm_locked]

# connect PCIE reset
connect_bd_net [get_bd_ports pcie_sys_resetn] \
  [get_bd_pins pcie_0/pcie_sys_resetn]

# connect sfp clock reset to inverter
connect_bd_net [get_bd_pins inverter_clk156_rst/Op1] \
  [get_bd_pins if_0/areset_clk156_out]

# AND rstn and rstn_sw
connect_bd_net [get_bd_pins rstn_combined/Op1] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins rstn_combined/Op2] \
  [get_bd_pins nt_ctrl/rstn_sw]

# AND rstn156 and rstn156_sw
connect_bd_net [get_bd_pins rstn156_combined/Op1] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins rstn156_combined/Op2] \
  [get_bd_pins nt_ctrl/rstn_sw156]

# connect clocks to MIGs
connect_bd_net [get_bd_pins clkbuf_fpga_sysclk/IBUF_OUT] \
  [get_bd_pins mig_ddr3A/clk_ref_i]
connect_bd_net [get_bd_pins clkbuf_fpga_sysclk/IBUF_OUT] \
  [get_bd_pins mig_ddr3B/clk_ref_i]
connect_bd_net [get_bd_pins clkbuf_ddr3_sysclk/IBUF_OUT] \
  [get_bd_pins mig_ddr3A/sys_clk_i]
connect_bd_net [get_bd_pins clkbuf_ddr3_sysclk/IBUF_OUT] \
  [get_bd_pins mig_ddr3B/sys_clk_i]

# connect MIG resets
connect_bd_net [get_bd_pins inverter_mig_ddr3A_rst/Op1] \
  [get_bd_pins mig_ddr3A/ui_clk_sync_rst]
connect_bd_net [get_bd_pins inverter_mig_ddr3B_rst/Op1] \
  [get_bd_pins mig_ddr3B/ui_clk_sync_rst]
connect_bd_net [get_bd_pins inverter_mig_ddr3A_rst/Res] \
  [get_bd_pins mig_ddr3A/aresetn]
connect_bd_net [get_bd_pins inverter_mig_ddr3B_rst/Res] \
  [get_bd_pins mig_ddr3B/aresetn]
connect_bd_net [get_bd_ports reset] [get_bd_pins mig_ddr3A/sys_rst]
connect_bd_net [get_bd_ports reset] [get_bd_pins mig_ddr3B/sys_rst]

# connect mig ddr3A ui clk to clock generator input
connect_bd_net [get_bd_pins mig_ddr3A/ui_clk] [get_bd_pins clk_wiz_0/clk_in1]

# connect mig ddr3A + ddr3B device_temp_i to constant 0
connect_bd_net [get_bd_pins mig_device_temp_i_constant/dout] \
  [get_bd_pins mig_ddr3A/device_temp_i]
connect_bd_net [get_bd_pins mig_device_temp_i_constant/dout] \
  [get_bd_pins mig_ddr3B/device_temp_i]

# connect mig ddr3A to external ports
connect_bd_net [get_bd_ports ddr3a_dq] [get_bd_pins mig_ddr3A/ddr3_dq]
connect_bd_net [get_bd_ports ddr3a_dqs_n] [get_bd_pins mig_ddr3A/ddr3_dqs_n]
connect_bd_net [get_bd_ports ddr3a_dqs_p] [get_bd_pins mig_ddr3A/ddr3_dqs_p]
connect_bd_net [get_bd_ports ddr3a_addr] [get_bd_pins mig_ddr3A/ddr3_addr]
connect_bd_net [get_bd_ports ddr3a_ba] [get_bd_pins mig_ddr3A/ddr3_ba]
connect_bd_net [get_bd_ports ddr3a_ras_n] [get_bd_pins mig_ddr3A/ddr3_ras_n]
connect_bd_net [get_bd_ports ddr3a_cas_n] [get_bd_pins mig_ddr3A/ddr3_cas_n]
connect_bd_net [get_bd_ports ddr3a_we_n] [get_bd_pins mig_ddr3A/ddr3_we_n]
connect_bd_net [get_bd_ports ddr3a_reset_n] [get_bd_pins mig_ddr3A/ddr3_reset_n]
connect_bd_net [get_bd_ports ddr3a_ck_p] [get_bd_pins mig_ddr3A/ddr3_ck_p]
connect_bd_net [get_bd_ports ddr3a_ck_n] [get_bd_pins mig_ddr3A/ddr3_ck_n]
connect_bd_net [get_bd_ports ddr3a_cke] [get_bd_pins mig_ddr3A/ddr3_cke]
connect_bd_net [get_bd_ports ddr3a_cs_n] [get_bd_pins mig_ddr3A/ddr3_cs_n]
connect_bd_net [get_bd_ports ddr3a_dm] [get_bd_pins mig_ddr3A/ddr3_dm]
connect_bd_net [get_bd_ports ddr3a_odt] [get_bd_pins mig_ddr3A/ddr3_odt]

# connect mig ddr3A to external ports
connect_bd_net [get_bd_ports ddr3b_dq] [get_bd_pins mig_ddr3B/ddr3_dq]
connect_bd_net [get_bd_ports ddr3b_dqs_n] [get_bd_pins mig_ddr3B/ddr3_dqs_n]
connect_bd_net [get_bd_ports ddr3b_dqs_p] [get_bd_pins mig_ddr3B/ddr3_dqs_p]
connect_bd_net [get_bd_ports ddr3b_addr] [get_bd_pins mig_ddr3B/ddr3_addr]
connect_bd_net [get_bd_ports ddr3b_ba] [get_bd_pins mig_ddr3B/ddr3_ba]
connect_bd_net [get_bd_ports ddr3b_ras_n] [get_bd_pins mig_ddr3B/ddr3_ras_n]
connect_bd_net [get_bd_ports ddr3b_cas_n] [get_bd_pins mig_ddr3B/ddr3_cas_n]
connect_bd_net [get_bd_ports ddr3b_we_n] [get_bd_pins mig_ddr3B/ddr3_we_n]
connect_bd_net [get_bd_ports ddr3b_reset_n] [get_bd_pins mig_ddr3B/ddr3_reset_n]
connect_bd_net [get_bd_ports ddr3b_ck_p] [get_bd_pins mig_ddr3B/ddr3_ck_p]
connect_bd_net [get_bd_ports ddr3b_ck_n] [get_bd_pins mig_ddr3B/ddr3_ck_n]
connect_bd_net [get_bd_ports ddr3b_cke] [get_bd_pins mig_ddr3B/ddr3_cke]
connect_bd_net [get_bd_ports ddr3b_cs_n] [get_bd_pins mig_ddr3B/ddr3_cs_n]
connect_bd_net [get_bd_ports ddr3b_dm] [get_bd_pins mig_ddr3B/ddr3_dm]
connect_bd_net [get_bd_ports ddr3b_odt] [get_bd_pins mig_ddr3B/ddr3_odt]

# connect PCIe lanes to PCIe core
connect_bd_net [get_bd_ports pcie_7x_mgt_txn] \
  [get_bd_pins pcie_0/pcie_7x_mgt_txn]
connect_bd_net [get_bd_ports pcie_7x_mgt_txp] \
  [get_bd_pins pcie_0/pcie_7x_mgt_txp]
connect_bd_net [get_bd_ports pcie_7x_mgt_rxn] \
  [get_bd_pins pcie_0/pcie_7x_mgt_rxn]
connect_bd_net [get_bd_ports pcie_7x_mgt_rxp] \
  [get_bd_pins pcie_0/pcie_7x_mgt_rxp]

# connect nt_ctrl clk and rst
connect_bd_net [get_bd_pins nt_ctrl/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_ctrl/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_ctrl/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_ctrl/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]

# connect nt_gen_rate_ctrl clk and rst
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_0/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_0/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_0/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_1/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_1/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_1/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_2/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_2/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_2/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_3/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_3/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_gen_rate_ctrl_3/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]

# connect nt_ident clk and rst
connect_bd_net [get_bd_pins nt_ident_0/clk] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_ident_0/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]

# connect nt_timestamp clk and rst
connect_bd_net [get_bd_pins nt_timestamp/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_timestamp/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]

# connect nt_gen_timestamp_insert clk and rst
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_0/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_1/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_2/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_3/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_0/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_1/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_2/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_3/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_0/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_1/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_2/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_gen_timestamp_insert_3/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]

# connect nt_recv_latency clk and rst
connect_bd_net [get_bd_pins nt_recv_latency_0/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_recv_latency_1/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_recv_latency_2/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_recv_latency_3/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_recv_latency_0/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_recv_latency_1/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_recv_latency_2/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_recv_latency_3/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_recv_latency_0/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_recv_latency_1/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_recv_latency_2/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_recv_latency_3/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]

# connect nt_recv_interpackettime clk and rst
connect_bd_net [get_bd_pins nt_recv_interpackettime_0/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_recv_interpackettime_1/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_recv_interpackettime_2/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_recv_interpackettime_3/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_recv_interpackettime_0/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_recv_interpackettime_1/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_recv_interpackettime_2/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_recv_interpackettime_3/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_recv_interpackettime_0/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_recv_interpackettime_1/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_recv_interpackettime_2/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_recv_interpackettime_3/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]

# connect nt_datarate clk and rst
connect_bd_net [get_bd_pins nt_datarate_0/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_datarate_1/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_datarate_2/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_datarate_3/clk156] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins nt_datarate_0/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_datarate_1/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_datarate_2/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_datarate_3/rstn156] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_net [get_bd_pins nt_datarate_0/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_datarate_1/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_datarate_2/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]
connect_bd_net [get_bd_pins nt_datarate_3/rst_sw156] \
  [get_bd_pins nt_ctrl/rst_sw156]

# connect nt_packet_counter clk and rst
connect_bd_net [get_bd_pins nt_packet_counter_0/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_packet_counter_1/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_packet_counter_2/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_packet_counter_3/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_packet_counter_0/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_packet_counter_1/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_packet_counter_2/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_packet_counter_3/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_packet_counter_0/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_packet_counter_1/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_packet_counter_2/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_packet_counter_3/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]

# connect nt_gen_replay clk and rst
connect_bd_net [get_bd_pins nt_gen_replay_0/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_gen_replay_1/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_gen_replay_2/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_gen_replay_3/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_gen_replay_0/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_gen_replay_1/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_gen_replay_2/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_gen_replay_3/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_gen_replay_0/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_gen_replay_1/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_gen_replay_2/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_gen_replay_3/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]

# connect nt_recv_capture clk and rst
connect_bd_net [get_bd_pins nt_recv_capture_0/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_recv_capture_1/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_recv_capture_2/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_recv_capture_3/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_recv_capture_0/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_recv_capture_1/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_recv_capture_2/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_recv_capture_3/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_recv_capture_0/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_recv_capture_1/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_recv_capture_2/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_recv_capture_3/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]

# connect nt_recv_filter_mac clk and rst
connect_bd_net [get_bd_pins nt_recv_filter_mac_0/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_recv_filter_mac_1/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_recv_filter_mac_2/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_recv_filter_mac_3/clk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins nt_recv_filter_mac_0/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_recv_filter_mac_1/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_recv_filter_mac_2/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_recv_filter_mac_3/rstn] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins nt_recv_filter_mac_0/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_recv_filter_mac_1/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_recv_filter_mac_2/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]
connect_bd_net [get_bd_pins nt_recv_filter_mac_3/rst_sw] \
  [get_bd_pins nt_ctrl/rst_sw]

# connect axis_fifo_tx clk and rst
connect_bd_net [get_bd_pins axis_fifo_tx_0/s_axis_aclk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axis_fifo_tx_1/s_axis_aclk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axis_fifo_tx_2/s_axis_aclk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axis_fifo_tx_3/s_axis_aclk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axis_fifo_tx_0/m_axis_aclk] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axis_fifo_tx_1/m_axis_aclk] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axis_fifo_tx_2/m_axis_aclk] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axis_fifo_tx_3/m_axis_aclk] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axis_fifo_tx_0/s_axis_aresetn] \
  [get_bd_pins rstn_combined/Res]
connect_bd_net [get_bd_pins axis_fifo_tx_1/s_axis_aresetn] \
  [get_bd_pins rstn_combined/Res]
connect_bd_net [get_bd_pins axis_fifo_tx_2/s_axis_aresetn] \
  [get_bd_pins rstn_combined/Res]
connect_bd_net [get_bd_pins axis_fifo_tx_3/s_axis_aresetn] \
  [get_bd_pins rstn_combined/Res]

# connect axis_fifo_rx clk and rst
connect_bd_net [get_bd_pins axis_fifo_rx_0/s_axis_aclk] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axis_fifo_rx_1/s_axis_aclk] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axis_fifo_rx_2/s_axis_aclk] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axis_fifo_rx_3/s_axis_aclk] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axis_fifo_rx_0/m_axis_aclk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axis_fifo_rx_1/m_axis_aclk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axis_fifo_rx_2/m_axis_aclk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axis_fifo_rx_3/m_axis_aclk] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axis_fifo_rx_0/s_axis_aresetn] \
  [get_bd_pins rstn156_combined/Res]
connect_bd_net [get_bd_pins axis_fifo_rx_1/s_axis_aresetn] \
  [get_bd_pins rstn156_combined/Res]
connect_bd_net [get_bd_pins axis_fifo_rx_2/s_axis_aresetn] \
  [get_bd_pins rstn156_combined/Res]
connect_bd_net [get_bd_pins axis_fifo_rx_3/s_axis_aresetn] \
  [get_bd_pins rstn156_combined/Res]

# connect nt_timestamp to nt_gen_timestamp_insert
connect_bd_net [get_bd_pins nt_timestamp/timestamp_o] \
  [get_bd_pins nt_gen_timestamp_insert_0/timestamp_i]
connect_bd_net [get_bd_pins nt_timestamp/timestamp_o] \
  [get_bd_pins nt_gen_timestamp_insert_1/timestamp_i]
connect_bd_net [get_bd_pins nt_timestamp/timestamp_o] \
  [get_bd_pins nt_gen_timestamp_insert_2/timestamp_i]
connect_bd_net [get_bd_pins nt_timestamp/timestamp_o] \
  [get_bd_pins nt_gen_timestamp_insert_3/timestamp_i]
connect_bd_net [get_bd_pins nt_timestamp/mode_o] \
  [get_bd_pins nt_gen_timestamp_insert_0/mode_i]
connect_bd_net [get_bd_pins nt_timestamp/mode_o] \
  [get_bd_pins nt_gen_timestamp_insert_1/mode_i]
connect_bd_net [get_bd_pins nt_timestamp/mode_o] \
  [get_bd_pins nt_gen_timestamp_insert_2/mode_i]
connect_bd_net [get_bd_pins nt_timestamp/mode_o] \
  [get_bd_pins nt_gen_timestamp_insert_3/mode_i]
connect_bd_net [get_bd_pins nt_timestamp/pos_o] \
  [get_bd_pins nt_gen_timestamp_insert_0/pos_i]
connect_bd_net [get_bd_pins nt_timestamp/pos_o] \
  [get_bd_pins nt_gen_timestamp_insert_1/pos_i]
connect_bd_net [get_bd_pins nt_timestamp/pos_o] \
  [get_bd_pins nt_gen_timestamp_insert_2/pos_i]
connect_bd_net [get_bd_pins nt_timestamp/pos_o] \
  [get_bd_pins nt_gen_timestamp_insert_3/pos_i]
connect_bd_net [get_bd_pins nt_timestamp/width_o] \
  [get_bd_pins nt_gen_timestamp_insert_0/width_i]
connect_bd_net [get_bd_pins nt_timestamp/width_o] \
  [get_bd_pins nt_gen_timestamp_insert_1/width_i]
connect_bd_net [get_bd_pins nt_timestamp/width_o] \
  [get_bd_pins nt_gen_timestamp_insert_2/width_i]
connect_bd_net [get_bd_pins nt_timestamp/width_o] \
  [get_bd_pins nt_gen_timestamp_insert_3/width_i]

# connect nt_timestamp to nt_recv_latency
connect_bd_net [get_bd_pins nt_timestamp/timestamp_o] \
  [get_bd_pins nt_recv_latency_0/timestamp_i]
connect_bd_net [get_bd_pins nt_timestamp/timestamp_o] \
  [get_bd_pins nt_recv_latency_1/timestamp_i]
connect_bd_net [get_bd_pins nt_timestamp/timestamp_o] \
  [get_bd_pins nt_recv_latency_2/timestamp_i]
connect_bd_net [get_bd_pins nt_timestamp/timestamp_o] \
  [get_bd_pins nt_recv_latency_3/timestamp_i]
connect_bd_net [get_bd_pins nt_timestamp/mode_o] \
  [get_bd_pins nt_recv_latency_0/mode_i]
connect_bd_net [get_bd_pins nt_timestamp/mode_o] \
  [get_bd_pins nt_recv_latency_1/mode_i]
connect_bd_net [get_bd_pins nt_timestamp/mode_o] \
  [get_bd_pins nt_recv_latency_2/mode_i]
connect_bd_net [get_bd_pins nt_timestamp/mode_o] \
  [get_bd_pins nt_recv_latency_3/mode_i]
connect_bd_net [get_bd_pins nt_timestamp/pos_o] \
  [get_bd_pins nt_recv_latency_0/pos_i]
connect_bd_net [get_bd_pins nt_timestamp/pos_o] \
  [get_bd_pins nt_recv_latency_1/pos_i]
connect_bd_net [get_bd_pins nt_timestamp/pos_o] \
  [get_bd_pins nt_recv_latency_2/pos_i]
connect_bd_net [get_bd_pins nt_timestamp/pos_o] \
  [get_bd_pins nt_recv_latency_3/pos_i]
connect_bd_net [get_bd_pins nt_timestamp/width_o] \
  [get_bd_pins nt_recv_latency_0/width_i]
connect_bd_net [get_bd_pins nt_timestamp/width_o] \
  [get_bd_pins nt_recv_latency_1/width_i]
connect_bd_net [get_bd_pins nt_timestamp/width_o] \
  [get_bd_pins nt_recv_latency_2/width_i]
connect_bd_net [get_bd_pins nt_timestamp/width_o] \
  [get_bd_pins nt_recv_latency_3/width_i]

# connect nt_gen_replay to nt_packet_counter
connect_bd_intf_net [get_bd_intf_pins nt_gen_replay_0/m_axis] \
  [get_bd_intf_pins nt_packet_counter_0/s_axis_tx]
connect_bd_intf_net [get_bd_intf_pins nt_gen_replay_1/m_axis] \
  [get_bd_intf_pins nt_packet_counter_1/s_axis_tx]
connect_bd_intf_net [get_bd_intf_pins nt_gen_replay_2/m_axis] \
  [get_bd_intf_pins nt_packet_counter_2/s_axis_tx]
connect_bd_intf_net [get_bd_intf_pins nt_gen_replay_3/m_axis] \
  [get_bd_intf_pins nt_packet_counter_3/s_axis_tx]

# connect nt_packet_counter to axis_fifo_tx
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_0/m_axis_tx] \
  [get_bd_intf_pins axis_fifo_tx_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_1/m_axis_tx] \
  [get_bd_intf_pins axis_fifo_tx_1/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_2/m_axis_tx] \
  [get_bd_intf_pins axis_fifo_tx_2/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_3/m_axis_tx] \
  [get_bd_intf_pins axis_fifo_tx_3/s_axis]

# connect axis_fifo_tx to nt_gen_rate_ctrl
connect_bd_intf_net [get_bd_intf_pins nt_gen_rate_ctrl_0/s_axis] \
  [get_bd_intf_pins axis_fifo_tx_0/m_axis]
connect_bd_intf_net [get_bd_intf_pins nt_gen_rate_ctrl_1/s_axis] \
  [get_bd_intf_pins axis_fifo_tx_1/m_axis]
connect_bd_intf_net [get_bd_intf_pins nt_gen_rate_ctrl_2/s_axis] \
  [get_bd_intf_pins axis_fifo_tx_2/m_axis]
connect_bd_intf_net [get_bd_intf_pins nt_gen_rate_ctrl_3/s_axis] \
  [get_bd_intf_pins axis_fifo_tx_3/m_axis]

# connect nt_gen_rate_ctrl to nt_datarate (tx)
connect_bd_intf_net [get_bd_intf_pins nt_gen_rate_ctrl_0/m_axis] \
  [get_bd_intf_pins nt_datarate_0/s_axis_tx]
connect_bd_intf_net [get_bd_intf_pins nt_gen_rate_ctrl_1/m_axis] \
  [get_bd_intf_pins nt_datarate_1/s_axis_tx]
connect_bd_intf_net [get_bd_intf_pins nt_gen_rate_ctrl_2/m_axis] \
  [get_bd_intf_pins nt_datarate_2/s_axis_tx]
connect_bd_intf_net [get_bd_intf_pins nt_gen_rate_ctrl_3/m_axis] \
  [get_bd_intf_pins nt_datarate_3/s_axis_tx]

# connect nt_datarate (tx) to nt_gen_timestamp_insert
connect_bd_intf_net [get_bd_intf_pins nt_datarate_0/m_axis_tx] \
  [get_bd_intf_pins nt_gen_timestamp_insert_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_datarate_1/m_axis_tx] \
  [get_bd_intf_pins nt_gen_timestamp_insert_1/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_datarate_2/m_axis_tx] \
  [get_bd_intf_pins nt_gen_timestamp_insert_2/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_datarate_3/m_axis_tx] \
  [get_bd_intf_pins nt_gen_timestamp_insert_3/s_axis]

# connect nt_gen_timestamp_insert to network interfaces
connect_bd_intf_net [get_bd_intf_pins if_0/s_axis] \
  [get_bd_intf_pins nt_gen_timestamp_insert_0/m_axis]
connect_bd_intf_net [get_bd_intf_pins if_1/s_axis] \
  [get_bd_intf_pins nt_gen_timestamp_insert_1/m_axis]
connect_bd_intf_net [get_bd_intf_pins if_2/s_axis] \
  [get_bd_intf_pins nt_gen_timestamp_insert_2/m_axis]
connect_bd_intf_net [get_bd_intf_pins if_3/s_axis] \
  [get_bd_intf_pins nt_gen_timestamp_insert_3/m_axis]

# connect nt_ctrl to nt_gen_rate_ctrl
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_3
set_property -dict [list  CONFIG.DIN_TO {0} CONFIG.DIN_FROM {0} \
                          CONFIG.DIN_WIDTH {4}] [get_bd_cells xlslice_0]
set_property -dict [list  CONFIG.DIN_TO {1} CONFIG.DIN_FROM {1} \
                          CONFIG.DIN_WIDTH {4}] [get_bd_cells xlslice_1]
set_property -dict [list  CONFIG.DIN_TO {2} CONFIG.DIN_FROM {2} \
                          CONFIG.DIN_WIDTH {4}] [get_bd_cells xlslice_2]
set_property -dict [list  CONFIG.DIN_TO {3} CONFIG.DIN_FROM {3} \
                          CONFIG.DIN_WIDTH {4}] [get_bd_cells xlslice_3]
connect_bd_net [get_bd_pins nt_ctrl/rate_ctrl_active_o] \
  [get_bd_pins xlslice_0/Din]
connect_bd_net [get_bd_pins nt_ctrl/rate_ctrl_active_o] \
  [get_bd_pins xlslice_1/Din]
connect_bd_net [get_bd_pins nt_ctrl/rate_ctrl_active_o] \
  [get_bd_pins xlslice_2/Din]
connect_bd_net [get_bd_pins nt_ctrl/rate_ctrl_active_o] \
  [get_bd_pins xlslice_3/Din]
connect_bd_net [get_bd_pins xlslice_0/Dout] \
  [get_bd_pins nt_gen_rate_ctrl_0/active_i]
connect_bd_net [get_bd_pins xlslice_1/Dout] \
  [get_bd_pins nt_gen_rate_ctrl_1/active_i]
connect_bd_net [get_bd_pins xlslice_2/Dout] \
  [get_bd_pins nt_gen_rate_ctrl_2/active_i]
connect_bd_net [get_bd_pins xlslice_3/Dout] \
  [get_bd_pins nt_gen_rate_ctrl_3/active_i]

# connect network interfaces to nt_recv_latency
connect_bd_intf_net [get_bd_intf_pins if_0/m_axis] \
  [get_bd_intf_pins nt_recv_latency_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins if_1/m_axis] \
  [get_bd_intf_pins nt_recv_latency_1/s_axis]
connect_bd_intf_net [get_bd_intf_pins if_2/m_axis] \
  [get_bd_intf_pins nt_recv_latency_2/s_axis]
connect_bd_intf_net [get_bd_intf_pins if_3/m_axis] \
  [get_bd_intf_pins nt_recv_latency_3/s_axis]

# connect nt_recv_latency to nt_recv_interpackettime
connect_bd_intf_net [get_bd_intf_pins nt_recv_latency_0/m_axis] \
  [get_bd_intf_pins nt_recv_interpackettime_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_recv_latency_1/m_axis] \
  [get_bd_intf_pins nt_recv_interpackettime_1/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_recv_latency_2/m_axis] \
  [get_bd_intf_pins nt_recv_interpackettime_2/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_recv_latency_3/m_axis] \
  [get_bd_intf_pins nt_recv_interpackettime_3/s_axis]

# connect nt_recv_interpackettime nt_datarate (rx)
connect_bd_intf_net [get_bd_intf_pins nt_recv_interpackettime_0/m_axis] \
  [get_bd_intf_pins nt_datarate_0/s_axis_rx]
connect_bd_intf_net [get_bd_intf_pins nt_recv_interpackettime_1/m_axis] \
  [get_bd_intf_pins nt_datarate_1/s_axis_rx]
connect_bd_intf_net [get_bd_intf_pins nt_recv_interpackettime_2/m_axis] \
  [get_bd_intf_pins nt_datarate_2/s_axis_rx]
connect_bd_intf_net [get_bd_intf_pins nt_recv_interpackettime_3/m_axis] \
  [get_bd_intf_pins nt_datarate_3/s_axis_rx]

# connect nt_datarate (rx) to axis_fifo_rx
connect_bd_intf_net [get_bd_intf_pins nt_datarate_0/m_axis_rx] \
  [get_bd_intf_pins axis_fifo_rx_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_datarate_1/m_axis_rx] \
  [get_bd_intf_pins axis_fifo_rx_1/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_datarate_2/m_axis_rx] \
  [get_bd_intf_pins axis_fifo_rx_2/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_datarate_3/m_axis_rx] \
  [get_bd_intf_pins axis_fifo_rx_3/s_axis]

# connect axis_fifo_rx to nt_packet_counter
connect_bd_intf_net [get_bd_intf_pins axis_fifo_rx_0/m_axis] \
  [get_bd_intf_pins nt_packet_counter_0/s_axis_rx]
connect_bd_intf_net [get_bd_intf_pins axis_fifo_rx_1/m_axis] \
  [get_bd_intf_pins nt_packet_counter_1/s_axis_rx]
connect_bd_intf_net [get_bd_intf_pins axis_fifo_rx_2/m_axis] \
  [get_bd_intf_pins nt_packet_counter_2/s_axis_rx]
connect_bd_intf_net [get_bd_intf_pins axis_fifo_rx_3/m_axis] \
  [get_bd_intf_pins nt_packet_counter_3/s_axis_rx]

# connect nt_packet_counter to nt_recv_filter_mac
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_0/m_axis_rx] \
  [get_bd_intf_pins nt_recv_filter_mac_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_1/m_axis_rx] \
  [get_bd_intf_pins nt_recv_filter_mac_1/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_2/m_axis_rx] \
  [get_bd_intf_pins nt_recv_filter_mac_2/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_3/m_axis_rx] \
  [get_bd_intf_pins nt_recv_filter_mac_3/s_axis]

# connect nt_recv_filter_mac to nt_recv_capture
connect_bd_intf_net [get_bd_intf_pins nt_recv_filter_mac_0/m_axis] \
  [get_bd_intf_pins nt_recv_capture_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_recv_filter_mac_1/m_axis] \
  [get_bd_intf_pins nt_recv_capture_1/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_recv_filter_mac_2/m_axis] \
  [get_bd_intf_pins nt_recv_capture_2/s_axis]
connect_bd_intf_net [get_bd_intf_pins nt_recv_filter_mac_3/m_axis] \
  [get_bd_intf_pins nt_recv_capture_3/s_axis]

### AXI DATA INTERCONNECT ###
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] \
  [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
  [get_bd_pins axi_interconnect_0/ARESETN]

# PCIe (master)
connect_bd_net [get_bd_pins pcie_0/M_AXI_ACLK] \
  [get_bd_pins axi_interconnect_0/S00_ACLK]
connect_bd_net [get_bd_pins pcie_0/M_AXI_ARESETN] \
  [get_bd_pins axi_interconnect_0/S00_ARESETN]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins axi_interconnect_0/S00_AXI] [get_bd_intf_pins pcie_0/M_AXI]

# nt_gen_replay (masters)
connect_bd_net [get_bd_pins axi_interconnect_0/S01_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S02_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S03_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S04_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S01_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_0/S02_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_0/S03_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_0/S04_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_intf_net [get_bd_intf_pins nt_gen_replay_0/m_axi_ddr3] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins nt_gen_replay_1/m_axi_ddr3] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins nt_gen_replay_2/m_axi_ddr3] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S03_AXI]
connect_bd_intf_net [get_bd_intf_pins nt_gen_replay_3/m_axi_ddr3] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S04_AXI]

# nt_recv_capture (masters)
connect_bd_net [get_bd_pins axi_interconnect_0/S05_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S06_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S07_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S08_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S05_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_0/S06_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_0/S07_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_0/S08_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_intf_net [get_bd_intf_pins nt_recv_capture_0/m_axi_ddr3] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S05_AXI]
connect_bd_intf_net [get_bd_intf_pins nt_recv_capture_1/m_axi_ddr3] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S06_AXI]
connect_bd_intf_net [get_bd_intf_pins nt_recv_capture_2/m_axi_ddr3] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S07_AXI]
connect_bd_intf_net [get_bd_intf_pins nt_recv_capture_3/m_axi_ddr3] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S08_AXI]

# MIG DDR3A + DDR3B (slaves)
connect_bd_net [get_bd_pins mig_ddr3A/ui_clk] \
  [get_bd_pins axi_interconnect_0/M00_ACLK]
connect_bd_net [get_bd_pins mig_ddr3B/ui_clk] \
  [get_bd_pins axi_interconnect_0/M01_ACLK]
connect_bd_net [get_bd_pins inverter_mig_ddr3A_rst/Res] \
  [get_bd_pins axi_interconnect_0/M00_ARESETN]
connect_bd_net [get_bd_pins inverter_mig_ddr3B_rst/Res] \
  [get_bd_pins axi_interconnect_0/M01_ARESETN]
connect_bd_intf_net [get_bd_intf_pins mig_ddr3A/s_axi] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/M00_AXI]
connect_bd_intf_net [get_bd_intf_pins mig_ddr3B/s_axi] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_0/M01_AXI]

### AXI CTRL INTERCONNECT ###
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] \
  [get_bd_pins axi_interconnect_1/ACLK]
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
  [get_bd_pins axi_interconnect_1/ARESETN]

# PCIe (master)
connect_bd_net [get_bd_pins pcie_0/M_AXI_CTRL_ACLK] \
  [get_bd_pins axi_interconnect_1/S00_ACLK]
connect_bd_net [get_bd_pins pcie_0/M_AXI_CTRL_ARESETN] \
  [get_bd_pins axi_interconnect_1/S00_ARESETN]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins axi_interconnect_1/S00_AXI] \
  [get_bd_intf_pins pcie_0/M_AXI_CTRL]

# nt_gen_replay (slaves)
connect_bd_net [get_bd_pins axi_interconnect_1/M00_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M01_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M02_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M03_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M00_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M01_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M02_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M03_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_gen_replay_0/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M00_AXI]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_gen_replay_1/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M01_AXI]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_gen_replay_2/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M02_AXI]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_gen_replay_3/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M03_AXI]

# nt_recv_capture (slaves)
connect_bd_net [get_bd_pins axi_interconnect_1/M04_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M05_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M06_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M07_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M04_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M05_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M06_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M07_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_recv_capture_0/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M04_AXI]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_recv_capture_1/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M05_AXI]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_recv_capture_2/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M06_AXI]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_recv_capture_3/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M07_AXI]

# nt_recv_filter_mac (slaves)
connect_bd_net [get_bd_pins axi_interconnect_1/M08_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M09_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M10_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M11_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M08_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M09_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M10_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M11_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_recv_filter_mac_0/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M08_AXI]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_recv_filter_mac_1/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M09_AXI]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_recv_filter_mac_2/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M10_AXI]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_recv_filter_mac_3/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M11_AXI]

# nt_packet_counter (slaves)
connect_bd_net [get_bd_pins axi_interconnect_1/M12_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M13_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M14_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M15_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M12_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M13_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M14_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_1/M15_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_0/s_axi] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_1/M12_AXI]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_1/s_axi] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_1/M13_AXI]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_2/s_axi] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_1/M14_AXI]
connect_bd_intf_net [get_bd_intf_pins nt_packet_counter_3/s_axi] \
  -boundary_type upper [get_bd_intf_pins axi_interconnect_1/M15_AXI]

# nt_ctrl (slave)
connect_bd_net [get_bd_pins axi_interconnect_1/M16_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M16_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_ctrl/s_axi] \
  [get_bd_intf_pins axi_interconnect_1/M16_AXI]

# nt_ident (slave)
connect_bd_net [get_bd_pins axi_interconnect_1/M17_ACLK] \
  [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_1/M17_ARESETN] \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_intf_net -boundary_type upper [get_bd_intf_pins nt_ident_0/s_axi] \
  [get_bd_intf_pins axi_interconnect_1/M17_AXI]

# nt_timestamp (slave)
connect_bd_net [get_bd_pins axi_interconnect_1/M18_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M18_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_timestamp/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M18_AXI]

# nt_gen_rate_ctrl (slave)
connect_bd_net [get_bd_pins axi_interconnect_1/M19_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M19_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_gen_rate_ctrl_0/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M19_AXI]
connect_bd_net [get_bd_pins axi_interconnect_1/M20_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M20_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_gen_rate_ctrl_1/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M20_AXI]
connect_bd_net [get_bd_pins axi_interconnect_1/M21_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M21_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_gen_rate_ctrl_2/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M21_AXI]
connect_bd_net [get_bd_pins axi_interconnect_1/M22_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M22_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_gen_rate_ctrl_3/s_axi_ctrl] \
  [get_bd_intf_pins axi_interconnect_1/M22_AXI]

# nt_datarate (slaves)
connect_bd_net [get_bd_pins axi_interconnect_1/M23_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M23_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_datarate_0/s_axi] \
  [get_bd_intf_pins axi_interconnect_1/M23_AXI]
connect_bd_net [get_bd_pins axi_interconnect_1/M24_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M24_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_datarate_1/s_axi] \
  [get_bd_intf_pins axi_interconnect_1/M24_AXI]
connect_bd_net [get_bd_pins axi_interconnect_1/M25_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M25_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_datarate_2/s_axi] \
  [get_bd_intf_pins axi_interconnect_1/M25_AXI]
connect_bd_net [get_bd_pins axi_interconnect_1/M26_ACLK] \
  [get_bd_pins if_0/clk156_out]
connect_bd_net [get_bd_pins axi_interconnect_1/M26_ARESETN] \
  [get_bd_pins inverter_clk156_rst/Res]
connect_bd_intf_net -boundary_type upper \
  [get_bd_intf_pins nt_datarate_3/s_axi] \
  [get_bd_intf_pins axi_interconnect_1/M26_AXI]

# connect remaining network inferface pins
connect_bd_net [get_bd_ports sfp_clk_n] [get_bd_pins if_0/refclk_n]
connect_bd_net [get_bd_ports sfp_clk_p] [get_bd_pins if_0/refclk_p]
connect_bd_net [get_bd_ports if0_rxn] [get_bd_pins if_0/rxn]
connect_bd_net [get_bd_ports if1_rxn] [get_bd_pins if_1/rxn]
connect_bd_net [get_bd_ports if2_rxn] [get_bd_pins if_2/rxn]
connect_bd_net [get_bd_ports if3_rxn] [get_bd_pins if_3/rxn]
connect_bd_net [get_bd_ports if0_rxp] [get_bd_pins if_0/rxp]
connect_bd_net [get_bd_ports if1_rxp] [get_bd_pins if_1/rxp]
connect_bd_net [get_bd_ports if2_rxp] [get_bd_pins if_2/rxp]
connect_bd_net [get_bd_ports if3_rxp] [get_bd_pins if_3/rxp]
connect_bd_net [get_bd_ports if0_txn] [get_bd_pins if_0/txn]
connect_bd_net [get_bd_ports if1_txn] [get_bd_pins if_1/txn]
connect_bd_net [get_bd_ports if2_txn] [get_bd_pins if_2/txn]
connect_bd_net [get_bd_ports if3_txn] [get_bd_pins if_3/txn]
connect_bd_net [get_bd_ports if0_txp] [get_bd_pins if_0/txp]
connect_bd_net [get_bd_ports if1_txp] [get_bd_pins if_1/txp]
connect_bd_net [get_bd_ports if2_txp] [get_bd_pins if_2/txp]
connect_bd_net [get_bd_ports if3_txp] [get_bd_pins if_3/txp]
connect_bd_net [get_bd_ports if0_tx_abs] [get_bd_pins if_0/tx_abs]
connect_bd_net [get_bd_ports if1_tx_abs] [get_bd_pins if_1/tx_abs]
connect_bd_net [get_bd_ports if2_tx_abs] [get_bd_pins if_2/tx_abs]
connect_bd_net [get_bd_ports if3_tx_abs] [get_bd_pins if_3/tx_abs]
connect_bd_net [get_bd_ports if0_tx_fault] [get_bd_pins if_0/tx_fault]
connect_bd_net [get_bd_ports if1_tx_fault] [get_bd_pins if_1/tx_fault]
connect_bd_net [get_bd_ports if2_tx_fault] [get_bd_pins if_2/tx_fault]
connect_bd_net [get_bd_ports if3_tx_fault] [get_bd_pins if_3/tx_fault]
connect_bd_net [get_bd_ports if0_rx_led] [get_bd_pins if_0/resetdone]
connect_bd_net [get_bd_ports if0_tx_led] [get_bd_pins if_0/resetdone]
connect_bd_net [get_bd_ports if1_rx_led] [get_bd_pins if_1/rx_resetdone]
connect_bd_net [get_bd_ports if1_tx_led] [get_bd_pins if_1/tx_resetdone]
connect_bd_net [get_bd_ports if2_rx_led] [get_bd_pins if_2/rx_resetdone]
connect_bd_net [get_bd_ports if2_tx_led] [get_bd_pins if_2/tx_resetdone]
connect_bd_net [get_bd_ports if3_rx_led] [get_bd_pins if_3/rx_resetdone]
connect_bd_net [get_bd_ports if3_tx_led] [get_bd_pins if_3/tx_resetdone]
connect_bd_net [get_bd_ports if0_tx_disable] [get_bd_pins if_0/tx_disable]
connect_bd_net [get_bd_ports if1_tx_disable] [get_bd_pins if_1/tx_disable]
connect_bd_net [get_bd_ports if2_tx_disable] [get_bd_pins if_2/tx_disable]
connect_bd_net [get_bd_ports if3_tx_disable] [get_bd_pins if_3/tx_disable]
connect_bd_net [get_bd_pins if_0/clk156_out] [get_bd_pins if_1/clk156]
connect_bd_net [get_bd_pins if_0/clk156_out] [get_bd_pins if_2/clk156]
connect_bd_net [get_bd_pins if_0/clk156_out] [get_bd_pins if_3/clk156]
connect_bd_net [get_bd_pins if_0/areset_clk156_out] \
  [get_bd_pins if_1/areset_clk156]
connect_bd_net [get_bd_pins if_0/areset_clk156_out] \
  [get_bd_pins if_2/areset_clk156]
connect_bd_net [get_bd_pins if_0/areset_clk156_out] \
  [get_bd_pins if_3/areset_clk156]
connect_bd_net [get_bd_pins if_0/gtrxreset_out] [get_bd_pins if_1/gtrxreset]
connect_bd_net [get_bd_pins if_0/gtrxreset_out] [get_bd_pins if_2/gtrxreset]
connect_bd_net [get_bd_pins if_0/gtrxreset_out] [get_bd_pins if_3/gtrxreset]
connect_bd_net [get_bd_pins if_0/gttxreset_out] [get_bd_pins if_1/gttxreset]
connect_bd_net [get_bd_pins if_0/gttxreset_out] [get_bd_pins if_2/gttxreset]
connect_bd_net [get_bd_pins if_0/gttxreset_out] [get_bd_pins if_3/gttxreset]
connect_bd_net [get_bd_pins if_0/qplllock_out] [get_bd_pins if_1/qplllock]
connect_bd_net [get_bd_pins if_0/qplllock_out] [get_bd_pins if_2/qplllock]
connect_bd_net [get_bd_pins if_0/qplllock_out] [get_bd_pins if_3/qplllock]
connect_bd_net [get_bd_pins if_0/qplloutclk_out] [get_bd_pins if_1/qplloutclk]
connect_bd_net [get_bd_pins if_0/qplloutclk_out] [get_bd_pins if_2/qplloutclk]
connect_bd_net [get_bd_pins if_0/qplloutclk_out] [get_bd_pins if_3/qplloutclk]
connect_bd_net [get_bd_pins if_0/qplloutrefclk_out] \
  [get_bd_pins if_1/qplloutrefclk]
connect_bd_net [get_bd_pins if_0/qplloutrefclk_out] \
  [get_bd_pins if_2/qplloutrefclk]
connect_bd_net [get_bd_pins if_0/qplloutrefclk_out] \
  [get_bd_pins if_3/qplloutrefclk]
connect_bd_net [get_bd_pins if_0/txuserrdy_out] [get_bd_pins if_1/txuserrdy]
connect_bd_net [get_bd_pins if_0/txuserrdy_out] [get_bd_pins if_2/txuserrdy]
connect_bd_net [get_bd_pins if_0/txuserrdy_out] [get_bd_pins if_3/txuserrdy]
connect_bd_net [get_bd_pins if_0/txusrclk_out] [get_bd_pins if_1/txusrclk]
connect_bd_net [get_bd_pins if_0/txusrclk_out] [get_bd_pins if_2/txusrclk]
connect_bd_net [get_bd_pins if_0/txusrclk_out] [get_bd_pins if_3/txusrclk]
connect_bd_net [get_bd_pins if_0/txusrclk2_out] [get_bd_pins if_1/txusrclk2]
connect_bd_net [get_bd_pins if_0/txusrclk2_out] [get_bd_pins if_2/txusrclk2]
connect_bd_net [get_bd_pins if_0/txusrclk2_out] [get_bd_pins if_3/txusrclk2]
connect_bd_net [get_bd_pins if_0/reset_counter_done_out] \
  [get_bd_pins if_1/reset_counter_done]
connect_bd_net [get_bd_pins if_0/reset_counter_done_out] \
  [get_bd_pins if_2/reset_counter_done]
connect_bd_net [get_bd_pins if_0/reset_counter_done_out] \
  [get_bd_pins if_3/reset_counter_done]
