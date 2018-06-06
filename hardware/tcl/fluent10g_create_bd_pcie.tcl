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
# Create PCIExpress DMA sub-system.

proc create_hier_cell_pcie { parentCell coreName } {

  # check arguments
  if { $parentCell eq "" || $coreName eq "" } {
    puts "ERROR: Empty argument(s)!"
    return
  }

  # get parentCell object
  set parentObj [get_bd_cells $parentCell]
  if { $parentCell == "" } {
    puts "ERROR: Unable to find parent cell <$parentCell>!"
    return
  }

  # parentObj should be hier block
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier"} {
    puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>."
  }

  # save current instance
  set oldCurInst [current_bd_instance .]

  # set parent object as current
  current_bd_instance $parentObj

  # create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $coreName]
  current_bd_instance $hier_obj

  # create pcie clock inputs
  create_bd_pin -dir I -type clk pcie_sysclk_p
  create_bd_pin -dir I -type clk pcie_sysclk_n

  # create pcie reset input
  create_bd_pin -dir I pcie_sys_resetn

  # create pcie data pins
  create_bd_pin -dir I -from 0 -to 7 pcie_7x_mgt_rxn
  create_bd_pin -dir I -from 0 -to 7 pcie_7x_mgt_rxp
  create_bd_pin -dir O -from 0 -to 7 pcie_7x_mgt_txn
  create_bd_pin -dir O -from 0 -to 7 pcie_7x_mgt_txp

  # create axi master interface
  create_bd_pin -dir O M_AXI_ACLK
  create_bd_pin -dir O M_AXI_ARESETN
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

  # create axi lite ctrl interface
  create_bd_pin -dir O M_AXI_CTRL_ACLK
  create_bd_pin -dir O M_AXI_CTRL_ARESETN
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 \
    M_AXI_CTRL

  # create pcie dma
  create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:3.1 xdma_0
  set_property -dict [list CONFIG.mode_selection {Advanced} \
                           CONFIG.pcie_blk_locn {X0Y1} \
                           CONFIG.pl_link_cap_max_link_width {X8} \
                           CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
                           CONFIG.axi_data_width {256_bit} \
                           CONFIG.pf0_device_id {7032} \
                           CONFIG.pf0_interrupt_pin {NONE} \
                           CONFIG.xdma_pcie_64bit_en {true} \
                           CONFIG.pf0_link_status_slot_clock_config {false} \
                           CONFIG.pf0_msix_enabled {true} \
                           CONFIG.cfg_mgmt_if {false} \
                           CONFIG.axisten_freq {250} \
                           CONFIG.dedicate_perst {false} \
                           CONFIG.plltype {QPLL1} \
                           CONFIG.axilite_master_en {true} \
                           CONFIG.axilite_master_scale {Kilobytes} \
                           CONFIG.axilite_master_size {128} \
                           CONFIG.pf0_msix_cap_table_size {020} \
                           CONFIG.pf0_msix_cap_table_offset {00008000} \
                           CONFIG.pf0_msix_cap_table_bir {BAR_3:2} \
                           CONFIG.pf0_msix_cap_pba_offset {00008FE0} \
                           CONFIG.pf0_msix_cap_pba_bir {BAR_3:2}] \
  [get_bd_cells xdma_0]

  # create pcie endpoint input clock buffer.
  create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 util_ds_buf_0
  set_property -dict [list CONFIG.C_BUF_TYPE {IBUFDSGTE}] \
    [get_bd_cells util_ds_buf_0]

  # create constant
  create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
  set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}] \
    [get_bd_cells xlconstant_0]

  # external port connections
  connect_bd_net [get_bd_pins pcie_sysclk_p] \
    [get_bd_pins util_ds_buf_0/IBUF_DS_P]
  connect_bd_net [get_bd_pins pcie_sysclk_n] \
    [get_bd_pins util_ds_buf_0/IBUF_DS_N]
  connect_bd_net [get_bd_pins pcie_sys_resetn] \
    [get_bd_pins xdma_0/sys_rst_n]
  connect_bd_net [get_bd_pins pcie_7x_mgt_rxn] [get_bd_pins xdma_0/pci_exp_rxn]
  connect_bd_net [get_bd_pins pcie_7x_mgt_rxp] [get_bd_pins xdma_0/pci_exp_rxp]
  connect_bd_net [get_bd_pins pcie_7x_mgt_txn] [get_bd_pins xdma_0/pci_exp_txn]
  connect_bd_net [get_bd_pins pcie_7x_mgt_txp] [get_bd_pins xdma_0/pci_exp_txp]

  # axi master
  connect_bd_net [get_bd_pins M_AXI_ACLK] [get_bd_pins xdma_0/axi_aclk]
  connect_bd_net [get_bd_pins M_AXI_ARESETN] [get_bd_pins xdma_0/axi_aresetn]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins M_AXI] \
    [get_bd_intf_pins xdma_0/M_AXI]

  # axi lite ctrl master
  connect_bd_net [get_bd_pins M_AXI_CTRL_ACLK] [get_bd_pins xdma_0/axi_aclk]
  connect_bd_net [get_bd_pins M_AXI_CTRL_ARESETN] \
    [get_bd_pins xdma_0/axi_aresetn]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins M_AXI_CTRL] \
    [get_bd_intf_pins xdma_0/M_AXI_LITE]

  # internal connections
  connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] \
    [get_bd_pins xdma_0/sys_clk]
  connect_bd_net [get_bd_pins xlconstant_0/dout] \
    [get_bd_pins xdma_0/usr_irq_req]

  # restore current instance
  current_bd_instance $oldCurInst
}
