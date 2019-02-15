"""Test bench for the Verilog module 'nt_gen_timestamp_insert'."""
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
# Test bench for the Verilog module 'nt_gen_timestamp_insert'.

import cocotb
from cocotb.triggers import RisingEdge
from lib.tb import clk_gen, rstn, wait_n_cycles, toggle_signal, print_progress
from lib.net import gen_packet, packet_to_axis_data, axis_data_to_packet
from lib.axis import AXIS_Reader, AXIS_Writer
from random import randint
from scapy.all import IP, IPv6
from struct import unpack

AXIS_BIT_WIDTH = 64
N_PACKETS = 150
N_REPEATS = 30
TIMESTAMP_COUNTER_CYCLES = 3
CLK_FREQ_MHZ = 156.25

MODE_DISABLED = 0x0
MODE_FIXED_POS = 0x1
MODE_HEADER = 0x2


def validate_packet_timestamp_header(pkt_ref, pkt_recv, timestamp_ref):
    """Validate packet content and timestamp in packet header.

    Valiadates that packet data at DUT output matches the one that was applied
    at DUT input. Also makes sure that the timestamp stored within the packet
    header is correct. Returns True if validation was successful.
    """
    # get l3 layer proto of reference packet
    if pkt_ref.type == 0x800:
        l3_proto = IP
    elif pkt_ref.type == 0x86dd:
        l3_proto = IPv6
    else:
        assert False

    # make sure received packets has same l3 layer proto
    if pkt_ref.type != pkt_recv.type:
        return False

    if l3_proto == IP:
        # in case of ipv4, the timestamp is located in the checksum field
        timestamp = pkt_recv[IP].chksum

        # replace checksum field in received packet by original value
        pkt_recv[IP].chksum = pkt_ref[IP].chksum

    elif l3_proto == IPv6:
        # in case of ipv6, the timestamp is located in the flowlabel field
        timestamp = pkt_recv[IPv6].fl

        # replace flowlabel field in received packet by original value
        pkt_recv[IPv6].fl = pkt_ref[IPv6].fl

    # change timestamp byte order
    timestamp = ((timestamp >> 8) | (timestamp << 8)) & 0xFFFF

    # make sure timestamp matches reference
    if timestamp_ref != timestamp:
        return False

    # received packet should now be identical to reference packet
    return str(pkt_ref) == str(pkt_recv)


def validate_packet_timestamp_fixed(dut, pkt_ref, pkt_recv, timestamp_ref):
    """Validate packet content and timestamp at fixed byte position.

    Validates that packet data at DUT output matches the one that was applied
    at DUT input. Also makes sure that the timestamp stored at a fixed byte
    position in the packet data is correct. Returns True if validation was
    successful.
    """
    # is packet long enough to contain a timestamp?
    if int(dut.width_i) == 0:
        # timestamp is 16 bit wide
        if len(pkt_ref) < int(dut.pos_i)+2:
            # not long enough, make sure that packet data matches and no
            # timestamp has been inserted
            assert timestamp_ref is None
            return str(pkt_ref) == str(pkt_recv)
    else:
        # timestamp is 24 bit wide
        if len(pkt_ref) < int(dut.pos_i)+3:
            # not long enough, make sure that packet data matches and no
            # timestamp has been inserted
            assert timestamp_ref is None
            return str(pkt_ref) == str(pkt_recv)

    # extract timestamp from packet and make sure packet data is correct
    if int(dut.width_i) == 0:
        # timestamp is 16 bit wide
        timestamp = unpack("H",
                           str(pkt_recv)[int(dut.pos_i):int(dut.pos_i)+2])[0]

        # does packet data match?
        if str(pkt_recv)[0:int(dut.pos_i)] != str(pkt_ref)[0:int(dut.pos_i)]:
            return False
        if str(pkt_recv)[int(dut.pos_i)+2:] != str(pkt_ref)[int(dut.pos_i)+2:]:
            return False

    else:
        # timestamp is 24 bit wide
        timestamp = unpack("I",
                           str(pkt_recv)[int(dut.pos_i):int(dut.pos_i)+3] +
                           '\x00')[0]

        # does packet data match?
        if str(pkt_recv)[0:int(dut.pos_i)] != str(pkt_ref)[0:int(dut.pos_i)]:
            return False
        if str(pkt_recv)[int(dut.pos_i)+3:] != str(pkt_ref)[int(dut.pos_i)+3:]:
            return False

    # make sure timestamp matches reference
    return timestamp_ref == timestamp


