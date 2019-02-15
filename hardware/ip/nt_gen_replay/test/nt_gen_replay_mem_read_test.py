"""Test bench for the Verilog module 'nt_gen_replay_mem_read'."""
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
# Test bench for the Verilog module 'nt_gen_mem_read'.

import cocotb
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, check_value, wait_n_cycles, toggle_signal
from lib.mem import Mem
from lib.file import File

# clock frequency in MHz
CLK_FREQ_MHZ = 200

# AXI data width
AXI_BIT_WIDTH = 512

# maximum byte size of a memory write
WR_TRANSFER_SIZE_MAX = 4096

# size of the ring buffer in memory to which trace data shall be transfered.
# its a factor that is multiplied by the byte size of the trace
# (factor < 1.0 -> ring buffer is smaller than the trace, factor > 1.0 -> ring
# buffer is larger than the trace)
RING_BUFF_SIZES = [1.0, 1.5, 0.1, 0.25, 0.75]

# offset in memory where ring buffer shall be located
RING_BUFF_ADDRS = [0, 2**32-10*(AXI_BIT_WIDTH/8)]


@cocotb.coroutine
def check_output(dut, trace):
    """Check data written to the output FIFO for correctness.

    The coroutine monitors the data written to the FIFO and checks whether it
    matches the data of the input trace file.
    """
    # get trace size
    trace_size = trace.size()

    # check data written to fifo for correctness
    for i in range(trace_size*8/AXI_BIT_WIDTH):
        # wait for fifo wr enable
        while True:
            yield RisingEdge(dut.clk)

            # make sure module active status signal is high
            check_value("status_active_o", int(dut.status_active_o), 1)

            if int(dut.fifo_wr_en_o):
                # output fifo data is valid
                break

        # the order of the 8 byte words is reversed in the 64 byte output word
        output = (int(dut.fifo_din_o) & 2**64-1) << 448
        output |= ((int(dut.fifo_din_o) >> 64) & 2**64-1) << 384
        output |= ((int(dut.fifo_din_o) >> 128) & 2**64-1) << 320
        output |= ((int(dut.fifo_din_o) >> 192) & 2**64-1) << 256
        output |= ((int(dut.fifo_din_o) >> 256) & 2**64-1) << 192
        output |= ((int(dut.fifo_din_o) >> 320) & 2**64-1) << 128
        output |= ((int(dut.fifo_din_o) >> 384) & 2**64-1) << 64
        output |= (int(dut.fifo_din_o) >> 448) & 2**64-1

        # get exepcted output
        output_ref = trace.read_reverse_byte_order(i*AXI_BIT_WIDTH/8,
                                                   AXI_BIT_WIDTH/8)

        # make sure values match
        check_value("fifo_din_o", output_ref, output)

    # wait one clock cycle and make sure active signal is low then
    yield RisingEdge(dut.clk)
    check_value("status_active_o", int(dut.status_active_o), 0)


@cocotb.coroutine
def ring_buff_write(dut, ring_buff, trace):
    """Write trace data to the ring buffer.

    The coroutines monitors the ring buffer read pointer and writes data to the
    buffer if sufficient memory is availabe.
    """
    # get ring buffer size
    ring_buff_size = ring_buff.size()

    # get trace size
    trace_size = trace.size()

    # transfer size must be smaller than ring buffer
    if WR_TRANSFER_SIZE_MAX >= ring_buff_size:
        raise cocotb.result.TestFailure("transfer size too large")

    # memory address at which ring buffer is located
    ring_buff_addr = \
        (int(dut.ctrl_mem_addr_hi_i) << 32) | int(dut.ctrl_mem_addr_lo_i)

    # initialize number of bytes that still need to be transfered to memory
    trace_size_outstanding = trace_size

    while True:
        # number of outstanding bytes for transfer must never be negative
        assert trace_size_outstanding >= 0

        # abort if there is no more trace data to be transfered
        if trace_size_outstanding == 0:
            break

        yield RisingEdge(dut.clk)

        # get read and write pointers
        rd = int(dut.ctrl_addr_rd_o)
        wr = int(dut.ctrl_addr_wr_i)

        # get memory size from current write pointer position until the end of
        # the ring buffer memory location
        ring_buff_size_end = ring_buff_size - wr

        # calculate the desired memory transfer size
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

        # update write pointer
        if (wr + transfer_size) == ring_buff_size:
            # end of memory reached, wrap around
            dut.ctrl_addr_wr_i <= 0
        else:
            assert (wr + transfer_size) < ring_buff_size
            dut.ctrl_addr_wr_i <= wr + transfer_size

        # decrement number of bytes that still remain to be written to memory
        trace_size_outstanding -= transfer_size

        # wait a little bit
        yield wait_n_cycles(dut.clk, 100)


