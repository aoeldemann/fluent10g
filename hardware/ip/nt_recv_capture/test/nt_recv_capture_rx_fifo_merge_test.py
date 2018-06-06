"""Test bench for multiple Verilog modules.

Test bench for the combined 'nt_recv_capture_rx' and
'nt_recv_capture_merge_fifo' Verilog modules.
"""
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
# Test bench for the combined 'nt_recv_capture_rx' and
# 'nt_recv_capture_merge_fifo' Verilog modules.

import cocotb
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, wait_n_cycles, check_value, print_progress
from lib.net import gen_packet, packet_to_axis_data, axis_data_to_packet
from lib.axis import AXIS_Writer
from random import randint

N_PACKETS = 300
CLK_FREQ_MHZ = 200
DATAPATH_BIT_WIDTH = 64
N_REPEATS = 10


@cocotb.coroutine
def packets_write(dut, axis_writer, pkts, latencies, inter_packet_times):
    """Apply packets on DuT input."""
    # iterate over all packets
    for i, pkt in enumerate(pkts):
        # convert packet to AXI4-Stream data
        (tdata, tkeep) = packet_to_axis_data(pkt, DATAPATH_BIT_WIDTH)

        # include latency and inter-packet time in last TUSER word
        tuser = len(tdata) * [0]
        tuser[-1] = latencies[i] | (1 << 24) | (inter_packet_times[i] << 25)

        # write data
        yield axis_writer.write(tdata, tkeep, tuser)

        # wait random number of cycles before writing the next packet
        yield wait_n_cycles(dut.clk, randint(0, 10))


@cocotb.coroutine
def check_output(dut, pkts_ref, latencies_ref, inter_packet_times_ref):
    """Check DuT output for correctness."""
    # check whether capturing is enabled
    enabled = int(dut.active_i) == 1

    if not enabled:
        # packet data capturing is disabled. make sure that the module does not
        # output any data
        pkt_cnt = 0
        while pkt_cnt < len(pkts_ref):
            # the module should not write any data to the output FIFO at all
            yield RisingEdge(dut.clk)
            assert int(dut.fifo_wr_en_o) == 0
            assert int(dut.pkt_cnt_o) == 0

            if int(dut.s_axis_tvalid) and int(dut.s_axis_tready) and \
                    int(dut.s_axis_tlast):
                # one full packet has been applied at DuT input -> print
                # progress and increment packet counter
                print_progress(pkt_cnt, N_PACKETS)
                pkt_cnt += 1

            if pkt_cnt == len(pkts_ref):
                # all packets have been applied -> done!
                break

        # make sure packet counter is still at zero
        check_value("pkt_cnt_o", dut.pkt_cnt_o, 0x0)

    else:
        # packet capture is enabled

        # get the configured maximum capture length
        max_len_capture = int(dut.max_len_capture_i)

        # iterate over all reference packets
        for i, pkt_ref in enumerate(pkts_ref):

            # get the packet's capture length
            len_capture = min(len(pkt_ref), max_len_capture)

            # wait for fifo write output signal to become high
            while True:
                yield RisingEdge(dut.clk)
                if int(dut.fifo_wr_en_o):
                    break

            # get meta data
            meta_data = int(dut.fifo_din_o)

            # extract meta data
            meta_latency = meta_data & 0xFFFFFF
            meta_latency_valid = (meta_data >> 24) & 0x1
            meta_interpackettime = (meta_data >> 25) & 0xFFFFFFF
            meta_len_wire = (meta_data >> 53) & 0x7FF

            # make sure the latency is marked valid
            if meta_latency_valid != 0x1:
                raise cocotb.result.TestFailure(("Packet #%d: " +
                                                 "Latency value not " +
                                                 "valid") % i)

            if latencies_ref[i] != meta_latency:
                raise cocotb.result.TestFailure(("Packet #%d: " +
                                                 "incorrect latency") %
                                                i)

            # make sure inter-packet time matches reference value
            if inter_packet_times_ref[i] != meta_interpackettime:
                raise cocotb.result.TestFailure(("Packet #%d: " +
                                                 "incorrect inter-" +
                                                 "packet time") % i)
            # make sure wire length matches packet length
            if len(pkt_ref) != meta_len_wire:
                raise cocotb.result.TestFailure(("Packet #%d: " +
                                                 "invalid wire " +
                                                 "length") % i)

            # calculate number of 8 byte packet data words
            if len_capture % 8 == 0:
                len_capture_words = len_capture / 8
            else:
                len_capture_words = len_capture / 8 + 1

            # read as many data words as specified by capture length
            data = []
            for _ in range(len_capture_words):
                # wait for FIFO write output signal to become high
                while True:
                    yield RisingEdge(dut.clk)
                    if int(dut.fifo_wr_en_o):
                        break

                # read data word
                data.append(int(dut.fifo_din_o))

            # create packet from captured data
            if len_capture % (DATAPATH_BIT_WIDTH/8) == 0:
                pkt = axis_data_to_packet(data,
                                          2**(DATAPATH_BIT_WIDTH/8)-1,
                                          DATAPATH_BIT_WIDTH)
            else:
                pkt = axis_data_to_packet(data,
                                          2**(len_capture % 8)-1,
                                          DATAPATH_BIT_WIDTH)

            # make sure packet data matches the exepcted packet data
            if str(pkt)[0:len_capture] != \
                    str(pkt_ref)[0:len_capture]:
                raise cocotb.result.TestFailure(("Packet #%d:" +
                                                 "invalid data") % i)

            # print progress
            print_progress(i, N_PACKETS)

        # make sure packet counter value is correct
        check_value("pkt_cnt_o", dut.pkt_cnt_o, len(pkts_ref))

    # make sure no errors are flagged by the DuT
    check_value("err_data_fifo_full_o", dut.err_data_fifo_full_o, 0x0)
    check_value("err_meta_fifo_full_o", dut.err_meta_fifo_full_o, 0x0)


