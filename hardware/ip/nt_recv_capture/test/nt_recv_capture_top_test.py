"""Test bench for the Verilog module 'nt_recv_capture_top'."""
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
# Test bench for the Verilog module 'nt_recv_capture_top'.

import cocotb
from lib.tb import clk_gen, rstn, wait_n_cycles, swp_byte_order
from lib.mem import Mem
from lib.axilite import AXI_Lite_Reader, AXI_Lite_Writer
from lib.axis import AXIS_Writer
from lib.net import gen_packet, packet_to_axis_data, axis_data_to_packet
import random
from nt_recv_capture_cpuregs_defines import *

# clock frquency in MHz
CLK_FREQ_MHZ = 200

# AXI data width
AXI_BIT_WIDTH = 512

# AXI lite data width
AXI_CTRL_BIT_WIDTH = 32

# AXI stream data width
AXIS_BIT_WIDTH = 64

# maximum byte size of a memory read
RD_TRANSFER_SIZE_MAX = 16384

# ring buffer size in bytes
RING_BUFF_SIZES = [32768, 65536, 131072, 262144]

# offset in memory where ring buffer shall be located
RING_BUFF_ADDRS = [0, 2**32-10*(AXI_BIT_WIDTH/8)]

# different capture lengths that shall be tested
MAX_CAPTURE_LENS = [0, 1514, random.randint(1, 1513)]

# number of packets, latency timestamps and inter-packet times to generate
N_PACKETS = 1331


@cocotb.coroutine
def packets_write(dut, axis_writer, axilite_writer, axilite_reader, pkts,
                  latencies, inter_packet_times):
    """Apply packets on DuT input."""
    # start the module
    yield axilite_writer.write(CPUREG_OFFSET_CTRL_ACTIVE, 0x1)

    # wait a little bit
    yield wait_n_cycles(dut.clk, 10)

    # iterate over all packets
    for i, pkt in enumerate(pkts):
        # convert packet to AXI4-Stream data
        (tdata, tkeep) = packet_to_axis_data(pkt, AXIS_BIT_WIDTH)

        # include latency and inter-packet time in last TUSER word
        tuser = len(tdata) * [0]
        tuser[-1] = latencies[i] | (1 << 24) | (inter_packet_times[i] << 25)

        # write data
        yield axis_writer.write(tdata, tkeep, tuser)

        # wait random number of cycles before applying the next packet
        yield wait_n_cycles(dut.clk, random.randint(0, 10))

    # stop the module
    yield axilite_writer.write(CPUREG_OFFSET_CTRL_ACTIVE, 0x0)


def check_data(pkts_ref, latencies_ref, inter_packet_times_ref, data,
               max_len_capture):
    """Check the received data for correctness.

    The function ensures that the data read from the ring buffer (a list of
    512 bit data words) matches the expected meta data (timestamps, wire +
    capture length) and packet data.
    """
    # data word index
    i_data = 0

    # iterate over all packets
    for i_pkt, pkt_ref in enumerate(pkts_ref):
        # determinal actual capture length
        len_capture = min(len(pkt_ref), max_len_capture)

        # data is captured at the granularity of 8 byte words. how many 8 byte
        # words do we have?
        if len_capture % 8 == 0:
            len_capture_words = len_capture / 8
        else:
            len_capture_words = len_capture / 8 + 1

        # initialize empty packet data list
        packet_data = []

        # iterate over captured data words (8 byte each)
        for i in range(len_capture_words+1):
            # get data word and increment data word index
            d = data[i_data]
            i_data += 1

            # swap byte order
            d = swp_byte_order(d, AXIS_BIT_WIDTH/8)

            if i == 0:
                # this is meta data
                meta_latency = d & 0xFFFFFF
                meta_latency_valid = (d >> 24) & 0x1
                meta_interpackettime = (d >> 25) & 0xFFFFFFF
                meta_len_wire = (d >> 53) & 0x7FF

                # make sure the latency is marked valid
                if meta_latency_valid != 0x1:
                    raise cocotb.result.TestFailure(("Packet #%d: " +
                                                     "Latency value not " +
                                                     "valid") % i)

                # make sure latency matches reference value
                if latencies_ref[i_pkt] != meta_latency:
                    raise cocotb.result.TestFailure(("Packet #%d: " +
                                                     "incorrect latency") %
                                                    i_pkt)

                # make sure inter-packet time matches reference value
                if inter_packet_times_ref[i_pkt] != meta_interpackettime:
                    raise cocotb.result.TestFailure(("Packet #%d: " +
                                                     "incorrect inter-" +
                                                     "packet time") % i_pkt)
                # make sure wire length matches packet length
                if len(pkt_ref) != meta_len_wire:
                    raise cocotb.result.TestFailure(("Packet #%d: " +
                                                     "invalid wire " +
                                                     "length") % i_pkt)

            else:
                # this is packet data
                packet_data.append(d)

        # create packet from captured data
        if len_capture % 8 == 0:
            pkt = axis_data_to_packet(packet_data, 2**8-1, 64)
        else:
            pkt = axis_data_to_packet(packet_data,
                                      2**(len_capture % 8)-1, 64)

        # make sure packet data matches the exepcted packet data
        if str(pkt)[0:len_capture] != \
                str(pkt_ref)[0:len_capture]:
            raise cocotb.result.TestFailure(("Packet #%d: " +
                                             "invalid data") % i_pkt)


