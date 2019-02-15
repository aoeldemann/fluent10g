"""Test bench for the Verilog module 'nt_recv_interpackettime'."""
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
# Test bench for verilog module 'nt_recv_interpackettime'.

import cocotb
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, wait_n_cycles, toggle_signal, print_progress
from lib.net import gen_packet, packet_to_axis_data, axis_data_to_packet
from lib.axis import AXIS_Reader, AXIS_Writer
from random import randint

# set some parameters
N_PACKETS = 1000
AXIS_BIT_WIDTH = 64
CLK_FREQ_MHZ = 156.25

# for the last AXI4-Stream transaction of a packet (i.e. TLAST high), the DuT
# module passes through the 25 LSB of the TUSER signal from slave to master
# AXI4-Stream interface. Choose a random stimulus value for these 25 LSB here.
TUSER_LSB = randint(0, 2**25-1)

# FIFO storing inter-packet times monitored by the testbench
inter_packet_cycles_monitor = []


@cocotb.coroutine
def monitor_inter_packet_time(dut):
    """Monitor the inter-packet times on the AXI4-Stream slave interface."""
    global inter_packet_cycles_monitor

    axis_active = False
    first_packet = True
    cntr_inter_packet_cycles = 0

    while True:
        yield RisingEdge(dut.clk156)

        # increment inter-packet cycle counter
        cntr_inter_packet_cycles += 1

        if not int(dut.s_axis_tvalid) or not int(dut.s_axis_tready):
            # no transaction active
            continue

        if not axis_active:
            # this transfer starts a new packet

            if first_packet:
                # this is the first packet, we cannot calculate an inter-packet
                # time yet
                first_packet = False
            else:
                # save inter-packet cycle counter value in FIFO
                inter_packet_cycles_monitor.append(cntr_inter_packet_cycles)

            # reset inter-packet cycle counter
            cntr_inter_packet_cycles = 0

        # the next transfer starts a new packet if the TLAST signal is high
        axis_active = int(dut.s_axis_tlast) == 0


@cocotb.coroutine
def packets_write(dut, axis_writer, pkts):
    """Apply packets on DuT input."""
    # iterate over all packets
    for pkt in pkts:
        # convert packet to axi stream data
        (tdata, tkeep) = packet_to_axis_data(pkt, AXIS_BIT_WIDTH)

        # if TLAST is low, TUSER input must be zero. for the last AXI4-Stream
        # transfer of the packet, TUSER is set to a predetermined random value
        tuser = len(tdata) * [0]
        tuser[-1] = TUSER_LSB

        # write data on AXI4-Stream slave interface
        yield axis_writer.write(tdata, tkeep, tuser)

        # wait a random number of cycles before applying next packet
        yield wait_n_cycles(dut.clk156, randint(0, 100))


@cocotb.coroutine
def packets_read(dut, axis_reader, pkts_ref):
    """Evaluate correct packet data at DuT output."""
    # we must read as many packets as we appyed at the input
    for i, pkt_ref in enumerate(pkts_ref):
        # read AXI4-Stream data
        (tdata, tkeep, tuser) = yield axis_reader.read()

        # convert AXI4-Stream data to scapy packet
        pkt = axis_data_to_packet(tdata, tkeep, AXIS_BIT_WIDTH)

        # make sure read packet matches the one we expected
        if str(pkt) != str(pkt_ref):
            raise cocotb.result.TestFailure(("Packet #%d: read invalid " +
                                             "packet data") % i)

        # make sure that all TUSER values except the last one are set to zero
        if any(v != 0 for v in tuser[1:len(tuser)-1]):
            raise cocotb.result.TestFailure(("Packet #%d: invalid TUSER " +
                                             "value (!= 0)") % i)

        # the 25 LSB of the last TUSER value must match the value we applied on
        # the input
        if tuser[-1] & 0x1FFFFFF != TUSER_LSB:
            raise cocotb.result.TestFailure(("Packet #%d: invalid TUSER " +
                                             "value (!= input)") % i)

        # print progress
        print_progress(i, N_PACKETS)

        # inter-packet time is a relative number. start evaluation with second
        # packet
        if i == 0:
            continue

        # extract inter-packet time from TUSER
        inter_packet_cycles = tuser[len(tuser)-1] >> 25

        # get the expected inter-packet time from FIFO
        inter_packet_cycles_ref = inter_packet_cycles_monitor.pop(0)

        # make sure the extracted inter-packet time matches the one monitored
        # on the DuT output
        if inter_packet_cycles != inter_packet_cycles_ref:
            raise cocotb.result.TestFailure(("Packet #%d: invalid " +
                                             "inter-packet time " +
                                             "(Expected: %d, Is: %d)") %
                                            (i, inter_packet_cycles_ref,
                                             inter_packet_cycles))


@cocotb.test()
def nt_recv_interpackettime_test(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk156, CLK_FREQ_MHZ))

    # no software reset
    dut.rst_sw156 <= 0

    # reset the DuT
    yield rstn(dut.clk156, dut.rstn156)

    # create an AXI4-Stream reader, connect and reset it
    axis_reader = AXIS_Reader()
    axis_reader.connect(dut, dut.clk156, AXIS_BIT_WIDTH)
    yield axis_reader.rst()

    # create an AXI4-Stream writer, connect and reset it
    axis_writer = AXIS_Writer()
    axis_writer.connect(dut, dut.clk156, AXIS_BIT_WIDTH)
    yield axis_writer.rst()

    # generate some random packets
    pkts = []
    for _ in range(N_PACKETS):
        pkts.append(gen_packet())

    # start random toggling of AXI4-Stream reader TREADY
    cocotb.fork(toggle_signal(dut.clk156, dut.m_axis_tready))

    # start one coroutine to apply packets on DuT input
    cocotb.fork(packets_write(dut, axis_writer, pkts))

    # start one coroutine to read packets on DuT output
    coroutine_read = cocotb.fork(packets_read(dut, axis_reader, pkts))

    # start one coroutine that monitors inter-packet times
    cocotb.fork(monitor_inter_packet_time(dut))

    # wait for coroutines to complete
    yield coroutine_read.join()
