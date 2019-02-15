"""Test bench for the Verilog module 'nt_recv_capture_rx'."""
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
# Test bench for the Verilog module 'nt_recv_capture_rx'.

import cocotb
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, wait_n_cycles, check_value, print_progress
from lib.net import gen_packet, packet_to_axis_data, axis_data_to_packet
from lib.axis import AXIS_Writer
from random import randint

N_PACKETS = 100
CLK_FREQ_MHZ = 200
DATAPATH_BIT_WIDTH = 64
N_REPEATS = 20


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
            # the module should not write any data to the FIFOs at all
            yield RisingEdge(dut.clk)
            assert int(dut.fifo_meta_wr_en_o) == 0
            assert int(dut.fifo_data_wr_en_o) == 0
            assert int(dut.pkt_cnt_o) == 0

            if int(dut.s_axis_tvalid) and int(dut.s_axis_tready) and \
                    int(dut.s_axis_tlast):
                # one full packet has been applied at DuT input -> print
                # progress and increment packet counter
                print_progress(pkt_cnt, N_PACKETS)
                pkt_cnt += 1

        # make sure packet counter is still at zero
        check_value("pkt_cnt_o", dut.pkt_cnt_o, 0x0)
    else:
        # packet capture is enabled

        # get the configured maximum capture length
        max_len_capture = int(dut.max_len_capture_i)

        data = []

        # iterate over all reference packets
        for i, pkt_ref in enumerate(pkts_ref):

            # calculate the expected capture length
            meta_len_capture_ref = min(len(pkt_ref), max_len_capture)

            # each data FIFO word is 8 bytes wide, calculate number of data
            # words that shall be written for the captured data
            if meta_len_capture_ref % 8 == 0:
                n_words_ref = meta_len_capture_ref / 8
            else:
                n_words_ref = (meta_len_capture_ref / 8) + 1

            while True:
                yield RisingEdge(dut.clk)

                if int(dut.fifo_meta_wr_en_o):
                    # meta data is written to FIFO in this cycle

                    # get meta data
                    meta_data = int(dut.fifo_meta_din_o)

                    # make sure that the correct number of data words have been
                    # written to the FIFO
                    assert len(data) == n_words_ref

                    # extract meta data
                    meta_latency = meta_data & 0xFFFFFF
                    meta_latency_valid = (meta_data >> 24) & 0x1
                    meta_interpackettime = (meta_data >> 25) & 0xFFFFFFF
                    meta_len_wire = (meta_data >> 53) & 0x7FF
                    meta_len_capture = (meta_data >> 64) & 0x7FF

                    # make sure the latency is marked valid
                    if meta_latency_valid != 0x1:
                        raise cocotb.result.TestFailure(("Packet #%d: " +
                                                         "Latency value not " +
                                                         "valid") % i)

                    # make sure latency matches reference value
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

                    # make sure capture length matches expected value
                    if meta_len_capture != meta_len_capture_ref:
                        raise cocotb.result.TestFailure(("Packet #%d: " +
                                                         "invalid capture" +
                                                         "length") % i)

                    # create packet from captured data
                    if meta_len_capture % (DATAPATH_BIT_WIDTH/8) == 0:
                        pkt = axis_data_to_packet(data,
                                                  2**(DATAPATH_BIT_WIDTH/8)-1,
                                                  DATAPATH_BIT_WIDTH)
                    else:
                        pkt = axis_data_to_packet(data,
                                                  2**(meta_len_capture % 8)-1,
                                                  DATAPATH_BIT_WIDTH)

                    # make sure packet data matches the exepcted packet data
                    if str(pkt)[0:meta_len_capture] != \
                            str(pkt_ref)[0:meta_len_capture]:
                        raise cocotb.result.TestFailure(("Packet #%d: " +
                                                         "invalid data") % i)

                    # delete captured data
                    data = []

                if int(dut.fifo_data_wr_en_o):
                    # data is being written to the data FIFO
                    data.append(int(dut.fifo_data_din_o))

                if int(dut.fifo_meta_wr_en_o):
                    # meta data has been written and checked -> we are done for
                    # this packet.
                    print_progress(i, N_PACKETS)
                    break

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

    # start writing packets to DuT input
    coroutine_pkts_write = cocotb.fork(packets_write(dut, axis_writer, pkts,
                                                     latencies,
                                                     inter_packet_times))

    # start coroutine that checks module output
    coroutine_check_output = cocotb.fork(check_output(dut, pkts, latencies,
                                                      inter_packet_times))

    # wait for coroutines to complete
    yield coroutine_pkts_write.join()
    yield coroutine_check_output.join()

    # disable module
    dut.active_i <= 0

    # wait a few cycles
    yield wait_n_cycles(dut.clk, 3)

    # make sure module is now inactive
    check_value("active_o", dut.active_o, 0x0)


@cocotb.test()
def nt_recv_capture_rx_test(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk, CLK_FREQ_MHZ))

    # do not issue software reset
    dut.rst_sw <= 0

    # reset the dut
    yield rstn(dut.clk, dut.rstn)

    # instantiate an AXI4-Stream writer, connect and reset it
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

    # meta and data FIFOs never become full
    dut.fifo_meta_full_i <= 0
    dut.fifo_data_full_i <= 0

    # test 0: capture disabled
    print("Performing test 1/%d" % (N_REPEATS+3))
    yield perform_test(dut, axis_writer, pkts, latencies, inter_packet_times,
                       False, 0)

    # test 1: max capture size: 1514 byte
    print("Performing test 2/%d" % (N_REPEATS+3))
    yield perform_test(dut, axis_writer, pkts, latencies, inter_packet_times,
                       True, 1514)

    # test 2: max capture size: 0 byte
    print("Performing test 3/%d" % (N_REPEATS+3))
    yield perform_test(dut, axis_writer, pkts, latencies, inter_packet_times,
                       True, 0)

    # perform some more tests for random capture sizes
    for i in range(N_REPEATS):
        print("Performing test %d/%d" % (3+i, N_REPEATS+3))
        yield perform_test(dut, axis_writer, pkts, latencies,
                           inter_packet_times, True, randint(64, 1514))
