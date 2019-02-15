"""Test bench for the Verilog module 'nt_recv_capture_fifo_merge'."""
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
# Test bench for the Verilog module 'nt_recv_capture_fifo_merge'.

import cocotb
import random
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, wait_n_cycles, check_value, print_progress

CLK_FREQ_MHZ = 200
N_PACKETS = 100
N_REPEATS = 15


def gen_input_data(max_len_capture):
    """Generate packet input data and the according meta information.

    The function generates random data for a total of N_PACKETS packets. For
    each packet a 64 bit meta data word including a (random) latency timestamp,
    inter-packet time, as well as the wire and capture length is generated.
    The function parameter max_len_capture defines the maximum capture length.
    The function returns two list of 64 data words, one containing the packet
    data, one containing the meta data.
    """
    meta = []
    data = []

    for _ in range(N_PACKETS):
        # determine random packet size
        len_wire = random.randint(0, 1514)

        # determine the acutal packet capure length
        len_capture = min(len_wire, max_len_capture)

        # calculate the number of 64 bit data words for the captured data
        if len_capture % 8 == 0:
            len_capture_words = len_capture / 8
        else:
            len_capture_words = len_capture / 8 + 1

        # generate random data words
        for _ in range(len_capture_words):
            data.append(random.randint(0, 2**64-1))

        # randomly set bits [52:0] of the meta data
        meta_word = random.randint(0, 2**53-1)

        # set wire length
        meta_word |= len_wire << 53

        # set capture length
        meta_word |= len_capture << 64

        # append meta data word to list
        meta.append(meta_word)

    # return generated data
    return (meta, data)


@cocotb.coroutine
def apply_input(dut, meta, data):
    """Apply meta data and packet data as DUT stimulus.

    Meta data is written to the input meta data FIFO, packet data is written
    to the input packet data FIFO.
    """
    # data word index
    i = 0

    # iterate over meta data words
    for m in meta:
        # get the capture length
        len_capture = (m >> 64) & 0x7FF

        # calculate the number of 64 bit data words
        if len_capture % 8 == 0:
            len_capture_words = len_capture / 8
        else:
            len_capture_words = len_capture / 8 + 1

        # apply data words at DUT input
        for _ in range(len_capture_words):
            # get data word and increment index
            d = data[i]
            i += 1

            # make sure input data fifo is not full
            check_value("fifo_data_full_i", dut.fifo_data_full_o, 0x0)

            # apply data word
            dut.fifo_data_din_i <= d
            dut.fifo_data_wr_en_i <= 1
            yield RisingEdge(dut.clk)

        # done writing data
        dut.fifo_data_wr_en_i <= 0

        # wait a random number of cycles until applying the meta data word
        yield wait_n_cycles(dut.clk, random.randint(0, 10))

        # make sure input meta data fifo is not full
        check_value("fifo_meta_full_o", dut.fifo_meta_full_o, 0x0)

        # apply meta data word
        dut.fifo_meta_din_i <= m
        dut.fifo_meta_wr_en_i <= 1
        yield RisingEdge(dut.clk)

        # done applying meta data
        dut.fifo_meta_wr_en_i <= 0

        # wait a random number of cycles again
        yield wait_n_cycles(dut.clk, random.randint(0, 10))


@cocotb.coroutine
def check_output(dut, meta_ref, data_ref, max_capture_len):
    """Verify that the DUT's output is correct."""
    # data word index
    j = 0

    # iterate over meta data words
    for i, m_ref in enumerate(meta_ref):
        # wait until fifo output becomes valid
        while True:
            yield RisingEdge(dut.clk)
            if int(dut.fifo_wr_en_o):
                break

        # read the meta data word
        m = int(dut.fifo_din_o)

        # make sure meta data word matches the expected one (bits 74:64
        # contain the packet capture length, which is not passed to software)
        if m != m_ref & 0xFFFFFFFFFFFFFFFF:
            raise cocotb.result.TestFailure("Packet #%d: invalid meta data" %
                                            i)

        # get the wire length
        len_wire = (m >> 53) & 0x7FF

        # calculate the capture length
        len_capture = min(len_wire, max_capture_len)

        # calculate how many data words we are expecting
        if len_capture % 8 == 0:
            len_capture_words = len_capture / 8
        else:
            len_capture_words = len_capture / 8 + 1

        for _ in range(len_capture_words):
            # get the reference data word and increment index
            d_ref = data_ref[j]
            j += 1

            # wait until fifo output becomes valid
            while True:
                yield RisingEdge(dut.clk)
                if int(dut.fifo_wr_en_o):
                    break

            # read data word
            d = int(dut.fifo_din_o)

            # make sure fifo output data matches the data word we are expecting
            if d != d_ref:
                raise cocotb.result.TestFailure("Packet #%d: invalid data" % i)

        # print progress
        print_progress(i, len(meta_ref))

    # ensure that all data has been read
    if j != len(data_ref):
        raise cocotb.result.TestFailure("did not read all data")


@cocotb.test()
def nt_recv_capture_fifo_merge(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk, CLK_FREQ_MHZ))

    # do not issue software reset
    dut.rst_sw <= 0

    # output fifo is never full
    dut.fifo_full_i <= 0

    # intially not writing to input fifos
    dut.fifo_meta_wr_en_i <= 0
    dut.fifo_data_wr_en_i <= 0

    # reset the dut
    yield rstn(dut.clk, dut.rstn)

    # wait a few cycles
    yield wait_n_cycles(dut.clk, 5)

    for i in range(N_REPEATS):
        # print out some status
        print("Test %d/%d" % (i+1, N_REPEATS))

        # determine random maximum capture length
        max_len_capture = random.randint(0, 1514)

        # generate packet and meta data
        (meta, data) = gen_input_data(max_len_capture)

        # start stimulus coroutine
        cocotb.fork(apply_input(dut, meta, data))

        # start coroutine checking output
        coroutine_chk = cocotb.fork(check_output(dut, meta, data,
                                                 max_len_capture))

        # wat for checking coroutine to complete
        yield coroutine_chk.join()
