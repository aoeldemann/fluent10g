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
# Creates the nt_recv_capture IP core.

set design nt_recv_capture
set top nt_recv_capture_top

source ../ip_create_start.tcl

read_verilog "./hdl/nt_recv_capture_top.v"
read_verilog "./hdl/nt_recv_capture_cpuregs.v"
read_verilog "./hdl/nt_recv_capture_cpuregs_defines.vh"
read_verilog "./hdl/nt_recv_capture_ctrl.v"
read_verilog "./hdl/nt_recv_capture_mem_write.v"
read_verilog "./hdl/nt_recv_capture_mem_write_fifo_wrapper.v"
read_verilog "./hdl/nt_recv_capture_rx.v"
read_verilog "./hdl/nt_recv_capture_fifo_merge.v"

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 \
  -module_name nt_recv_capture_mem_write_fifo
set_property -dict [list \
                    CONFIG.Performance_Options {First_Word_Fall_Through} \
                    CONFIG.Input_Data_Width {64} CONFIG.Input_Depth {8192} \
                    CONFIG.Almost_Empty_Flag {false} CONFIG.Read_Data_Count {true} \
                    CONFIG.Programmable_Empty_Type \
                      {Single_Programmable_Empty_Threshold_Constant} \
                    CONFIG.Empty_Threshold_Assert_Value {255} \
                    CONFIG.Output_Data_Width {512} CONFIG.Output_Depth {1024} \
                    CONFIG.Use_Extra_Logic {true} CONFIG.Data_Count_Width {14} \
                    CONFIG.Write_Data_Count_Width {14} \
                    CONFIG.Read_Data_Count_Width {11} \
                    CONFIG.Full_Threshold_Assert_Value {8191} \
                    CONFIG.Full_Threshold_Negate_Value {8190} \
                    CONFIG.Empty_Threshold_Negate_Value {256}] \
  [get_ips nt_recv_capture_mem_write_fifo]

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 \
  -module_name nt_recv_capture_meta_fifo
set_property -dict [list \
                    CONFIG.Performance_Options {First_Word_Fall_Through} \
                    CONFIG.Input_Data_Width {75} CONFIG.Input_Depth {256} \
                    CONFIG.Output_Data_Width {75} CONFIG.Output_Depth {256} ] \
  [get_ips nt_recv_capture_meta_fifo]

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 \
  -module_name nt_recv_capture_data_fifo
set_property -dict [list \
                    CONFIG.Performance_Options {First_Word_Fall_Through} \
                    CONFIG.Input_Data_Width {64} CONFIG.Input_Depth {256} \
                    CONFIG.Output_Data_Width {64} CONFIG.Output_Depth {256} ] \
  [get_ips nt_recv_capture_data_fifo]

# to perform behavioral simulations we need generated simulation sources for
# the fifos, generate them
generate_target simulation [get_ips nt_recv_capture_mem_write_fifo]
generate_target simulation [get_ips nt_recv_capture_meta_fifo]
generate_target simulation [get_ips nt_recv_capture_data_fifo]

# check if 'hdl_sim' directory already exist
set sim_src_exist [file exists hdl_sim/]

if {${sim_src_exist} == 0} {
  # create directory
  file mkdir hdl_sim/

  # symlink sources
  set curdir [pwd]
  file link -symbolic hdl_sim/nt_recv_capture_mem_write_fifo.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_recv_capture_mem_write_fifo/sim/nt_recv_capture_mem_write_fifo.v
  file link -symbolic hdl_sim/nt_recv_capture_meta_fifo.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_recv_capture_meta_fifo/sim/nt_recv_capture_meta_fifo.v
  file link -symbolic hdl_sim/nt_recv_capture_data_fifo.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_recv_capture_data_fifo/sim/nt_recv_capture_data_fifo.v
  file link -symbolic hdl_sim/fifo_generator_v13_1_rfs.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_recv_capture_mem_write_fifo/hdl/fifo_generator_v13_1_rfs.v
  file link -symbolic hdl_sim/fifo_generator_vlog_beh.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_recv_capture_mem_write_fifo/simulation/fifo_generator_vlog_beh.v
}

ipx::package_project -force -import_files nt_recv_capture_mem_write_fifo.xci

source ../ip_create_end.tcl
