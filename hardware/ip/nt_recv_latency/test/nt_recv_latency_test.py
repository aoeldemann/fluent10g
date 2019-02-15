"""Test bench for the Verilog module 'nt_recv_latency'."""
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
# Test bench for verilog module 'nt_recv_latency'.

import cocotb
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, wait_n_cycles, toggle_signal, print_progress
from lib.net import gen_packet, packet_to_axis_data, axis_data_to_packet
from lib.axis import AXIS_Reader, AXIS_Writer
from random import randint, shuffle
from scapy.all import Ether, IP, IPv6
from struct import pack

AXIS_BIT_WIDTH = 64
N_PACKETS = 200
N_REPEATS = 50
CLK_FREQ_MHZ = 156.25


MODE_DISABLED = 0x0
MODE_FIXED_POS = 0x1
MODE_HEADER = 0x2


def packet_insert_random_timestamp_header(pkt, timestamps):
    """Insert a random timestamp in the packet header.

    For IPv4 packets a 16 bit random timestamp is inserted in the checksum
    field of the header. For IPv6 packets a random 16 bit timestamp is inserted
    in the flowlabel field of the header. The generated timestamp is appended
    to a list which is given as a function argument.
    """
    # get random timestamp
    timestamp = randint(0, 2**16-1)

    # get l3 layer of packet
    if pkt.type == 0x800:
        l3_proto = IP
    elif pkt.type == 0x86dd:
        l3_proto = IPv6
    else:
        assert False

    # insert timestamp in header field based on ip version
    if l3_proto == IP:
        pkt[IP].chksum = timestamp
    elif l3_proto == IPv6:
        pkt[IPv6].fl = timestamp

    # hardware receives data in network byte order -> reverse byte order before
    # storing timestamp
    timestamp = ((timestamp << 8) | (timestamp >> 8)) & 0xFFFF

    # append timestamp to list given as function argument
    timestamps.append(timestamp)


def packet_insert_random_timestamp_fixed(pkt, timestamps, pos, width):
    """Insert a random timestamp at a fixed byte position.

    If 'width' is zero, a 16 bit timestamp is inserted at the byte position
    determined by the 'pos' parameter. If 'width' is one, a 24 bit timestamp
    is inserted. If the packet is too short to hold the timestamp value, no
    timestamp is inserted at all.

    In constrast to the 'packet_insert_random_timestamp_header' function, this
    function does not modify the packet passed via the 'pkt' argument, but
    rather returns a new packet in which the timestamp has been inserted. If
    no timestamp has been inserted, it returns the unmodified packet that has
    been passed via the 'pkt' argument.
    """
    # is packet long enoguh to contain a timestamp?
    if width == 0:
        # timestamp is 16 bit wide
        if len(pkt) < pos+2:
            # not long enough
            timestamps.append(None)
            return pkt
    else:
        # timestamp is 24 bit wide
        if len(pkt) < pos+3:
            # not long enough
            timestamps.append(None)
            return pkt

    # generate random timestamp and insert into packet
    if width == 0:
        # 16 bit timestamp
        timestamp = randint(0, 2**16-1)

        # convert packet to string and insert timestamp
        pkt_str = str(pkt)
        pkt_str = pkt_str[0:pos] + pack("H", timestamp) + pkt_str[pos+2:]
    else:
        # 24 bit timestamp
        timestamp = randint(0, 2**24-1)

        # convert packet to string and insert timestamp
        pkt_str = str(pkt)
        pkt_str = pkt_str[0:pos] + pack("I", timestamp)[0:3] + pkt_str[pos+3:]

    # create new packet and make sure that length matches the one of the
    # old one
    pkt_new = Ether(pkt_str)
    assert len(pkt) == len(pkt_new)

    # append generate timestamp to list
    timestamps.append(timestamp)

    # return new packet
    return pkt_new


@cocotb.coroutine
def packets_write(dut, axis_writer, pkts):
    """Apply generated packet data on DuT input."""
    # iterate over all packets that should be sent
    for pkt in pkts:
        # convert packet to AXI4-Stream data
        (tdata, tkeep) = packet_to_axis_data(pkt, AXIS_BIT_WIDTH)

        # apply data
        yield axis_writer.write(tdata, tkeep)

        # wait a random number of cycles before sending next packet
        yield wait_n_cycles(dut.clk156, randint(0, 10))


