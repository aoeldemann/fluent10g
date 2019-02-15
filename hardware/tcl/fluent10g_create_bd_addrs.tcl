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
# Assigns addresses to AXI (-Lite) peripherals

create_bd_addr_seg -offset 0x0000000000000000 -range 4G \
  [get_bd_addr_spaces /pcie_0/xdma_0/M_AXI] \
  [get_bd_addr_segs /mig_ddr3A/memmap/memaddr] SEG_mig_ddr3A_memmap_memaddr
create_bd_addr_seg -offset 0x0000000100000000 -range 4G \
  [get_bd_addr_spaces /pcie_0/xdma_0/M_AXI] \
  [get_bd_addr_segs /mig_ddr3B/memmap/memaddr] SEG_mig_ddr3B_memmap_memaddr
create_bd_addr_seg -offset 0x0000000000000000 -range 4G \
  [get_bd_addr_spaces /nt_gen_replay_0/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3A/memmap/memaddr] SEG_mig_ddr3A_memmap_memaddr
create_bd_addr_seg -offset 0x0000000100000000 -range 4G \
  [get_bd_addr_spaces /nt_gen_replay_0/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3B/memmap/memaddr] SEG_mig_ddr3B_memmap_memaddr
create_bd_addr_seg -offset 0x0000000000000000 -range 4G \
  [get_bd_addr_spaces /nt_gen_replay_1/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3A/memmap/memaddr] SEG_mig_ddr3A_memmap_memaddr
create_bd_addr_seg -offset 0x0000000100000000 -range 4G \
  [get_bd_addr_spaces /nt_gen_replay_1/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3B/memmap/memaddr] SEG_mig_ddr3B_memmap_memaddr
create_bd_addr_seg -offset 0x0000000000000000 -range 4G \
  [get_bd_addr_spaces /nt_gen_replay_2/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3A/memmap/memaddr] SEG_mig_ddr3A_memmap_memaddr
create_bd_addr_seg -offset 0x0000000100000000 -range 4G \
  [get_bd_addr_spaces /nt_gen_replay_2/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3B/memmap/memaddr] SEG_mig_ddr3B_memmap_memaddr
create_bd_addr_seg -offset 0x0000000000000000 -range 4G \
  [get_bd_addr_spaces /nt_gen_replay_3/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3A/memmap/memaddr] SEG_mig_ddr3A_memmap_memaddr
create_bd_addr_seg -offset 0x0000000100000000 -range 4G \
  [get_bd_addr_spaces /nt_gen_replay_3/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3B/memmap/memaddr] SEG_mig_ddr3B_memmap_memaddr

create_bd_addr_seg -offset 0x0000000000000000 -range 4G \
  [get_bd_addr_spaces /nt_recv_capture_0/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3A/memmap/memaddr] SEG_mig_ddr3A_memmap_memaddr
create_bd_addr_seg -offset 0x0000000100000000 -range 4G \
  [get_bd_addr_spaces /nt_recv_capture_0/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3B/memmap/memaddr] SEG_mig_ddr3B_memmap_memaddr
create_bd_addr_seg -offset 0x0000000000000000 -range 4G \
  [get_bd_addr_spaces /nt_recv_capture_1/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3A/memmap/memaddr] SEG_mig_ddr3A_memmap_memaddr
create_bd_addr_seg -offset 0x0000000100000000 -range 4G \
  [get_bd_addr_spaces /nt_recv_capture_1/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3B/memmap/memaddr] SEG_mig_ddr3B_memmap_memaddr
create_bd_addr_seg -offset 0x0000000000000000 -range 4G \
  [get_bd_addr_spaces /nt_recv_capture_2/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3A/memmap/memaddr] SEG_mig_ddr3A_memmap_memaddr
create_bd_addr_seg -offset 0x0000000100000000 -range 4G \
  [get_bd_addr_spaces /nt_recv_capture_2/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3B/memmap/memaddr] SEG_mig_ddr3B_memmap_memaddr
create_bd_addr_seg -offset 0x0000000000000000 -range 4G \
  [get_bd_addr_spaces /nt_recv_capture_3/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3A/memmap/memaddr] SEG_mig_ddr3A_memmap_memaddr
create_bd_addr_seg -offset 0x0000000100000000 -range 4G \
  [get_bd_addr_spaces /nt_recv_capture_3/m_axi_ddr3] \
  [get_bd_addr_segs /mig_ddr3B/memmap/memaddr] SEG_mig_ddr3B_memmap_memaddr

create_bd_addr_seg -offset 0x00000000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_gen_replay_0/s_axi_ctrl/reg0] SEG_nt_gen_replay_0_reg0
create_bd_addr_seg -offset 0x00001000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_gen_replay_1/s_axi_ctrl/reg0] SEG_nt_gen_replay_1_reg0
create_bd_addr_seg -offset 0x00002000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_gen_replay_2/s_axi_ctrl/reg0] SEG_nt_gen_replay_2_reg0
create_bd_addr_seg -offset 0x00003000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_gen_replay_3/s_axi_ctrl/reg0] SEG_nt_gen_replay_3_reg0