@cocotb.coroutine
def perform_test(dut, axis_writer, pkts, latencies, inter_packet_times, active,
                 max_len_capture):
    """Perform a test run for specific capture parameters."""
    # enable/disable capture
    dut.active_i <= active

    # set per-packet capture length
    dut.max_len_capture_i <= max_len_capture

    # wait a few cycles
    yield wait_n_cycles(dut.clk, 5)

    # if capture is enabled, module shall be active now. otherwise it should
    # remain deactivated
    check_value("active_o", dut.active_o, active)

    # start applying packets
    coroutine_pkts_write = cocotb.fork(packets_write(dut, axis_writer, pkts,
                                                     latencies,
                                                     inter_packet_times))

    # start coroutine that checks module output
    coroutine_check_output = cocotb.fork(check_output(dut, pkts, latencies,
                                                      inter_packet_times))

    # wait for coroutines to complete
    yield coroutine_pkts_write.join()
    yield coroutine_check_output.join()

    # disable capture
    dut.active_i <= 0

    # wait a few cycles
    yield wait_n_cycles(dut.clk, 3)

    # make sure module is now inactive
    check_value("active_o", dut.active_o, 0x0)


@cocotb.test()
def nt_recv_capture_rx_fifo_merge_test(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk, CLK_FREQ_MHZ))

    # do not issue software reset
    dut.rst_sw <= 0

    # reset the dut
    yield rstn(dut.clk, dut.rstn)

    # instantiate an AXI4-Stream writer, connect and reset
    axis_writer = AXIS_Writer()
    axis_writer.connect(dut, dut.clk, DATAPATH_BIT_WIDTH)
    yield axis_writer.rst()

    # generate a couple of random Ethernet packets. For each packet, generate
    # a 16 bit latency value and a 26 bit inter-packet time value
    pkts = []
    latencies = []
    inter_packet_times = []
    for _ in range(N_PACKETS):
        pkts.append(gen_packet())
        latencies.append(randint(0, 2**24-1))
        inter_packet_times.append(randint(0, 2**28-1))

    # initially output FIFO is not full
    dut.fifo_full_i <= 0

    # test: capture disabled
    print("Performing test 1/%d" % (N_REPEATS+5))
    yield perform_test(dut, axis_writer, pkts, latencies, inter_packet_times,
                       False, 0)

    # test: max capture size: 1514 byte
    print("Performing test 2/%d" % (N_REPEATS+5))
    yield perform_test(dut, axis_writer, pkts, latencies, inter_packet_times,
                       True, 1514)

    # test: max capture size: 0 byte
    print("Performing test 3/%d" % (N_REPEATS+5))
    yield perform_test(dut, axis_writer, pkts, latencies, inter_packet_times,
                       True, 0)

    # perform some more tests for random capture sizes
    for i in range(N_REPEATS):
        print("Performing test %d/%d" % (3+i, N_REPEATS+5))
        yield perform_test(dut, axis_writer, pkts, latencies,
                           inter_packet_times, True, randint(64, 1514))

    # now mark the fifo as full
    dut.fifo_full_i <= 1

    # perform another test and check data fifo error output signal
    # should become full
    print("Performing test %d/%d (no status output)" %
          (N_REPEATS+4, N_REPEATS+5))
    cocotb.fork(perform_test(dut, axis_writer, pkts, latencies,
                             inter_packet_times, True, 1514))

    # wait until all packets have been applied on AXI stream interface
    pkt_cnt = 0
    while pkt_cnt < len(pkts):
        yield RisingEdge(dut.clk)
        if int(dut.s_axis_tvalid) and int(dut.s_axis_tready) and \
                int(dut.s_axis_tlast):
            pkt_cnt += 1

    # make sure the data fifo full error signal is asserted
    assert int(dut.err_data_fifo_full_o)

    # perform reset
    dut.rst_sw <= 1
    yield RisingEdge(dut.clk)
    dut.rst_sw <= 0
    yield RisingEdge(dut.clk)

    # perform one final test to check whether the meta data fifo error signal
    # is asserted when the fifo becomes full
    print("Performing test %d/%d (no status output)" %
          (N_REPEATS+5, N_REPEATS+5))
    cocotb.fork(perform_test(dut, axis_writer, pkts, latencies,
                             inter_packet_times, True, 0))

    # wait until all packets have been applied on AXI stream interface
    pkt_cnt = 0
    while pkt_cnt < len(pkts):
        yield RisingEdge(dut.clk)
        if int(dut.s_axis_tvalid) and int(dut.s_axis_tready) and \
                int(dut.s_axis_tlast):
            pkt_cnt += 1

    # make sure the meta fifo full error signal is asserted
    assert int(dut.err_meta_fifo_full_o)
