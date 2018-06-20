#!/usr/bin/env python3
"""Create a simple nanosecond precision PCAP file for testing."""
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
# Create a simple nanosecond precision PCAP file for testing.

from scapy.all import *

# name of the PCAP file to generate
FILENAME = "test_nano.pcap"

# number of packets to generate
N_PKTS = 100

# inter-packet generation time in nanoseconds
IPG = 1000e-9 # (1000 ns, 156.25 clock cycles @ 6.4 ns)

# packet size in bytes
PKT_SIZE = 791

def main():
    # generate random source and destination MAC addresses
    macAddrSrc = RandMAC()._fix()
    macAddrDst = RandMAC()._fix()

    # generate random source and destination IP addresses
    ipAddrSrc = RandIP()._fix()
    ipAddrDst = RandIP()._fix()

    # create packet
    pkt = Ether(src=macAddrSrc, dst=macAddrDst)/IP(src=ipAddrSrc, dst=ipAddrDst)

    # append zero padding to reach desired packet size
    pkt /= ''.join('\x00' for _ in range(PKT_SIZE-len(pkt)))

    # packet transmission time
    t = 0.0

    # nanosecond timestamp precision is only supported by newer scapy versions.
    # make sure it works, otherwise abort with an error message
    try:
        PcapWriter(FILENAME, nano=True)
    except TypeError:
        print("Cannot create nanosecond precision timestap PCAP trace file.")
        print("This is likely because your Scapy version is too old. Please")
        print("update to a new version and try again.")
        exit(-1)

    # write packets to pcap file
    with PcapWriter(FILENAME, nano=True) as pcap_writer:
        for _ in range(N_PKTS):
            # set packet time
            pkt.time = t

            # write packet
            pcap_writer.write(pkt)

            # increment time
            t += IPG

if __name__ == "__main__":
    main()