@cocotb.coroutine
def packets_read(dut, axis_reader, pkts_ref, timestamps_ref):
    """Evaluate data at DuT output and validate correct behavior."""
    # read as many packets as we originally generated
    for i, pkt_ref in enumerate(pkts_ref):
        # read AXI4-Stream data
        (tdata, tkeep, tuser) = yield axis_reader.read()

        # print progress
        print_progress(i, N_PACKETS)

        # convert AXI4-Stream data to scapy packet
        pkt = axis_data_to_packet(tdata, tkeep, AXIS_BIT_WIDTH)

        # make sure received packet matches expected packet
        if str(pkt) != str(pkt_ref):
            raise cocotb.result.TestFailure(("Packet #%d: received invalid " +
                                             "packet data") % i)

        # make sure that all tuser values except the last one are set to zero
        if any(v != 0 for v in tuser[1:-1]):
            raise cocotb.result.TestFailure("Packet #%d: invalid TUSER value" %
                                            i)

        if int(dut.mode_i) == MODE_HEADER:
            # latency timestamp is saved in IP packet header. latency values
            # must be extracted for all IP packets
            if pkt_ref.type == 0x800 or pkt_ref.type == 0x86dd:
                # latency value provided at output?
                latency_valid = tuser[-1] >> 24
                if latency_valid == 0:
                    raise cocotb.result.TestFailure(("Packet #%d: no " +
                                                     "latency value in " +
                                                     "output") % i)

                # get latency value
                latency = tuser[-1] & 0xFFFFFF

                # calculate reference latency
                timestamp_cur = int(dut.timestamp_i) & 0xFFFF
                if timestamp_cur > timestamps_ref[i]:
                    latency_ref = timestamp_cur - timestamps_ref[i]
                else:
                    latency_ref = 0xFFFF - timestamps_ref[i] + \
                        timestamp_cur + 1

                # make sure latency values match
                if latency != latency_ref:
                    raise cocotb.result.TestFailure(("Packet #%d: wrong " +
                                                     "latency value") % i)

            else:
                # non latency value must be provided on output for non-IP
                # packets
                if tuser[-1] != 0:
                    raise cocotb.result.TestFailure(("Packet #%d: latency " +
                                                     "value on output") % i)
        elif int(dut.mode_i) == MODE_FIXED_POS:
            # latency timestamp is located at a fixed byte position in the
            # packet

            # is packet long enough to contain a timestamp?
            if int(dut.width_i) == 0:
                # timestamp is 16 bit wide
                if len(pkt_ref) < int(dut.pos_i)+2:
                    # not long enough, make sure that no latency value is
                    # provided
                    if tuser[-1] != 0:
                        raise cocotb.result.TestFailure(("Packet #%d: " +
                                                         "latency value on " +
                                                         "output") % i)

                    # ensure that we did not generate a timestamp for this
                    # packet
                    assert timestamps_ref[i] is None

                    # nothing more to do for this packet
                    continue
            else:
                # timestamp is 24 bit wide
                if len(pkt_ref) < int(dut.pos_i)+3:
                    # not long enough, make sure that no latency value is
                    # provided
                    if tuser[-1] != 0:
                        raise cocotb.result.TestFailure(("Packet #%d: " +
                                                         "latency value on " +
                                                         "output") % i)
                    # ensure that we did not generate a timestamp for this
                    # packet
                    assert timestamps_ref[i] is None

                    # nothing more to do for this packet
                    continue

            # make sure latency value is provided at output
            latency_valid = tuser[-1] >> 24
            if latency_valid == 0:
                raise cocotb.result.TestFailure(("Packet #%d: no " +
                                                 "latency value in " +
                                                 "output") % i)

            # get latency value
            latency = tuser[-1] & 0xFFFFFF

            # calculate reference latency
            if int(dut.width_i) == 0:
                # 16 bit timestamp
                timestamp_cur = int(dut.timestamp_i) & 0xFFFF
                if timestamp_cur > timestamps_ref[i]:
                    latency_ref = timestamp_cur - timestamps_ref[i]
                else:
                    latency_ref = 0xFFFF - timestamps_ref[i] + \
                        timestamp_cur + 1
            else:
                # 24 bit timestamp
                timestamp_cur = int(dut.timestamp_i)
                if timestamp_cur > timestamps_ref[i]:
                    latency_ref = timestamp_cur - timestamps_ref[i]
                else:
                    latency_ref = 0xFFFFFF - timestamps_ref[i] + \
                        timestamp_cur + 1

            # make sure latency values match
            if latency != latency_ref:
                raise cocotb.result.TestFailure(("Packet #%d: wrong " +
                                                 "latency value") % i)

        elif int(dut.mode_i) == MODE_DISABLED:
            # timestamping is disabled

            # all bits of the last tuser value must be set to zero
            if tuser[-1] != 0:
                raise cocotb.result.TestFailure(("Packet #%d: latency value "
                                                 "in output") % i)
        else:
            # this should never happen
            assert False