create_bd_addr_seg -offset 0x00004000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_gen_rate_ctrl_0/s_axi_ctrl/reg0] \
  SEG_nt_gen_rate_ctrl_0_reg0

create_bd_addr_seg -offset 0x00005000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_gen_rate_ctrl_1/s_axi_ctrl/reg0] \
  SEG_nt_gen_rate_ctrl_1_reg0

create_bd_addr_seg -offset 0x00006000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_gen_rate_ctrl_2/s_axi_ctrl/reg0] \
  SEG_nt_gen_rate_ctrl_2_reg0

create_bd_addr_seg -offset 0x00007000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_gen_rate_ctrl_3/s_axi_ctrl/reg0] \
  SEG_nt_gen_rate_ctrl_3_reg0

create_bd_addr_seg -offset 0x00008000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_ctrl/s_axi/reg0] \
  SEG_nt_ctrl_reg0

create_bd_addr_seg -offset 0x00009000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_recv_capture_0/s_axi_ctrl/reg0] \
  SEG_nt_recv_capture_0_reg0
create_bd_addr_seg -offset 0x0000A000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_recv_capture_1/s_axi_ctrl/reg0] \
  SEG_nt_recv_capture_1_reg0
create_bd_addr_seg -offset 0x0000B000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_recv_capture_2/s_axi_ctrl/reg0] \
  SEG_nt_recv_capture_2_reg0
create_bd_addr_seg -offset 0x0000C000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_recv_capture_3/s_axi_ctrl/reg0] \
  SEG_nt_recv_capture_3_reg0

create_bd_addr_seg -offset 0x0000D000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_recv_filter_mac_0/s_axi_ctrl/reg0] \
  SEG_nt_recv_filter_mac_0_reg0
create_bd_addr_seg -offset 0x0000E000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_recv_filter_mac_1/s_axi_ctrl/reg0] \
  SEG_nt_recv_filter_mac_1_reg0
create_bd_addr_seg -offset 0x0000F000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_recv_filter_mac_2/s_axi_ctrl/reg0] \
  SEG_nt_recv_filter_mac_2_reg0
create_bd_addr_seg -offset 0x00010000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_recv_filter_mac_3/s_axi_ctrl/reg0] \
  SEG_nt_recv_filter_mac_3_reg0

create_bd_addr_seg -offset 0x00011000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_packet_counter_0/s_axi/reg0] \
  SEG_nt_packet_counter_0_reg0
create_bd_addr_seg -offset 0x00012000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_packet_counter_1/s_axi/reg0] \
  SEG_nt_packet_counter_1_reg0
create_bd_addr_seg -offset 0x00013000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_packet_counter_2/s_axi/reg0] \
  SEG_nt_packet_counter_2_reg0
create_bd_addr_seg -offset 0x00014000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_packet_counter_3/s_axi/reg0] \
  SEG_nt_packet_counter_3_reg0

create_bd_addr_seg -offset 0x00015000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_timestamp/s_axi_ctrl/reg0] \
  SEG_nt_timestamp_reg0

create_bd_addr_seg -offset 0x00016000 -range 4K \
  [get_bd_addr_spaces pcie_0/xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs /nt_ident_0/s_axi/reg0] SEG_nt_ident_0_reg0


set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00000000}] \
  [get_bd_cells nt_gen_replay_0]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00001000}] \
  [get_bd_cells nt_gen_replay_1]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00002000}] \
  [get_bd_cells nt_gen_replay_2]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00003000}] \
  [get_bd_cells nt_gen_replay_3]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00004000}] \
  [get_bd_cells nt_gen_rate_ctrl_0]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00005000}] \
  [get_bd_cells nt_gen_rate_ctrl_1]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00006000}] \
  [get_bd_cells nt_gen_rate_ctrl_2]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00007000}] \
  [get_bd_cells nt_gen_rate_ctrl_3]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00008000}] \
  [get_bd_cells nt_ctrl]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00009000}] \
  [get_bd_cells nt_recv_capture_0]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x0000A000}] \
  [get_bd_cells nt_recv_capture_1]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x0000B000}] \
  [get_bd_cells nt_recv_capture_2]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x0000C000}] \
  [get_bd_cells nt_recv_capture_3]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x0000D000}] \
  [get_bd_cells nt_recv_filter_mac_0]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x0000E000}] \
  [get_bd_cells nt_recv_filter_mac_1]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x0000F000}] \
  [get_bd_cells nt_recv_filter_mac_2]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00010000}] \
  [get_bd_cells nt_recv_filter_mac_3]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00011000}] \
  [get_bd_cells nt_packet_counter_0]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00012000}] \
  [get_bd_cells nt_packet_counter_1]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00013000}] \
  [get_bd_cells nt_packet_counter_2]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00014000}] \
  [get_bd_cells nt_packet_counter_3]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00015000}] \
  [get_bd_cells nt_timestamp]
set_property -dict [list CONFIG.C_AXI_BASE_ADDRESS {0x00016000}] \
  [get_bd_cells nt_ident_0]
