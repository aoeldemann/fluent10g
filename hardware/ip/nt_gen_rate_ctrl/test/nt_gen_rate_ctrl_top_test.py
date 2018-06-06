"""Test bench for the Verilog module 'nt_gen_rate_ctrl'."""
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
# Test bench for the Verilog module 'nt_gen_rate_ctrl'.

import cocotb
from cocotb.triggers import RisingEdge
from lib.axis import AXIS_Reader, AXIS_Writer
from lib.axilite import AXI_Lite_Reader, AXI_Lite_Writer
from lib.tb import clk_gen, rstn, wait_n_cycles, toggle_signal, print_progress
from lib.net import gen_packet, packet_to_axis_data, axis_data_to_packet
import random
from scapy.all import *
from nt_gen_rate_ctrl_cpuregs_defines import *

CLK_FREQ_MHZ = 156.25
N_PACKETS = 500
AXIS_BIT_WIDTH = 64
AXI_CTRL_BIT_WIDTH = 32

cntr_cycles_between_axis_transmission = 0


@cocotb.coroutine
def count_cycles_between_axis_transmission(dut):
    """Count clock cycles between two AXI4-Stream transmissions."""
    global cntr_cycles_between_axis_transmission

    # initialize local counter
    cntr = 0

    # currently no transaction on the AXI4-Stream
    trans_active = False

    while True:
        # increase local counter every clock cycle
        yield RisingEdge(dut.clk156)
        cntr += 1

        # wait for TVALID to become high
        if int(dut.m_axis_tvalid):
            if not trans_active:
                # if this starts a new transaction, we copy the local counter
                # value to the global one
                cntr_cycles_between_axis_transmission = cntr

                # reset local counter
                cntr = 0

            # transaction is finished when TLAST is high
            trans_active = int(dut.m_axis_tlast) == 0


@cocotb.coroutine
def packets_write(dut, axis_writer, pkts):
    """Apply packets on DuT input."""
    for (pkt, inter_packet_cycles) in pkts:
        # convert pkt to AXI4-Stream data
        (tdata, tkeep) = packet_to_axis_data(pkt, AXIS_BIT_WIDTH)

        # insert inter-packet time in TUSER signal for first transfer word
        tuser = [inter_packet_cycles]

        # write AXI4-Stream data (do not insert idle gaps)
        yield axis_writer.write(tdata, tkeep, tuser, False)


@cocotb.coroutine
def packets_read(dut, axis_reader, pkts_ref, check_timing):
    """Check DuT output for correctness."""
    p = None
    for i, (pkt_ref, inter_packet_cycles_ref) in enumerate(pkts_ref):
        # read AXI4-Stream data
        (tdata, tkeep, _) = yield axis_reader.read()

        # convert AXI4-Stream data to scapy packet
        pkt = axis_data_to_packet(tdata, tkeep, AXIS_BIT_WIDTH)

        # make sure packets match
        if str(pkt) != str(pkt_ref):
            raise cocotb.result.TestFailure("Packet #%d: wrong data" % i)

        # get cycles since between transmissions
        cycles_transmission = cntr_cycles_between_axis_transmission

        if check_timing and i > 0 \
                and cntr_cycles_between_axis_transmission != p:
            raise cocotb.result.TestFailure(("Packet #%d: wrong timing, " +
                                             "Cycles IS: %d " +
                                             "Cycles Expected %d ") %
                                            (i, cycles_transmission, p))

        p = inter_packet_cycles_ref

        # print progress
        print_progress(i, N_PACKETS)


