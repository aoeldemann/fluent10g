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
# Creates the nt_gen_rate_ctrl IP core.

set design nt_gen_rate_ctrl
set top nt_gen_rate_ctrl_top

source ../ip_create_start.tcl

read_verilog "./hdl/nt_gen_rate_ctrl_top.v"
read_verilog "./hdl/nt_gen_rate_ctrl.v"
read_verilog "./hdl/nt_gen_rate_ctrl_cpuregs.v"
read_verilog "./hdl/nt_gen_rate_ctrl_cpuregs_defines.vh"

create_ip -name axis_data_fifo -vendor xilinx.com -library ip -version 1.1 \
  -module_name nt_gen_rate_ctrl_axis_fifo
set_property -dict [list  CONFIG.TDATA_NUM_BYTES {8} CONFIG.FIFO_DEPTH {512} \
                          CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} \
                          CONFIG.TUSER_WIDTH {32}] \
  [get_ips nt_gen_rate_ctrl_axis_fifo]

# to perform behavioral simulations we need generated simulation sources for
# the fifo, generate them
generate_target simulation [get_ips nt_gen_rate_ctrl_axis_fifo]

# check if 'hdl_sim' directory already exist
set sim_src_exist [file exists hdl_sim/]

if {${sim_src_exist} == 0} {
  # create directory
  file mkdir hdl_sim/

  # symlink sources
  set curdir [pwd]
  file link -symbolic hdl_sim/nt_gen_rate_ctrl_axis_fifo.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_gen_rate_ctrl_axis_fifo/sim/nt_gen_rate_ctrl_axis_fifo.v
  file link -symbolic hdl_sim/axis_data_fifo_v1_1_vl_rfs.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_gen_rate_ctrl_axis_fifo/hdl/axis_data_fifo_v1_1_vl_rfs.v
  file link -symbolic hdl_sim/fifo_generator_v13_1_rfs.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_gen_rate_ctrl_axis_fifo/hdl/fifo_generator_v13_1_rfs.v
  file link -symbolic hdl_sim/fifo_generator_vlog_beh.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_gen_rate_ctrl_axis_fifo/simulation/fifo_generator_vlog_beh.v
  file link -symbolic hdl_sim/axis_infrastructure_v1_1_vl_rfs.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_gen_rate_ctrl_axis_fifo/hdl/axis_infrastructure_v1_1_vl_rfs.v
  file link -symbolic hdl_sim/axis_infrastructure_v1_1_0.vh \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_gen_rate_ctrl_axis_fifo/hdl/axis_infrastructure_v1_1_0.vh
  file link -symbolic hdl_sim/xpm_cdc.sv \
  $::env(XILINX_VIVADO)/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv
}

ipx::package_project -force -import_files nt_gen_rate_ctrl_axis_fifo.xci

ipx::infer_bus_interface clk156 xilinx.com:signal:clock_rtl:1.0 \
  [ipx::current_core]
ipx::infer_bus_interface rstn156 xilinx.com:signal:reset_rtl:1.0 \
  [ipx::current_core]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis -of_objects \
  [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis -of_objects \
  [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axi_ctrl -of_objects \
  [ipx::current_core]]
ipx::add_bus_parameter ASSOCIATED_BUSIF \
  [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]
set_property value m_axis:s_axis:s_axi_ctrl \
  [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects \
  [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]]

source ../ip_create_end.tcl
