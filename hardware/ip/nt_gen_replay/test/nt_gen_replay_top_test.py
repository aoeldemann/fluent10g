"""Test bench for the Verilog module 'nt_gen_replay_top'."""
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
# Test bench for the Verilog module 'nt_gen_replay_top'.

import cocotb
from cocotb.triggers import RisingEdge
from lib.axilite import AXI_Lite_Writer, AXI_Lite_Reader
from lib.axis import AXIS_Reader
from lib.mem import Mem
from lib.file import File
from lib.net import axis_data_to_packet
from lib.tb import clk_gen, rstn, wait_n_cycles, check_value, toggle_signal
from scapy.all import Ether
import binascii
from nt_gen_replay_cpuregs_defines import *

# clock frequency in MHz
CLK_FREQ_MHZ = 200

# AXI Stream data width
AXIS_BIT_WIDTH = 64

# AXI memory data width
AXI_MEM_BIT_WIDTH = 512

# AXI Lite data width
AXI_LITE_BIT_WIDTH = 32

# maximum byte size of a memory write
WR_TRANSFER_SIZE_MAX = 4096

# size of the ring buffer in memory to which trace data shall be transfered.
# its a factor that is multiplied by the byte size of the trace
# (factor < 1.0 -> ring buffer is smaller than the trace, factor > 1.0 -> ring
# buffer is larger than the trace)
RING_BUFF_SIZES = [1.0, 1.5, 0.1, 0.25, 0.75]

# offset in memory where ring buffer shall be located
RING_BUFF_ADDRS = [0, 2**32-10*(AXI_MEM_BIT_WIDTH/8)]


@cocotb.coroutine
def check_output(dut, trace, axis_reader):
    """Check whether the DUT output is the one that is expected.

    Based on a given trace replay file, the coroutine constructs the expected
    output behavior of the DUT and compares it to the actual values.
    """
    # get trace size
    trace_size = trace.size()

    # initialize address used to index memory-mapped trace file
    addr = 0

    while addr < trace_size:
        # read 8 byte from trace file. contains packet meta data
        meta = trace.read_reverse_byte_order(addr, 8)
        addr += 8

        if meta == 2**64-1:
            # the overall trace data has to be 512 bit aligned. If the actual
            # trace size is smaller, we can add padding at the end of the
            # trace (in multiples of 64 bit words). all bits of the padding
            # data have to be set to 1
            continue

        # extract meta data
        meta_delta_t = meta & 2**32-1
        meta_len_snap = (meta >> 32) & 2**11-1
        meta_len_wire = (meta >> 48) & 2**11-1

        # read packet data from trace file
        data = trace.read(addr, meta_len_snap)

        # increase address. packet data is aligned to 8 byte aligned
        if meta_len_snap % 8 == 0:
            addr += meta_len_snap
        else:
            addr += 8 * (meta_len_snap / 8 + 1)

        # if number of bytes on the wire is larger than the number of snap
        # bytes, add zero bytes as padding
        for _ in range(meta_len_wire - meta_len_snap):
            data <<= 8

        # create reference ethernet frame from the read data
        data = "%x" % data
        data = data.zfill(meta_len_wire)
        frame_ref = Ether(binascii.unhexlify(data))

        # read arriving frame from AXI4-Stream
        (tdata, tkeep, tuser) = yield axis_reader.read()

        # convert AXI4-Stream data to ethernet frame
        frame_recv = axis_data_to_packet(tdata, tkeep, AXIS_BIT_WIDTH)

        # make sure frames match
        if str(frame_ref) != str(frame_recv):
            raise cocotb.result.TestFailure("received wrong data")

        # inter-packet time is located in first tuser word
        meta_delta_t_recv = tuser[0] & 2**32-1

        # make sure the inter-packet time matches the expected one
        if meta_delta_t != meta_delta_t_recv:
            raise cocotb.result.TestFailure("wrong timing information")

        # all other tuser fields must be set to zero
        if any(v != 0 for v in tuser[2:]):
            raise cocotb.result.TestFailure("invalid tuser data")

    # wait some more cycles after last packet. there should not be any data on
    # the axi stream anymore
    for _ in range(1000):
        yield RisingEdge(dut.clk)
        check_value("m_axis_tvalid", dut.m_axis_tvalid, 0)


