"""Test bench for Verilog module 'nt_recv_capture_mem_write_fifo_wrapper'."""
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
# Test bench for the Verilog module 'nt_recv_capture_mem_write_fifo_wrapper'.

import cocotb
import random
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, wait_n_cycles

CLK_FREQ_MHZ = 200

# number of 64 bit data words that are written to the FIFO for each test run
N_INPUT_WORDS = [8, 16, 27, 99, 137, 256, 257, 258, 879, 1111, 2222, 3333]


def gen_input_data(n_words):
    """Generate and return n_words 64 bit data words."""
    data64 = []
    for _ in range(n_words):
        # append random 64 bit data word
        data64.append(random.randint(0, 2**64-1))
    return data64


def convert_data_64_to_512(data64):
    """Convert the DUT 64 bit input data words to 512 bit output data words."""
    data512 = []

    # convert 64 bit data to 512 bit data (see Xilinx FIFO Generator spec
    # for information on 64 bit word order).
    i = 0
    while i < len(data64):
        if i % 8 == 0:
            d = data64[i] << 448
        else:
            d |= data64[i] << (64*(7-i % 8))

        if i % 8 == 7 or i == len(data64) - 1:
            data512.append(d)
        i += 1

    # append alignment
    while i % 8 != 0:
        data512[-1] |= 0xFFFFFFFFFFFFFFFF << (64*(7-i % 8))
        i += 1

    return data512


@cocotb.coroutine
def apply_input(dut, data64):
    """Apply data at DUT input."""
    for d in data64:
        # wait for FIFO not full
        while True:
            if int(dut.full_o) == 0:
                break
            yield RisingEdge(dut.clk)

        # apply input data
        dut.din_i <= d
        dut.wr_en_i <= 1
        yield RisingEdge(dut.clk)

        dut.wr_en_i <= 0


@cocotb.coroutine
def trigger_align(dut, data64):
    """Trigger 512 bit alignment."""
    if len(data64) % 8 == 0:
        # nothing to do here
        yield RisingEdge(dut.clk)
        return

    # wait until all input data has been written to the FIFO
    i = 0
    while i < len(data64):
        if int(dut.full_o) == 0 and int(dut.wr_en_i) == 1:
            i += 1
        yield RisingEdge(dut.clk)

    # trigger alignment
    dut.align_i <= 1
    yield RisingEdge(dut.clk)
    dut.align_i <= 0

    # wait for alignment to complete
    while True:
        yield RisingEdge(dut.clk)
        if int(dut.align_done_o):
            break

    # done signal must go low after one clock cycle
    yield RisingEdge(dut.clk)
    if int(dut.align_done_o) != 0:
        raise cocotb.result.TestFailure("align_done_o does not go low")


@cocotb.coroutine
def check_output(dut, data512):
    """Verify that the DuT's output is correct."""
    # keep reading
    dut.rd_en_i <= 1

    for d in data512:
        # wait for FIFO to become non-empty
        while True:
            yield RisingEdge(dut.clk)
            if int(dut.empty_o) == 0:
                break

        if int(dut.dout_o) != d:
            raise cocotb.result.TestFailure("received wrong data")

    yield RisingEdge(dut.clk)

    # fifo should now stay empty
    for _ in range(100):
        if int(dut.empty_o) == 0:
            raise cocotb.result.TestFailure("FIFO does not remain empty")
        yield RisingEdge(dut.clk)


@cocotb.test()
def nt_recv_capture_mem_write_fifo_wrapper_test(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk, CLK_FREQ_MHZ))

    # do not issue software reset
    dut.rst_sw <= 0

    # initially we do not read or write data to the FIFO
    dut.rd_en_i <= 0
    dut.wr_en_i <= 0

    # initially do not add alignment data
    dut.align_i <= 0

    # reset the dut
    yield rstn(dut.clk, dut.rstn)

    # wait a few cycles
    yield wait_n_cycles(dut.clk, 10)

    for i, n_words in enumerate(N_INPUT_WORDS):
        print("Test %d/%d" % (i+1, len(N_INPUT_WORDS)))

        # generate 64 bit input data
        data64 = gen_input_data(n_words)

        # convert 64 bit input data to 512 bit output data
        data512 = convert_data_64_to_512(data64)

        # start input coroutine
        coroutine_in = cocotb.fork(apply_input(dut, data64))

        # start ouput coroutine
        coroutine_out = cocotb.fork(check_output(dut, data512))

        # start one coroutine for triggering aligment
        coroutine_align = cocotb.fork(trigger_align(dut, data64))

        # wait for coroutines to complete
        yield coroutine_in.join()
        yield coroutine_out.join()
        yield coroutine_align.join()