@cocotb.test()
def nt_gen_replay_mem_read_test(dut):
    """Test bench main function."""
    # open trace file
    trace = File("files/random.file")

    # get trace file size
    trace_size = trace.size()

    # trace file size must be a multiple of AXI data width
    if trace.size() % (AXI_BIT_WIDTH/8) != 0:
        raise cocotb.result.TestFailure("invalid trace size")

    # calculate ring buffer sizes
    ring_buff_sizes = []
    for ring_buff_size in RING_BUFF_SIZES:
        # size of ring buffer is determined by multiplying the size factor by
        # the size of the trace
        ring_buff_size = int(ring_buff_size * trace_size)

        # make sure that the ring buffer size is multiple of AXI data width
        if ring_buff_size % (AXI_BIT_WIDTH/8) != 0:
            ring_buff_size += AXI_BIT_WIDTH/8 - ring_buff_size % \
                             (AXI_BIT_WIDTH/8)
        ring_buff_sizes.append(ring_buff_size)

    # create a ring buffer memory (initially of size 0) and connect it to the
    # DUT
    ring_buff = Mem(0)
    ring_buff.connect(dut)

    # start the clock
    cocotb.fork(clk_gen(dut.clk, CLK_FREQ_MHZ))

    # deassert sw reset
    dut.rst_sw <= 0

    # initially module start is not triggered
    dut.ctrl_start_i <= 0

    # reset dut
    yield rstn(dut.clk, dut.rstn)

    # start the ring buffer memory main routine
    cocotb.fork(ring_buff.main())

    # wait some more clock cycles
    yield wait_n_cycles(dut.clk, 5)

    # randomly toggle fifo_prog_full input signal
    dut.fifo_prog_full_i <= 0
    cocotb.fork(toggle_signal(dut.clk, dut.fifo_prog_full_i))

    # iterate over all ring buffer sizes
    for i, ring_buff_size in enumerate(ring_buff_sizes):

        # set ring buffer size
        ring_buff.set_size(ring_buff_size)

        # iterate over all adderesses where ring buffer shall be located in
        # memory
        for j, ring_buff_addr in enumerate(RING_BUFF_ADDRS):

            # print status
            print("Test %d/%d" % (i*len(RING_BUFF_ADDRS) + j + 1,
                  len(RING_BUFF_ADDRS) * len(RING_BUFF_SIZES)))

            # we have a total of 8 GByte of memory. Make sure the ring buffer
            # fits at the desired address
            if ring_buff_addr + ring_buff_size > 0x1FFFFFFFF:
                raise cocotb.result.TestFailure("ring buffer is too large")

            # to reduce the simulation memory footprint, provide the memory
            # module the first memory address that we actually care about
            ring_buff.set_offset(ring_buff_addr)

            # apply ring buffer memory location to dut
            dut.ctrl_mem_addr_hi_i <= ring_buff_addr >> 32
            dut.ctrl_mem_addr_lo_i <= ring_buff_addr & 0xFFFFFFFF

            # apply ring buffer address range to dut
            dut.ctrl_mem_range_i <= ring_buff_size - 1

            # apply trace size to dut
            dut.ctrl_trace_size_hi_i <= trace_size >> 32
            dut.ctrl_trace_size_lo_i <= trace_size & 0xFFFFFFFF

            # reset write address pointer
            dut.ctrl_addr_wr_i <= 0

            # start reading from the ring buffer
            dut.ctrl_start_i <= 1
            yield RisingEdge(dut.clk)
            dut.ctrl_start_i <= 0
            yield RisingEdge(dut.clk)

            # start writing the ring buffer
            cocotb.fork(ring_buff_write(dut, ring_buff, trace))

            # start checking dut output and wait until it completes
            yield cocotb.fork(check_output(dut, trace)).join()

            # clear the ring buffer contents
            ring_buff.clear()

    # close trace file
    trace.close()
