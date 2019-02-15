"""Test bench for the Verilog module 'nt_recv_filter_mac_top'."""
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
# Test bench for the Verilog module 'nt_recv_filter_mac_top'.

import cocotb
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, wait_n_cycles, toggle_signal, print_progress
from lib.net import gen_packet, packet_to_axis_data, axis_data_to_packet
from lib.axilite import AXI_Lite_Writer
from lib.axis import AXIS_Reader, AXIS_Writer
from nt_recv_filter_mac_cpureg_defines import *
from random import randint

# clock frequency in MHz
CLK_FREQ_MHZ = 200

# AXI4-Stream bit width
AXIS_BIT_WIDTH = 64

# AXI4-Lite bit width
AXI_CTRL_BIT_WIDTH = 32

# number of frames to generate per run
N_FRAMES = 50

# number of runs
N_RUNS = 20


@cocotb.coroutine
def frames_write(dut, axis_writer, frames):
    """Apply generated frames on DuT input."""
    # iterate over frames
    for frame in frames:
        # convert frame to AXI4-Stream data
        (tdata, tkeep) = packet_to_axis_data(frame, AXIS_BIT_WIDTH)

        # write frame
        yield axis_writer.write(tdata, tkeep, [])

        # wait a random number of cycles before writing next frame
        yield wait_n_cycles(dut.clk, randint(0, 10))


@cocotb.coroutine
def frames_read(dut, axis_reader, frames_ref):
    """Evaluate data at DuT output and validates correct behavior."""
    # iterate over the list of frames that we are expecting to read
    for i, frame_ref in enumerate(frames_ref):
        # read AXI4-Stream data
        (tdata, tkeep, _) = yield axis_reader.read()

        # convert AXI4-Stream data to scapy frame
        frame = axis_data_to_packet(tdata, tkeep, AXIS_BIT_WIDTH)

        # check if written and read frames are equal
        if str(frame) != str(frame_ref):
            raise cocotb.result.TestFailure("Frame #%d: invalid data" % i)

        # print progress
        print_progress(i, N_FRAMES)


def mac_addr_str(mac_addr):
    """Convert a number to a colon-separated MAC address string."""
    hexDecoded = ("%012X" % mac_addr).decode('hex')
    return ':'.join(s.encode('hex') for s in hexDecoded)


def mac_addr_reverse_byte_order(mac_addr):
    """Reverse the byte order of a 48 bit MAC address."""
    mac_addr_reversed = 0
    for i in range(6):
        mac_addr_reversed |= ((mac_addr >> 8*i) & 0xFF) << 8*(5-i)
    return mac_addr_reversed


@cocotb.coroutine
def perform_test(dut, axi_lite_writer, axis_writer, axis_reader):
    """Perform a test run with randomly generated MAC addresses."""
    # generate random length of the MAC address prefix that the module should
    # match on
    len_prefix = randint(0, 48)

    # generate MAC address prefix bit masks
    prefix_bitmask = (2**len_prefix-1) << (48 - len_prefix)

    # generate the actual prefix
    prefix = randint(0, 2**len_prefix - 1) << (48 - len_prefix)

    # generate frames with destination MAC addresses that match the prefix
    frames_valid = []
    for _ in range(N_FRAMES):
        # generate random frame
        frame = gen_packet()

        # generate random MAC addresses with the previously determined prefix
        addr_dst = prefix + randint(0, 2**(48 - len_prefix) - 1)

        # set address
        frame.dst = mac_addr_str(addr_dst)

        # save the frame
        frames_valid.append(frame)

    # we next generate some frames with a destination MAC address that will
    # not match. This only works if the prefix length is larger than zero.
    frames_invalid = []
    if len_prefix > 0:
        for _ in range(N_FRAMES):
            # generate random frame
            frame = gen_packet()

            addr_dst = prefix

            while (addr_dst == prefix):
                addr_dst = randint(0, 2**len_prefix - 1) \
                    << (48 - len_prefix)

            # add some random value that is not matched anyways
            addr_dst += randint(0, 2**(48 - len_prefix) - 1)

            # set address
            frame.dst = mac_addr_str(addr_dst)

            # save frame
            frames_invalid.append(frame)

    # randomly merge both valid and invalid frames in a new list
    frames_merged = []
    frames = [frames_valid, frames_invalid]
    i = [0, 0]
    while True:
        if i[0] == len(frames[0]) and i[1] == len(frames[1]):
            break
        elif i[0] == len(frames[0]):
            x = 1
        elif i[1] == len(frames[1]):
            x = 0
        else:
            x = randint(0, 1)
        frames_merged.append(frames[x][i[x]])
        i[x] += 1

    assert len(frames_merged) == len(frames_valid) + len(frames_invalid)

    # write destination address
    yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_ADDR_DST_HI,
                                mac_addr_reverse_byte_order(prefix) >> 32)
    yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_ADDR_DST_LO,
                                mac_addr_reverse_byte_order(prefix) &
                                0xFFFFFFFF)

    # write destination address bit mask
    yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_ADDR_MASK_DST_HI,
                                mac_addr_reverse_byte_order(prefix_bitmask)
                                >> 32)
    yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_ADDR_MASK_DST_LO,
                                mac_addr_reverse_byte_order(prefix_bitmask)
                                & 0xFFFFFFFF)

    # start one coroutine that applies valid and invalid frames on input
    coroutine_send = cocotb.fork(frames_write(dut, axis_writer, frames_merged))

    # start one coroutine to evaluate frames on dut output, should only see
    # the valid ones
    coroutine_recv = cocotb.fork(frames_read(dut, axis_reader, frames_valid))

    # wait for coroutines to complete
    yield coroutine_send.join()
    yield coroutine_recv.join()

    # make sure no more frames are arriving in the next cycles
    for _ in range(200):
        yield RisingEdge(dut.clk)
        if int(dut.m_axis_tvalid):
            raise cocotb.result.TestFailure("recv'd more frames than expected")


@cocotb.test()
def nt_recv_filter_mac_top_test(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk, CLK_FREQ_MHZ))

    # no software reset
    dut.rst_sw <= 0

    # reset the dut
    yield rstn(dut.clk, dut.rstn)

    # create, connect and reset AXI4-Lite writer
    axi_lite_writer = AXI_Lite_Writer()
    axi_lite_writer.connect(dut, dut.clk, AXI_CTRL_BIT_WIDTH, "ctrl")
    yield axi_lite_writer.rst()

    # create and reset AXI4-Stream writer
    axis_writer = AXIS_Writer()
    axis_writer.connect(dut, dut.clk, AXIS_BIT_WIDTH)
    yield axis_writer.rst()

    # create and reset AXI4-Stream reader
    axis_reader = AXIS_Reader()
    axis_reader.connect(dut, dut.clk, AXIS_BIT_WIDTH)
    yield axis_reader.rst()

    # start random toggling of axi stream reader tready
    cocotb.fork(toggle_signal(dut.clk, dut.m_axis_tready))

    # perform a set of test. each run will generate its own random mac
    # addresses
    for i in range(N_RUNS):
        print("Test %d/%d" % (i+1, N_RUNS))
        yield perform_test(dut, axi_lite_writer, axis_writer, axis_reader)
