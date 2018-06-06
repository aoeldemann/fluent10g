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
# Creates the nt_gen_replay IP core.

set design nt_gen_replay
set top nt_gen_replay_top

source ../ip_create_start.tcl

read_verilog "./hdl/nt_gen_replay_top.v"
read_verilog "./hdl/nt_gen_replay_cpuregs.v"
read_verilog "./hdl/nt_gen_replay_cpuregs_defines.vh"
read_verilog "./hdl/nt_gen_replay_mem_read.v"
read_verilog "./hdl/nt_gen_replay_assemble.v"

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 \
  -module_name nt_gen_replay_mem_read_fifo
set_property -dict [list \
                    CONFIG.Performance_Options {First_Word_Fall_Through} \
                    CONFIG.Input_Data_Width {512} CONFIG.Input_Depth {1024} \
                    CONFIG.Almost_Full_Flag {false} \
                    CONFIG.Programmable_Full_Type \
                      {Single_Programmable_Full_Threshold_Constant} \
                    CONFIG.Full_Threshold_Assert_Value {752} \
                    CONFIG.Output_Data_Width {64} CONFIG.Output_Depth {8192} \
                    CONFIG.Use_Extra_Logic {true} CONFIG.Data_Count_Width {11} \
                    CONFIG.Write_Data_Count_Width {11} \
                    CONFIG.Read_Data_Count_Width {14} \
                    CONFIG.Full_Threshold_Negate_Value {751} \
                    CONFIG.Empty_Threshold_Assert_Value {4} \
                    CONFIG.Empty_Threshold_Negate_Value {5}] \
  [get_ips nt_gen_replay_mem_read_fifo]

# to perform behavioral simulations we need generated simulation sources for
# the fifo, generate them
generate_target simulation [get_ips nt_gen_replay_mem_read_fifo]

# check if 'hdl_sim' directory already exist
set sim_src_exist [file exists hdl_sim/]

if {${sim_src_exist} == 0} {
  # create directory
  file mkdir hdl_sim/

  # symlink sources
  set curdir [pwd]
  file link -symbolic hdl_sim/nt_gen_replay_mem_read_fifo.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_gen_replay_mem_read_fifo/sim/nt_gen_replay_mem_read_fifo.v
  file link -symbolic hdl_sim/fifo_generator_v13_1_rfs.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_gen_replay_mem_read_fifo/hdl/fifo_generator_v13_1_rfs.v
  file link -symbolic hdl_sim/fifo_generator_vlog_beh.v \
  ${curdir}/${proj_dir}/${design}.srcs/sources_1/ip/nt_gen_replay_mem_read_fifo/simulation/fifo_generator_vlog_beh.v
}

ipx::package_project -force -import_files nt_gen_replay_mem_read_fifo.xci

source ../ip_create_end.tcl
