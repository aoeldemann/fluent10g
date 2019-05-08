#!/usr/bin/env python3
"""Creates a file with random trace data."""
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
# Creates a file with random trace data.

import random
from scapy.all import Ether

N_PKTS = 4000


def create_file():
    """Create a file with random trace data."""
    # open file
    f = open('random.file', 'wb')

    # accumulate number of bytes written to file
    size = 0

    for i in range(N_PKTS):
        # generate ethernet frame with random payload
        pkt = Ether(src="53:00:00:00:00:01", dst="53:00:00:00:00:02")
        pkt /= ''.join(chr(random.randint(0, 127)) for _ in
                       range(random.randint(50, 100)))

        # determine wire length and a random snap length (at least 14 bytes so
        # ethernet header is included)
        meta_len_wire = len(pkt)
        meta_len_snap = random.randint(14, len(pkt))

        # determine a random inter-packet time in cycles
        meta_delta_t = random.randint(0, 2**32-1)

        # assemble meta data word
        meta = meta_delta_t
        meta |= meta_len_snap << 32
        meta |= meta_len_wire << 48

        # write meta data word to file (aligned to 8 byte)
        f.write(meta.to_bytes(8, byteorder='little'))
        size += 8

        # calculate how many 8 byte data words we need to store the snap data
        if meta_len_snap % 8 == 0:
            n = int(meta_len_snap/8)
        else:
            n = int(meta_len_snap/8) + 1

        # convert packet to bytes
        pkt = bytes(pkt)

        # write snap data (aligned to 8 byte boundary)
        for i in range(n):
            data_len = min(8, len(pkt))
            data_len = min(data_len, meta_len_snap - i * 8)
            data = pkt[0:data_len]
            pkt = pkt[data_len:]
            while data_len < 8:
                data += b'\x00'
                data_len += 1
            f.write(data)
            size += 8

    # data of each packet is aligned to 8 bytes. total file size must be
    # aligned to 64 bytes. if padding data is required (i.e. zero or more 8
    # byte data words), all bits of the padding data must be set to 1
    while size % 64 != 0:
        f.write((2**64-1).to_bytes(8, byteorder='little'))
        size += 8

    # close file
    f.close()


if __name__ == "__main__":
    create_file()
