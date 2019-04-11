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
# Creates the nt_datarate IP core.

set design nt_datarate
set top nt_datarate_top

source ../ip_create_start.tcl

read_verilog "./hdl/nt_datarate_top.v"
read_verilog "./hdl/nt_datarate.v"
read_verilog "./hdl/nt_datarate_cpuregs.v"
read_verilog "./hdl/nt_datarate_cpuregs_defines.vh"

ipx::package_project -force -import_files

ipx::infer_bus_interface clk156 xilinx.com:signal:clock_rtl:1.0 \
  [ipx::current_core]
ipx::infer_bus_interface rstn156 xilinx.com:signal:reset_rtl:1.0 \
  [ipx::current_core]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis_tx -of_objects \
  [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis_rx -of_objects \
  [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis_tx -of_objects \
  [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis_rx -of_objects \
  [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axi -of_objects \
  [ipx::current_core]]
ipx::add_bus_parameter ASSOCIATED_BUSIF \
  [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]
set_property value m_axis_tx:s_axis_tx:m_axis_rx:s_axis_rx:s_axi \
  [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects \
  [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]]

source ../ip_create_end.tcl
