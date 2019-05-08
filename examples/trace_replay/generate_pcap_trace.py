#!/usr/bin/env python3
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
# Generate a simple constant-bit-rate PCAP trace with nanosecond timestamp
# resolution.

# we generate packets using scapy!
from scapy.all import *

# determine the length of the packets (in bytes) that shall be generated. a
# packet starts with the first byte of the Ethernet frame's destination MAC
# address and ends with the last byte of the payload. Preamble, start-of-frame
# delimiter, frame check sequence and interpacket gap are appended/prepended by
# the network tester.
PKTLEN = 60 # byte

# determine the data rate (in bits/second) at which packets shall be generated.
# the datarate referrs to the raw data rate. it includes all Ethernet protocol
# overheads (i.e. preamble, start-of-frame-delimiter, ...). On a 10 Gbps link,
# the maximum raw data rate we get is 10e9
DATARATE = 10e9 # 10 Gbps

# what shall be the total duration of the trace (in seconds)? Trace generation
# is quite time consuming. but no worries, the network tester can replay the
# trace multiple times without pauses!
DURATION = 100e-3 # 100 ms


def main():
    # calculate the time between two packet transmission. since the Ethernet
    # protocol overheads (preamble, start-of-frame-delimiter, fcs and
    # interpacket gap) is 24 bytes, add this to the packet length we originally
    # specified
    t_interpacket = 8*(PKTLEN + 24) / DATARATE

    # calculate how many packets we must generate to reach the specified
    # trace duration
    n_pkts = math.floor(DURATION/t_interpacket)

    # generate a single packet with an Ethernet header, fixed source and
    # destination MAC addresses. we will rewrite this packet to the trace
    # multiple times then, each time modifying its timestamp
    pkt = Ether(src="53:00:00:00:00:01", dst="53:00:00:00:00:02")

    # add zero padding to reach target packet length
    pkt /= Raw("".join("\x00" for _ in range(PKTLEN - len(pkt))))

    # open pcap writer with nanosecond precision timestamps
    try:
        wr = PcapWriter("trace.pcap", nano=True)
    except TypeError:
        print("ERROR! :-( Looks like you have an old version of the scapy " + \
              "library installed? Nanosecond timestamp precision does not " + \
              "seem to work.")
        exit(-1)

    print("Generating trace now, this might take a bit! (< 3 minutes)")

    # write packet 'n_pkts' times to the trace. adjust its timestamp each time
    for i in range(n_pkts):
        # set timestamp
        pkt.time = i*t_interpacket

        # write packet to trace
        wr.write(pkt)

    # close pcap writer
    wr.close()

if __name__ == "__main__":
    main()