@cocotb.coroutine
def ring_buff_write(dut, ring_buff, trace, ring_buff_addr, axi_lite_reader,
                    axi_lite_writer):
    """Coroutine writes trace data to the ring buffer in memory.

    The coroutine monitors the ring buffer read pointer (set by the DUT) and
    writes data to the buffer when a sufficient amount of storage is available.
    """
    # get the ring buffer size
    ring_buff_size = ring_buff.size()

    # get trace size
    trace_size = trace.size()

    # transfer size must be smaller than ring buffer size
    if WR_TRANSFER_SIZE_MAX >= ring_buff_size:
        raise cocotb.result.TestFailure("transfer size too large")

    # initialize number of bytes that still need to be transfered to memory
    trace_size_outstanding = trace_size

    # initialize write pointer
    wr = 0x0

    while True:
        # number of outstanding bytes for transfer must never be negative
        assert trace_size_outstanding >= 0

        # abort if there is no more trace data to be transfered
        if trace_size_outstanding == 0:
            break

        # get the current read pointer
        rd = yield axi_lite_reader.read(CPUREG_OFFSET_CTRL_ADDR_RD)

        # get memory size from current write pointer position until the end
        # of the ring buffer memory location
        ring_buff_size_end = ring_buff_size - wr

        # calculate the desired transfer size
        transfer_size = \
            min(ring_buff_size_end,
                min(trace_size_outstanding, WR_TRANSFER_SIZE_MAX))

        # calculated memory transfer size must always be positive
        assert transfer_size > 0

        if rd == wr:
            # ring buffer is empty --> write data
            do_transfer = True
        elif rd < wr:
            # as long as ring buffer contains valid data, read and write
            # pointers must never become equal. If the read pointer is smaller
            # than the write pointer, we may fill up the memory until the end.
            # This means that the write pointer will may wrap around and have a
            # value of 0. Now if the read pointer is currently 0 as well, this
            # would result in an error situation in which the memory would be
            # assumed to be empty. Thus, special attention is necessary here.
            do_transfer = (rd != 0) or (wr + transfer_size) != ring_buff_size
        elif rd > wr:
            # to make sure that the read pointer does not have the same value
            # as the write pointer (which would mean that ring buffer is
            # empty), only transfer data if difference between both pointer is
            # larger than the transfer size
            do_transfer = (rd - wr) > transfer_size
        if not do_transfer:
            # no data transfer shall take place now, do nothing
            continue

        # read trace file data
        data = trace.read(trace_size - trace_size_outstanding, transfer_size)

        # write data to the ring buffer
        ring_buff.write(ring_buff_addr + wr, data, transfer_size)

        # update the write pointer
        if (wr + transfer_size) == ring_buff_size:
            # end of memory reached, wrap around
            wr = 0x0
        else:
            assert (wr + transfer_size) < ring_buff_size
            wr += transfer_size

        # write the write pointer to the DUT
        yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_ADDR_WR, wr)

        # decrement number of bytes that still remain to be written to memory
        trace_size_outstanding -= transfer_size

        # wait a little bit
        yield wait_n_cycles(dut.clk, 100)