@cocotb.coroutine
def ring_buff_read(dut, axilite_writer, axilite_reader, ring_buff,
                   ring_buff_addr, max_len_capture, pkts_ref, latencies_ref,
                   inter_packet_times_ref):
    """Read data from the ring buffer and check it for correctness.

    The coroutines monitors the ring buffer write pointer and reads data from
    the buffer if sufficient data is available. It ensures that the read data
    matches the expected one.
    """
    # get ring buffer size
    ring_buff_size = ring_buff.size()

    # ring buffer must be larger than 16384 bytes
    if ring_buff_size <= 16384:
        raise cocotb.result.TestFailure("ring buffer size too small")

    # ring buffer size must be a multiple of 16384 bytes
    if ring_buff_size % 16384 != 0:
        raise cocotb.result.TestFailure("ring buffer size invalid")

    # transfer size must be smaller than ring buffer
    if RD_TRANSFER_SIZE_MAX >= ring_buff_size:
        raise cocotb.result.TestFailure("transfer size too large")

    # determine the number of bytes that we are expecting to read in total
    size_outstanding = 0

    # iterate over packets
    for pkt in pkts_ref:
        # for each packet we need to read 8 byte of meta information
        size_outstanding += 8

        # determine data capture length
        len_capture = min(len(pkt), max_len_capture)

        # data is captured at the granularity of 8 byte words
        if len_capture % 8 == 0:
            size_outstanding += len_capture
        else:
            size_outstanding += 8 * (len_capture/8 + 1)

    # total capture data is 64 byte aligned
    if size_outstanding % 64 != 0:
        size_outstanding = 64 * (size_outstanding/64 + 1)

    # read pointer has been reset and currently is zero
    rd = 0

    data = []

    while True:
        # number of outstanding bytes that still need to be read must never be
        # negative
        assert size_outstanding >= 0

        # abort if there is no more data to be read
        if size_outstanding == 0:
            break

        # read error register
        errs = yield axilite_reader.read(CPUREG_OFFSET_STATUS_ERRS)

        # make sure there was no error
        assert errs == 0x0

        # get the write pointer
        wr = yield axilite_reader.read(CPUREG_OFFSET_CTRL_ADDR_WR)

        # get memory size from current read pointer position until the end of
        # the ring buffer memory location
        ring_buff_size_end = ring_buff_size - rd

        # calculate the desired memory transfer size
        transfer_size = min(ring_buff_size_end,
                            min(size_outstanding, RD_TRANSFER_SIZE_MAX))

        # calculated memory transfer size must always be positive
        assert transfer_size > 0

        # ... and it must always be a multiple of 64 bytes
        assert transfer_size % 64 == 0

        if rd == wr:
            # ring buffer is empty -> nothing to transfer
            do_transfer = False
        elif rd < wr:
            # we can read if the difference between both pointers is at least
            # the desired transfer size
            do_transfer = (wr - rd) >= transfer_size
        elif wr < rd:
            # we can read until the end of the ring buffer
            do_transfer = True

        if not do_transfer:
            # no data transfer shall take place now, do nothing
            continue

        # read data from the ring buffer
        data_ring_buff = ring_buff.read(ring_buff_addr + rd, transfer_size)

        # write data to list in 8 byte words
        for i in range(transfer_size/8):
            d = data_ring_buff >> ((transfer_size/8 - i - 1)*64) & 2**64-1
            data.append(d)

        # update read pointer
        if (rd + transfer_size) == ring_buff_size:
            # end of memory reached, wrap around
            rd = 0
        else:
            assert (rd + transfer_size) < ring_buff_size
            rd = rd + transfer_size

        # write read pointer to DuT
        yield axilite_writer.write(CPUREG_OFFSET_CTRL_ADDR_RD, rd)

        # decrement number of bytes that still remain to be written to memory
        size_outstanding -= transfer_size

        # wait a little bit
        yield wait_n_cycles(dut.clk, 100)

    # check data for correctness
    check_data(pkts_ref, latencies_ref, inter_packet_times_ref, data,
               max_len_capture)