@cocotb.coroutine
def timestamp_counter(dut):
    """Continuously increment timestamp counter input.

    Timestamp counter input signal is incremented every
    TIMESTAMP_COUNTER_CYCLES clock cycles.
    """
    # set initial counter value
    dut.timestamp_i <= 0

    i = 0

    # increase timestamp every TIMESTAMP_COUNTER_CYCLES cycles
    while True:
        yield RisingEdge(dut.clk156)
        i = i + 1
        if i == TIMESTAMP_COUNTER_CYCLES:
            if int(dut.timestamp_i) == 0xFFFFFF:
                dut.timestamp_i <= 0
            else:
                dut.timestamp_i <= int(dut.timestamp_i) + 1
            i = 0


@cocotb.coroutine
def packets_write(dut, axis_writer, pkts):
    """Apply packets on DuT input."""
    # iterate over all packets
    for pkt in pkts:
        # convert packet to AXI4-Stream data
        (tdata, tkeep) = packet_to_axis_data(pkt, AXIS_BIT_WIDTH)

        # apply data
        yield axis_writer.write(tdata, tkeep)

        # wait a random number of cycles before writing next packet
        yield wait_n_cycles(dut.clk156, randint(0, 10))


@cocotb.coroutine
def packets_read(dut, axis_reader, pkts_ref, timestamps):
    """Evaluate data at DuT output and validate correct behavior."""
    # read as many packets as we originally generated
    for i, pkt_ref in enumerate(pkts_ref):
        # read axi stream data
        (tdata, tkeep, _) = yield axis_reader.read()

        # convert axi stream data to scapy packet
        pkt = axis_data_to_packet(tdata, tkeep, AXIS_BIT_WIDTH)

        # check if sent and received packets match and if (possibly) inserted
        # timestamps match
        if int(dut.mode_i) == MODE_DISABLED:
            # timestamping is disabled, received and sent packets must be
            # identical
            valid = str(pkt) == str(pkt_ref)
        elif int(dut.mode_i) == MODE_HEADER:
            # timestamp is located in packet header
            valid = validate_packet_timestamp_header(pkt_ref, pkt,
                                                     timestamps[i])
        elif int(dut.mode_i) == MODE_FIXED_POS:
            # timestamp is loacted at fixed byte position
            valid = validate_packet_timestamp_fixed(dut, pkt_ref, pkt,
                                                    timestamps[i])
        else:
            # this should never happen
            assert False

        if not valid:
            raise cocotb.result.TestFailure(("Packet #%d: received invalid " +
                                             "packet data or timestamp") % i)

        # print progress
        print_progress(i, N_PACKETS)