@cocotb.test()
def nt_gen_replay_top_test(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk, CLK_FREQ_MHZ))

    # no software reset
    dut.rst_sw <= 0

    # reset dut
    yield rstn(dut.clk, dut.rstn)

    # open trace file
    trace = File("files/random.file")

    # get trace file size
    trace_size = trace.size()

    # trace file must be a multiple of the AXI data width
    if trace.size() % (AXI_MEM_BIT_WIDTH/8) != 0:
        raise cocotb.result.TestFailure("invalid trace size")

    # calculate ring buffer sizes
    ring_buff_sizes = []
    for ring_buff_size in RING_BUFF_SIZES:
        # size of ring buffer is determined by multiplying the size factor by
        # the size of the trace
        ring_buff_size = int(ring_buff_size * trace_size)

        # make sure that the ring buffer size is multiple of AXI data width
        if ring_buff_size % (AXI_MEM_BIT_WIDTH/8) != 0:
            ring_buff_size += AXI_MEM_BIT_WIDTH/8 - \
                    ring_buff_size % (AXI_MEM_BIT_WIDTH/8)
        ring_buff_sizes.append(ring_buff_size)

    # create a ring buffer memory (initially of size 0) and connect it to the
    # DUT
    ring_buff = Mem(0)
    ring_buff.connect(dut, "ddr3")

    # create axi lite writer, connect and reset
    axi_lite_writer = AXI_Lite_Writer()
    axi_lite_writer.connect(dut, dut.clk, AXI_LITE_BIT_WIDTH, "ctrl")
    yield axi_lite_writer.rst()

    # create axi lite reader, connect and reset
    axi_lite_reader = AXI_Lite_Reader()
    axi_lite_reader.connect(dut, dut.clk, AXI_LITE_BIT_WIDTH, "ctrl")
    yield axi_lite_reader.rst()

    # create axi stream reader, connect and reset
    axis_reader = AXIS_Reader()
    axis_reader.connect(dut, dut.clk, AXIS_BIT_WIDTH)
    yield axis_reader.rst()

    # start the ring buffer memory main routine
    cocotb.fork(ring_buff.main())

    # toggle m_axis_tready
    cocotb.fork(toggle_signal(dut.clk, dut.m_axis_tready))

    # iterate over all ring buffer sizes
    for i, ring_buff_size in enumerate(ring_buff_sizes):

        # set ring buffer size
        ring_buff.set_size(ring_buff_size)

        # iterate over all addresses where ring buffer shall be located in
        # memory
        for j, ring_buff_addr in enumerate(RING_BUFF_ADDRS):

            # print status
            print("Test %d/%d" % (i*len(RING_BUFF_ADDRS) + j + 1,
                  len(RING_BUFF_ADDRS) * len(RING_BUFF_SIZES)))

            print("Ring Buff Addr: 0x%x, Size: %d" %
                  (ring_buff_addr, ring_buff_size))

            # we have a total of 8 GByte of memory. Make sure the ring buffer
            # fits at the desired address
            if ring_buff_addr + ring_buff_size > 0x1FFFFFFFF:
                raise cocotb.result.TestFailure("ring buffer is too large")

            # to reduce the simulation memory footprint, provide the memory
            # module the first memory address that we acutally care about
            ring_buff.set_offset(ring_buff_addr)

            # configure ring buffer memory location
            yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_MEM_ADDR_HI,
                                        ring_buff_addr >> 32)
            yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_MEM_ADDR_LO,
                                        ring_buff_addr & 0xFFFFFFFF)

            # configure ring buffer address range
            yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_MEM_RANGE,
                                        ring_buff_size - 1)

            # configure trace size
            yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_TRACE_SIZE_HI,
                                        trace_size >> 32)
            yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_TRACE_SIZE_LO,
                                        trace_size & 0xFFFFFFFF)

            # reset write address pointer
            yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_ADDR_WR, 0x0)

            # make sure module initially is inactive
            status = yield axi_lite_reader.read(CPUREG_OFFSET_STATUS)
            if status & 0x3 != 0:
                raise cocotb.reset.TestFailure("module is active")

            # start the module
            yield axi_lite_writer.write(CPUREG_OFFSET_CTRL_START, 0x1)

            # wait a few cycles
            yield wait_n_cycles(dut.clk, 10)

            # start writing the ring buffer
            cocotb.fork(ring_buff_write(dut, ring_buff, trace, ring_buff_addr,
                                        axi_lite_reader, axi_lite_writer))

            # start coroutine that checks dut output
            coroutine_chk_out = cocotb.fork(check_output(dut, trace,
                                                         axis_reader))

            # wait a few cycles and make sure module is active
            yield wait_n_cycles(dut.clk, 10)
            status = yield axi_lite_reader.read(CPUREG_OFFSET_STATUS)
            if status & 0x1 == 0x0:
                raise cocotb.result.TestFailure("mem read not active")
            if status & 0x2 == 0x0:
                raise cocotb.result.TestFailure("packet assembly not active")

            # wait for output check to complete
            yield coroutine_chk_out.join()

            # wait a few cycles
            yield wait_n_cycles(dut.clk, 10)

            # make sure module is now inactive
            status = yield axi_lite_reader.read(CPUREG_OFFSET_STATUS)
            if status & 0x3 != 0x0:
                raise cocotb.result.TestFailure("module does not become " +
                                                "inactive")

            # clear the ring buffer contents
            ring_buff.clear()

    # close the trace file
    trace.close()
