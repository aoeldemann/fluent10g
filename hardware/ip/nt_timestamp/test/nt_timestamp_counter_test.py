"""Test bench for the Verilog module 'nt_timestamp'."""
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
# Test bench for the Verilog module 'nt_timestamp'.

import cocotb
from lib.tb import clk_gen, rstn, wait_n_cycles
from lib.axilite import AXI_Lite_Writer
from nt_timestamp_cpuregs_defines import *

CLK_FREQ_MHZ = 156.25
AXI_DATA_WIDTH = 32


@cocotb.test()
def nt_timestamp_test(dut):
    """Main test bench function.

    TODO: no automatic validation of DUT output yet. Look at waveforms.
    """
    # start the clock
    cocotb.fork(clk_gen(dut.clk156, CLK_FREQ_MHZ))

    # reset dut
    yield rstn(dut.clk156, dut.rstn156)

    # create axi lite writer, connect and reset
    axi_writer = AXI_Lite_Writer()
    axi_writer.connect(dut, dut.clk156, AXI_DATA_WIDTH, "ctrl")
    yield axi_writer.rst()

    # run simulation for a while
    yield wait_n_cycles(dut.clk156, 1000)

    # set number of clock cycles which shall pass until counter is incremented
    # to 10
    yield axi_writer.write(CPUREG_OFFSET_CTRL_CYCLES_PER_TICK, 10)

    # run simulation for a while
    yield wait_n_cycles(dut.clk156, 1000)