@cocotb.coroutine
def monitor_timestamps(dut, pkts, timestamps):
    """Record the timestamps that are inserted into the packet headers."""
    axis_word_cntr = 0

    for i, pkt in enumerate(pkts):
        while True:
            yield RisingEdge(dut.clk156)
            # transfer active?
            if int(dut.s_axis_tvalid) == 1 and int(dut.s_axis_tready) == 1:

                if int(dut.mode_i) == MODE_HEADER:
                    # timestamps are inserted in IPv4 checksum or IPv6 flow
                    # label fields
                    if pkt.type == 0x0800 and axis_word_cntr == 3:
                        # ipv4 packet timestamps are in checksum field in 4th
                        # 8 byte word
                        timestamps.append(int(dut.timestamp_i))

                    elif pkt.type == 0x86dd and axis_word_cntr == 2:
                        # ipv6 packet timestamps are in flowlabel field in 3rd
                        # 8 byte word
                        timestamps.append(int(dut.timestamp_i))

                elif int(dut.mode_i) == MODE_FIXED_POS:
                    # timestamps are inserted at fixed byte position

                    # is the packet long enough to actually insert the
                    # timestamp?
                    if (int(dut.width_i) == 0 and
                            len(pkt) > int(dut.pos_i)+1) or \
                       (int(dut.width_i) == 1 and
                        len(pkt) > int(dut.pos_i)+2):

                        # is this the axi stream data word where the timestamp
                        # will be inserted?
                        if axis_word_cntr == int(dut.pos_i) / 8:
                            # record the timestamp
                            if int(dut.width_i) == 0:
                                # 16 bit timestamp
                                timestamps.append(int(dut.timestamp_i) &
                                                  0xFFFF)
                            else:
                                # 24 bit timestamp
                                timestamps.append(int(dut.timestamp_i))

                # last data word?
                if int(dut.s_axis_tlast):
                    axis_word_cntr = 0

                    # if no timestamp has been inserted (because packet is too
                    # small), record None
                    if len(timestamps) != i + 1:
                        timestamps.append(None)

                    break
                else:
                    axis_word_cntr += 1


@cocotb.coroutine
def perform_test(dut, axis_writer, axis_reader, pkts):
    """Perform a test run."""
    # create empty list of timestamp values
    timestamps = []

    # start one coroutine to evaluate packets on dut output
    coroutine_recv = cocotb.fork(packets_read(dut, axis_reader, pkts,
                                              timestamps))

    # start random toggling of axi stream reader tready signal
    cocotb.fork(toggle_signal(dut.clk156, dut.m_axis_tready))

    # start monitoring of timestamp values
    cocotb.fork(monitor_timestamps(dut, pkts, timestamps))

    yield RisingEdge(dut.clk156)

    # start one coroutine to apply packets on dut input
    cocotb.fork(packets_write(dut, axis_writer, pkts))

    # wait until all packets have been received
    yield coroutine_recv.join()


@cocotb.test()
def nt_gen_timestamp_insert_test(dut):
    """Test bench main function."""
    # start the clock
    cocotb.fork(clk_gen(dut.clk156, CLK_FREQ_MHZ))

    # no software reset
    dut.rst_sw156 <= 0

    # reset the dut
    yield rstn(dut.clk156, dut.rstn156)

    # create an axi stream writer, connect it and reset if
    axis_writer = AXIS_Writer()
    axis_writer.connect(dut, dut.clk156, AXIS_BIT_WIDTH)
    yield axis_writer.rst()

    # create an axi stream reader, connect it and reset if
    axis_reader = AXIS_Reader()
    axis_reader.connect(dut, dut.clk156, AXIS_BIT_WIDTH)
    yield axis_reader.rst()

    # start the timestamp counter
    cocotb.fork(timestamp_counter(dut))

    # generate some ip packets
    pkts = []
    for _ in range(N_PACKETS):
        pkts.append(gen_packet())

    # initially we insert timestamps in the packet headers
    dut.mode_i <= MODE_HEADER

    print("Test Timestamp Header")
    yield perform_test(dut, axis_writer, axis_reader, pkts)

    # then we perform one test where we do not insert any timestamps at all
    dut.mode_i <= MODE_DISABLED

    print("Test Timestamp Disabled")
    yield perform_test(dut, axis_writer, axis_reader, pkts)

    # next run some random tests with timestamp inserted at fixed byte position
    for i in range(N_REPEATS):
        # generate some ip packets
        pkts = []
        for _ in range(N_PACKETS):
            pkts.append(gen_packet())

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

        # perform the test
        print("Test Timestamp Fixed Pos %d/%d (Pos: %d, Width: %d)" %
              (i+1, N_REPEATS, pos, width))
        yield perform_test(dut, axis_writer, axis_reader, pkts)
