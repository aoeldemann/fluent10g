"""Test bench for the Verilog module 'nt_recv_capture_mem_write'."""
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
# Test bench for the Verilog module 'nt_recv_capture_mem_write'.

import cocotb
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, wait_n_cycles
from lib.mem import Mem
from lib.file import File

# clock frequency in MHz
CLK_FREQ_MHZ = 200

# mem write data path width
BIT_WIDTH_MEM_WRITE = 512

# input data path width
BIT_WIDTH_INPUT = 64

# maximum byte size of a memory read
RD_TRANSFER_SIZE_MAX = 16384

# ring buffer size in bytes
RING_BUFF_SIZES = [32768, 65536, 131072, 262144]

# offset in memory where ring buffer shall be located
RING_BUFF_ADDRS = [0, 2**32-10*(BIT_WIDTH_MEM_WRITE/8)]


@cocotb.coroutine
def apply_input(dut, f):
    """Apply DuT input stimulus."""
    # start the module
    dut.active_i <= 1

    # get file size
    f_size = f.size()

    # iterate over all 64 bit input data words
    for i in range(f_size*8/BIT_WIDTH_INPUT):
        # wait for fifo to become not full
        while True:
            yield RisingEdge(dut.clk)
            if int(dut.fifo_full_o) == 0:
                break

        # read 64 bit input data from file
        data = f.read_reverse_byte_order(i*BIT_WIDTH_INPUT/8,
                                         BIT_WIDTH_INPUT/8)

        # apply data to fifo
        dut.fifo_din_i <= data
        dut.fifo_wr_en_i <= 1
        yield RisingEdge(dut.clk)
        dut.fifo_wr_en_i <= 0

    # wait until there are less than 256 entries in the FIFO
    while True:
        yield RisingEdge(dut.clk)
        if int(dut.fifo_prog_empty):
            break

    # stop the module
    dut.active_i <= 0

    # wait for the module to become deactivated
    while True:
        yield RisingEdge(dut.clk)
        if int(dut.active_o) == 0:
            break

    if int(dut.fifo_rd_data_count) > 0:
        # flush the remaining data words from FIFO to ring buffer
        dut.flush_i <= 1
        yield RisingEdge(dut.clk)
        dut.flush_i <= 0
        yield RisingEdge(dut.clk)

        # wait for module to become deactivated again
        while True:
            yield RisingEdge(dut.clk)
            if int(dut.active_o) == 0:
                break

        # fifo must now be empty
        assert int(dut.fifo_rd_data_count) == 0


@cocotb.coroutine
def ring_buff_read(dut, ring_buff, f):
    """Read data from the ring buffer and check it for correctness.

    The coroutines monitors the ring buffer write pointer and reads data from
    the buffer if sufficient data is available. It ensures that the read data
    matches the data that has originally been written from the input file to
    the input FIFO.
    """
    # get ring buffer size
    ring_buff_size = ring_buff.size()

    # get file size
    f_size = f.size()

    # ring buffer must be larger than 16384 bytes
    if ring_buff_size <= 16384:
        raise cocotb.result.TestFailure("ring buffer size too small")

    # ring buffer size must be a multiple of 16384 bytes
    if ring_buff_size % 16384 != 0:
        raise cocotb.result.TestFailure("ring buffer size invalid")

    # transfer size must be smaller than ring buffer
    if RD_TRANSFER_SIZE_MAX >= ring_buff_size:
        raise cocotb.result.TestFailure("transfer size too large")

    # memory address at which ring buffer is located
    ring_buff_addr = (int(dut.mem_addr_hi_i) << 32) | int(dut.mem_addr_lo_i)

    # initialize number of bytes that still need to be read from memory
    size_outstanding = f_size

    # make sure module is active
    if int(dut.active_o) == 0:
        raise cocotb.result.TestFailure("DuT became inactive")

    while True:
        # number of outstanding bytes that still need to be read must never be
        # negative
        assert size_outstanding >= 0

        # abort if there is no more data to be read
        if size_outstanding == 0:
            break

        yield RisingEdge(dut.clk)

        # get read and write pointers
        rd = int(dut.addr_rd_i)
        wr = int(dut.addr_wr_o)

        # get memory size from current read pointer position until the end of
        # the ring buffer memory location
        ring_buff_size_end = ring_buff_size - rd

        # calculate the desired memory transfer size
        transfer_size = min(ring_buff_size_end,
                            min(size_outstanding, RD_TRANSFER_SIZE_MAX))

        # calculated memory transfer size must always be positive
        assert transfer_size > 0

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

        # read data from file
        data_file = f.read(f_size - size_outstanding, transfer_size)

        # make sure that data read from ring buffer matches the data we are
        # expecting
        if data_ring_buff != data_file:
            raise cocotb.result.TestFailure("ring buffer data does not " +
                                            "match expected data")

        # update read pointer
        if (rd + transfer_size) == ring_buff_size:
            # end of memory reached, wrap around
            dut.addr_rd_i <= 0
        else:
            assert (rd + transfer_size) < ring_buff_size
            dut.addr_rd_i <= rd + transfer_size

        # decrement number of bytes that still remain to be written to memory
        size_outstanding -= transfer_size

        # wait a little bit
        yield wait_n_cycles(dut.clk, 100)

    # make sure module is now inactive
    if int(dut.active_o) != 0:
        raise cocotb.result.TestFailure("DuT does not become inactive")


@cocotb.test()
def nt_recv_capture_mem_write_test(dut):
    """Test bench main function."""
    # open file with random content
    try:
        f = File("files/random.file")
    except IOError:
        raise cocotb.result.TestFailure("Generate input data by calling " +
                                        "'./create_random.py' in 'files' " +
                                        "folder!")

    # file size must be a multiple of AXI data width
    if f.size() % (BIT_WIDTH_MEM_WRITE/8) != 0:
        raise cocotb.result.TestFailure("invalid input data size")

    # create a ring buffer memory (initially of size 0) and connect it to the
    # DuT
    ring_buff = Mem(0)
    ring_buff.connect(dut)

    # start the clock
    cocotb.fork(clk_gen(dut.clk, CLK_FREQ_MHZ))

    # deassert sw reset
    dut.rst_sw <= 0

    # initially module is disabled
    dut.active_i <= 0

    # initially no FIFO flush
    dut.flush_i <= 0

    # reset DuT
    yield rstn(dut.clk, dut.rstn)

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
            dut.mem_addr_hi_i <= ring_buff_addr >> 32
            dut.mem_addr_lo_i <= ring_buff_addr & 0xFFFFFFFF

            # apply ring buffer address range to dut
            dut.mem_range_i <= ring_buff_size - 1

            # reset read address pointer
            dut.addr_rd_i <= 0

            # start a couroutine that applies input data
            cocotb.fork(apply_input(dut, f))

            # wait a few clock cycles
            yield wait_n_cycles(dut.clk, 10)

            # start the ring buffer read coroutine and wait until it completes
            yield ring_buff_read(dut, ring_buff, f)

            # clear the ring buffer contents
            ring_buff.clear()

    # close file
    f.close()
