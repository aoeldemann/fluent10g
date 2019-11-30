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
# Create the network tester Vivado project and instantiates IP cores. Sources
# other scripts to connect IP cores, create the block design, assign addresses,
# ...

# set some basic project infos
set design fluent10g
set device xc7vx690t-3-ffg1761
set proj_dir ./project
set repo_dir ./ip

# set current directory
set current_dir [pwd]

# create the project
create_project -name ${design} -force -dir "./${proj_dir}" -part ${device}
set_property source_mgmt_mode DisplayOnly [current_project]

# set ip repo directory
set_property ip_repo_paths ${repo_dir} [current_fileset]

# update ip catalog
update_ip_catalog

# create block design
create_bd_design ${design}

# import constaint files
add_files -fileset constrs_1 -norecurse ./xdc/fluent10g_bd.xdc
import_files -fileset constrs_1 ./xdc/fluent10g_bd.xdc

# create xilinx ip cores used by project's ip cores
source ./tcl/fluent10g_create_ip.tcl

# create clock generator
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000}] \
  [get_bd_cells clk_wiz_0]

# create reset system
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0

# create clock buffer for FPGA_SYSCLK
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 clkbuf_fpga_sysclk

# create clock buffer for DDR3_SYSCLK
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 clkbuf_ddr3_sysclk

# create pci express core
source ./tcl/fluent10g_create_bd_pcie.tcl
create_hier_cell_pcie [current_bd_instance .] pcie_0

# create axi interconnect (data)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 \
  axi_interconnect_0
set_property -dict [list  CONFIG.NUM_SI {9} CONFIG.NUM_MI {2} \
                          CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
                          CONFIG.XBAR_DATA_WIDTH {512}] \
  [get_bd_cells axi_interconnect_0]

# create axi interconnect (ctrl)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 \
  axi_interconnect_1
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {27}] \
  [get_bd_cells axi_interconnect_1]

# instantiate network interface cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_10g_if_shared:1.00 if_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_10g_if:1.00 if_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_10g_if:1.00 if_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_10g_if:1.00 if_3

# create SFP reset inverter
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 \
  inverter_clk156_rst
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not}] \
  [get_bd_cells inverter_clk156_rst]

# create logic to AND rstn and rstn_sw
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 \
  rstn_combined
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {and}] \
  [get_bd_cells rstn_combined]

# create logic to AND rstn156 and rstn_sw156
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 \
  rstn156_combined
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {and}] \
  [get_bd_cells rstn156_combined]

# create system control core
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_ctrl:1.00 nt_ctrl

# create system identification core
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_ident:1.00 nt_ident_0

# create global timestamp core
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_timestamp:1.00 nt_timestamp

# create generator replay cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_replay:1.00 nt_gen_replay_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_replay:1.00 nt_gen_replay_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_replay:1.00 nt_gen_replay_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_replay:1.00 nt_gen_replay_3

# create generator rate control cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_rate_ctrl:1.00 \
  nt_gen_rate_ctrl_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_rate_ctrl:1.00 \
  nt_gen_rate_ctrl_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_rate_ctrl:1.00 \
  nt_gen_rate_ctrl_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_rate_ctrl:1.00 \
  nt_gen_rate_ctrl_3

# create generator timestamp insert cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_timestamp_insert:1.00 \
  nt_gen_timestamp_insert_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_timestamp_insert:1.00 \
  nt_gen_timestamp_insert_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_timestamp_insert:1.00 \
  nt_gen_timestamp_insert_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_gen_timestamp_insert:1.00 \
  nt_gen_timestamp_insert_3

# create receiver capture cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_capture:1.00 \
  nt_recv_capture_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_capture:1.00 \
  nt_recv_capture_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_capture:1.00 \
  nt_recv_capture_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_capture:1.00 \
  nt_recv_capture_3

# create receiver mac address filter cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_filter_mac:1.00 \
  nt_recv_filter_mac_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_filter_mac:1.00 \
  nt_recv_filter_mac_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_filter_mac:1.00 \
  nt_recv_filter_mac_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_filter_mac:1.00 \
  nt_recv_filter_mac_3

# create receiver latency cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_latency:1.00 \
  nt_recv_latency_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_latency:1.00 \
  nt_recv_latency_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_latency:1.00 \
  nt_recv_latency_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_latency:1.00 \
  nt_recv_latency_3

# create receiver inter-packet time cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_interpackettime:1.00 \
  nt_recv_interpackettime_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_interpackettime:1.00 \
  nt_recv_interpackettime_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_interpackettime:1.00 \
  nt_recv_interpackettime_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_recv_interpackettime:1.00 \
  nt_recv_interpackettime_3

