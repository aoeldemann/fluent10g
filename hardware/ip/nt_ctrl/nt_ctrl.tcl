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
# Creates the nt_ctrl IP core.

set design nt_ctrl
set top nt_ctrl_top

source ../ip_create_start.tcl

read_verilog "./hdl/nt_ctrl_top.v"
read_verilog "./hdl/nt_ctrl_cpuregs.v"
read_verilog "./hdl/nt_ctrl_cpuregs_defines.vh"

ipx::package_project

# make sure 'clk156' and 'rstn156' pins are inferred as clock and reset pins
ipx::infer_bus_interface clk156 xilinx.com:signal:clock_rtl:1.0 \
  [ipx::current_core]
ipx::infer_bus_interface rstn156 xilinx.com:signal:reset_rtl:1.0 \
  [ipx::current_core]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axi -of_objects \
  [ipx::current_core]]

# vivado infers 's_axi' interface to be in 'clk' clock domain. however, it is in
# the 'clk156' domain. remove ASSOCIATED_BUSIF parameter from 'clk' signal
ipx::remove_bus_parameter ASSOCIATED_BUSIF \
  [ipx::get_bus_interfaces clk -of_objects [ipx::current_core]]

# associate 's_axi' interface with 'clk156' clock
ipx::add_bus_parameter ASSOCIATED_BUSIF \
  [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]
set_property value s_axi \
  [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects \
  [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]]

# associate 'rstn' pin with 'clk' clock
set_property value rstn \
  [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects \
  [ipx::get_bus_interfaces clk -of_objects [ipx::current_core]]]

# associate 'rstn156' pin with 'clk156' clock
set_property value rstn156 \
  [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects \
  [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]]

source ../ip_create_end.tcl