@cocotb.test()
def nt_gen_rate_ctrl_top_test(dut):
    """Test bench main function."""
    # initially module is inactive
    dut.active_i <= 0

    # no software reset
    dut.rst_sw156 <= 0

    # start the clock
    cocotb.fork(clk_gen(dut.clk156, CLK_FREQ_MHZ))

    # reset the DuT
    yield rstn(dut.clk156, dut.rstn156)

    # create AXI4-Stream writer and reader
    axis_writer = AXIS_Writer()
    axis_writer.connect(dut, dut.clk156, AXIS_BIT_WIDTH)
    yield axis_writer.rst()

    axis_reader = AXIS_Reader()
    axis_reader.connect(dut, dut.clk156, AXIS_BIT_WIDTH)
    yield axis_reader.rst()

    # create AXI4-Lite writer and connect to DuT
    axi_lite_writer = AXI_Lite_Writer()
    axi_lite_writer.connect(dut, dut.clk156, AXI_CTRL_BIT_WIDTH, "ctrl")
    yield axi_lite_writer.rst()

    # create AXI4-Lite reader and connect to DuT
    axi_lite_reader = AXI_Lite_Reader()
    axi_lite_reader.connect(dut, dut.clk156, AXI_CTRL_BIT_WIDTH, "ctrl")
    yield axi_lite_reader.rst()

    # initially we are always ready to receive
    dut.m_axis_tready <= 1

    # start a coroutine that counts the number of cycles between two packets
    # on the output axi stream
    cocotb.fork(count_cycles_between_axis_transmission(dut))

    print("Test 1/4")

    # generate some packets and inter-packet times. we start with a constant
    # inter-packet time of 200 cycles, more than enough to transmit each packet
    pkts = []
    for _ in range(N_PACKETS):
        pkts.append((gen_packet(), 200))

    # write packet data
    cocotb.fork(packets_write(dut, axis_writer, pkts))

    # wait a little
    yield wait_n_cycles(dut.clk156, 500)

    # start the module
    dut.active_i <= 1

    # start coroutine that checks output and wait until it completes
    yield cocotb.fork(packets_read(dut, axis_reader, pkts, True))

    # deactive the module
    dut.active_i <= 0

    # make sure no warning was flagged
    status = yield axi_lite_reader.read(CPUREG_OFFSET_STATUS)
    assert status == 0x0

    print("Test 2/4")

    # now generate packets of fixed size of 800 bytes. Since the datapath is
    # 8 byte wide, it will take exactly 100 cycles to send them. Also select
    # a fixed inter-packet time of 100 cycles. packets should be sent
    # back-to-back
    pkts = []
    for _ in range(N_PACKETS):
        pkt = Ether(src="53:00:00:00:00:01", dst="53:00:00:00:00:02")
        pkt /= ''.join(chr(random.randint(0, 255)) for _ in
                       range(800-len(pkt)))
        pkts.append((pkt, 100))

    # apply packet data
    cocotb.fork(packets_write(dut, axis_writer, pkts))

    # wait a little
    yield wait_n_cycles(dut.clk156, 1000)

    # start the module
    dut.active_i <= 1

    # start coroutine that checks output and wait until it completes
    yield cocotb.fork(packets_read(dut, axis_reader, pkts, True))

    # deactive the module
    dut.active_i <= 0

    # make sure no warning was flagged
    status = yield axi_lite_reader.read(CPUREG_OFFSET_STATUS)
    assert status == 0x0

    print("Test 3/4")

    # repeat the experiment, but decrement inter-packet time to 99 cycles.
    # since inter-packet time is smaller than the packet transmit time, we
    # should get a warning
    pkts = []
    for _ in range(N_PACKETS):
        pkt = Ether(src="53:00:00:00:00:01", dst="53:00:00:00:00:02")
        pkt /= ''.join(chr(random.randint(0, 255)) for _ in
                       range(800-len(pkt)))
        pkts.append((pkt, 99))

    # apply packet data
    cocotb.fork(packets_write(dut, axis_writer, pkts))

    # wait a little
    yield wait_n_cycles(dut.clk156, 500)

    # start the module
    dut.active_i <= 1

    # start coroutine that checks output and wait until it completes
    yield cocotb.fork(packets_read(dut, axis_reader, pkts, False))

    # deactive the module
    dut.active_i <= 0

    # make sure a warning was flagged
    status = yield axi_lite_reader.read(CPUREG_OFFSET_STATUS)
    assert status == 0x1

    # perform software reset to clear warning flag
    yield axi_lite_writer.write(CPUREG_OFFSET_RST, 0x1)

    # now start toggeling tready
    cocotb.fork(toggle_signal(dut.clk156, dut.m_axis_tready))

    print("Test 4/4")

    # repeat the experiment, inter-packet time back at 100 cycles. since the
    # slave is not always ready to receive, this should cause a warning
    pkts = []
    for _ in range(N_PACKETS):
        pkt = Ether(src="53:00:00:00:00:01", dst="53:00:00:00:00:02")
        pkt /= ''.join(chr(random.randint(0, 255)) for _ in
                       range(800-len(pkt)))
        pkts.append((pkt, 100))

    # apply packet data
    cocotb.fork(packets_write(dut, axis_writer, pkts))

    # wait a little
    yield wait_n_cycles(dut.clk156, 500)

    # start the module
    dut.active_i <= 1

    # start coroutine that checks output and wait until it completes
    yield cocotb.fork(packets_read(dut, axis_reader, pkts, False))

    # deactive the module
    dut.active_i <= 0

    # make sure no warning was flagged
    status = yield axi_lite_reader.read(CPUREG_OFFSET_STATUS)
    assert status == 0x1