# create packet counter cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_packet_counter:1.00 \
  nt_packet_counter_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_packet_counter:1.00 \
  nt_packet_counter_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_packet_counter:1.00 \
  nt_packet_counter_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_packet_counter:1.00 \
  nt_packet_counter_3

# create data rate cores
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_datarate:1.00 \
  nt_datarate_0
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_datarate:1.00 \
  nt_datarate_1
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_datarate:1.00 \
  nt_datarate_2
create_bd_cell -type ip -vlnv TUMLIS:TUMLIS:nt_datarate:1.00 \
  nt_datarate_3

# create AXI4-Stream FIFOs for TX clock domain crossing
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_fifo_tx_0
set_property -dict [list CONFIG.TDATA_NUM_BYTES {8} CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.TUSER_WIDTH {32} \
  CONFIG.FIFO_DEPTH {16}]  [get_bd_cells axis_fifo_tx_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_fifo_tx_1
set_property -dict [list CONFIG.TDATA_NUM_BYTES {8} CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.TUSER_WIDTH {32} \
  CONFIG.FIFO_DEPTH {16}] [get_bd_cells axis_fifo_tx_1]
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_fifo_tx_2
set_property -dict [list CONFIG.TDATA_NUM_BYTES {8} CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.TUSER_WIDTH {32} \
  CONFIG.FIFO_DEPTH {16}] [get_bd_cells axis_fifo_tx_2]
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_fifo_tx_3
set_property -dict [list CONFIG.TDATA_NUM_BYTES {8} CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.TUSER_WIDTH {32} \
  CONFIG.FIFO_DEPTH {16}] [get_bd_cells axis_fifo_tx_3]

# create AXI4-Stream FIFOs for RX clock domain crossing
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_fifo_rx_0
set_property -dict [list CONFIG.TDATA_NUM_BYTES {8} CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.TUSER_WIDTH {53} \
  CONFIG.FIFO_DEPTH {16}] [get_bd_cells axis_fifo_rx_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_fifo_rx_1
set_property -dict [list CONFIG.TDATA_NUM_BYTES {8} CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.TUSER_WIDTH {53} \
  CONFIG.FIFO_DEPTH {16}] [get_bd_cells axis_fifo_rx_1]
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_fifo_rx_2
set_property -dict [list CONFIG.TDATA_NUM_BYTES {8} CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.TUSER_WIDTH {53} \
  CONFIG.FIFO_DEPTH {16}] [get_bd_cells axis_fifo_rx_2]
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_fifo_rx_3
set_property -dict [list CONFIG.TDATA_NUM_BYTES {8} CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.TUSER_WIDTH {53} \
  CONFIG.FIFO_DEPTH {16}] [get_bd_cells axis_fifo_rx_3]

# create MIGs for DDD3 DRAM memories
create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 mig_ddr3A
set_property -dict [list \
                    CONFIG.XML_INPUT_FILE ${current_dir}/config/mig_ddr3A.xml] \
  [get_bd_cells mig_ddr3A]
create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 mig_ddr3B
set_property -dict [list \
                    CONFIG.XML_INPUT_FILE ${current_dir}/config/mig_ddr3B.xml] \
  [get_bd_cells mig_ddr3B]

# create two MIG reset signal inverters
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 \
  inverter_mig_ddr3A_rst
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not}] \
  [get_bd_cells inverter_mig_ddr3A_rst]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 \
  inverter_mig_ddr3B_rst
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not}] \
  [get_bd_cells inverter_mig_ddr3B_rst]

# create constant input (0) for device_temp_i MIG input
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 \
  mig_device_temp_i_constant
set_property -dict [list CONFIG.CONST_WIDTH {12} CONFIG.CONST_VAL {0}] \
  [get_bd_cells mig_device_temp_i_constant]

# create external ports
source ./tcl/fluent10g_create_bd_ports.tcl

# create connections
source ./tcl/fluent10g_create_bd_connections.tcl

# assign addresses
source ./tcl/fluent10g_create_bd_addrs.tcl

# save block design
current_bd_instance [current_bd_instance .]
save_bd_design

# create system block
make_wrapper -files \
  [get_files ./${proj_dir}/${design}.srcs/sources_1/bd/${design}/${design}.bd] \
  -top
add_files -norecurse \
  ./${proj_dir}/${design}.srcs/sources_1/bd/${design}/hdl/${design}_wrapper.v

# set toplevel module
set_property top ${design}_wrapper [current_fileset]

# done
exit