@cocotb.test()
def nt_recv_capture_top_test(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk, CLK_FREQ_MHZ))

    # no software reset
    dut.rst_sw <= 0

    # reset DuT
    yield rstn(dut.clk, dut.rstn)

    # create AXI4-Lite writer, connect and reset it
    axilite_writer = AXI_Lite_Writer()
    axilite_writer.connect(dut, dut.clk, AXI_CTRL_BIT_WIDTH, "ctrl")
    yield axilite_writer.rst()

    # create AXI4-Lite reader, connect and reset it
    axilite_reader = AXI_Lite_Reader()
    axilite_reader.connect(dut, dut.clk, AXI_CTRL_BIT_WIDTH, "ctrl")
    yield axilite_reader.rst()

    # create AXI4-Stream writer, connect and reset it
    axis_writer = AXIS_Writer()
    axis_writer.connect(dut, dut.clk, AXIS_BIT_WIDTH)
    yield axis_writer.rst()

    # create a ring buffer memory (initially of size 0) and connect it to the
    # DuT
    ring_buff = Mem(0)
    ring_buff.connect(dut, "ddr3")

    # generate a couple of random Ethernet packets. For each packet, generate
    # a 16 bit latency value and a 26 bit inter-packet time value
    pkts = []
    latencies = []
    inter_packet_times = []
    for _ in range(N_PACKETS):
        pkts.append(gen_packet())
        latencies.append(random.randint(0, 2**24-1))
        inter_packet_times.append(random.randint(0, 2**28-1))

    # start the ring buffer memory main routine
    cocotb.fork(ring_buff.main())

    # wait some more clock cycles
    yield wait_n_cycles(dut.clk, 5)

    # iterate over all ring buffer sizes
    for i, ring_buff_size in enumerate(RING_BUFF_SIZES):

        # set ring buffer size
        ring_buff.set_size(ring_buff_size)

        # iterate over all adderesses where ring buffer shall be located in
        # memory
        for j, ring_buff_addr in enumerate(RING_BUFF_ADDRS):

            # print status
            print("Test %d/%d (this will take a while)" %
                  (i*len(RING_BUFF_ADDRS) + j + 1,
                   len(RING_BUFF_ADDRS) * len(RING_BUFF_SIZES)))

            # we have a total of 8 GByte of memory. Make sure the ring buffer
            # fits at the desired address
            if ring_buff_addr + ring_buff_size > 0x1FFFFFFFF:
                raise cocotb.result.TestFailure("ring buffer is too large")

            # to reduce the simulation memory footprint, provide the memory
            # module the first memory address that we actually care about
            ring_buff.set_offset(ring_buff_addr)

            # write ring buffer memory location and address range
            yield axilite_writer.write(CPUREG_OFFSET_CTRL_MEM_ADDR_HI,
                                       ring_buff_addr >> 32)
            yield axilite_writer.write(CPUREG_OFFSET_CTRL_MEM_ADDR_LO,
                                       ring_buff_addr & 0xFFFFFFFF)
            yield axilite_writer.write(CPUREG_OFFSET_CTRL_MEM_RANGE,
                                       ring_buff_size - 1)

            # itererate over all capture lengths
            for max_len_capture in MAX_CAPTURE_LENS:
                # reset read address pointer
                yield axilite_writer.write(CPUREG_OFFSET_CTRL_ADDR_RD, 0x0)

                # set max capture length
                yield axilite_writer.write(CPUREG_OFFSET_CTRL_MAX_LEN_CAPTURE,
                                           max_len_capture)

                # start couroutine that applies packets at input
                cocotb.fork(packets_write(dut, axis_writer, axilite_writer,
                                          axilite_reader, pkts, latencies,
                                          inter_packet_times))

                # wait a bit
                yield wait_n_cycles(dut.clk, 50)

                # start the ring buffer read coroutine and wait until it
                # completes
                yield ring_buff_read(dut, axilite_writer, axilite_reader,
                                     ring_buff, ring_buff_addr,
                                     max_len_capture, pkts, latencies,
                                     inter_packet_times)

                # make sure no error occured
                errs = yield axilite_reader.read(CPUREG_OFFSET_STATUS_ERRS)
                assert errs == 0x0

                # make sure packet count is correct
                pkt_cnt = \
                    yield axilite_reader.read(CPUREG_OFFSET_STATUS_PKT_CNT)
                assert pkt_cnt == len(pkts)

                # make sure module is deactivated now
                active = yield axilite_reader.read(CPUREG_OFFSET_STATUS_ACTIVE)
                assert active == 0

                # clear the ring buffer contents
                ring_buff.clear()