@cocotb.coroutine
def perform_test(dut, axis_writer, axis_reader, pkts, timestamps):
    """Perform a test run."""
    # start one coroutine to apply packets on dut input
    cocotb.fork(packets_write(dut, axis_writer, pkts))

    # start one coroutine to evaluate packets on dut output
    thread_recv = cocotb.fork(packets_read(dut, axis_reader, pkts, timestamps))

    # wait for coroutines to complete
    yield thread_recv.join()


@cocotb.test()
def nt_recv_latency_test(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk156, CLK_FREQ_MHZ))

    # no software reset
    dut.rst_sw156 <= 0

    # reset the dut
    yield rstn(dut.clk156, dut.rstn156)

    # create an AXI4-Stream reader, connect and reset it
    axis_reader = AXIS_Reader()
    axis_reader.connect(dut, dut.clk156, AXIS_BIT_WIDTH)
    yield axis_reader.rst()

    # create an AXI4-Stream writer, connect and reset it
    axis_writer = AXIS_Writer()
    axis_writer.connect(dut, dut.clk156, AXIS_BIT_WIDTH)
    yield axis_writer.rst()

    # start random toggling of AXI4-Stream reader TREADY
    cocotb.fork(toggle_signal(dut.clk156, dut.m_axis_tready))

    # set current timestamp to be static at 8421376
    dut.timestamp_i <= 8421376
    yield RisingEdge(dut.clk156)

    # generate 70% of N_PACKETS IP packets and insert random timestamp in
    # packet header
    n_packets_ip = int(0.7*N_PACKETS)
    pkts = []
    timestamps = []
    for _ in range(n_packets_ip):
        pkt = gen_packet()
        packet_insert_random_timestamp_header(pkt, timestamps)
        pkts.append(pkt)

    # then generate 30% of N_PACKETS non-IP packets. no timestamp will be
    # inserted
    for _ in range(N_PACKETS-n_packets_ip):
        pkt = gen_packet(eth_only=True)
        pkts.append(pkt)
        timestamps.append(None)

    # shuffle pkt and timestamp lists (in same order)
    tmp = list(zip(pkts, timestamps))
    shuffle(tmp)
    pkts, timestamps = zip(*tmp)

    # we inserted timestamps in packet header
    dut.mode_i <= MODE_HEADER

    print("Test Timestamp Header")
    yield perform_test(dut, axis_writer, axis_reader, pkts, timestamps)

    # perform another test where timestamping is disabled
    dut.mode_i <= MODE_DISABLED

    print("Test Timestamp Disabled")
    yield perform_test(dut, axis_writer, axis_reader, pkts, timestamps)

    # next run some random tests with timestamp inserted at fixed byte position
    for i in range(N_REPEATS):
        # fixed byte position
        dut.mode_i <= MODE_FIXED_POS

        # randomly choose 16 bit or 24 bit timestamp width
        width = randint(0, 1)

        # find valid timestamp positions
        while True:
            pos = randint(0, 1518)
            if width == 0 and (pos % 8) < 7:
                break
            elif width == 1 and (pos % 8) < 6:
                break

        # set timestamp position and width
        dut.pos_i <= pos
        dut.width_i <= width

        # generate some ip packets and insert random timestamps
        pkts = []
        timestamps = []
        for _ in range(N_PACKETS):
            pkt = gen_packet()
            pkt = packet_insert_random_timestamp_fixed(pkt, timestamps, pos,
                                                       width)
            pkts.append(pkt)

        # perform the test
        print("Test Timestamp Fixed Pos %d/%d (Pos: %d, Width: %d)" %
              (i+1, N_REPEATS, pos, width))
        yield perform_test(dut, axis_writer, axis_reader, pkts, timestamps)
