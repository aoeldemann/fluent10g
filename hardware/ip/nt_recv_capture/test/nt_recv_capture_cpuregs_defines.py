"""Register address offsets."""
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
# Register address offsets.

CPUREG_OFFSET_CTRL_ACTIVE               = 0x00000000
CPUREG_OFFSET_CTRL_MEM_ADDR_LO          = 0x00000004
CPUREG_OFFSET_CTRL_MEM_ADDR_HI          = 0x00000008
CPUREG_OFFSET_CTRL_MEM_RANGE            = 0x0000000C
CPUREG_OFFSET_CTRL_ADDR_WR              = 0x00000010
CPUREG_OFFSET_CTRL_ADDR_RD              = 0x00000014
CPUREG_OFFSET_CTRL_MAX_LEN_CAPTURE      = 0x00000018
CPUREG_OFFSET_STATUS_PKT_CNT            = 0x0000001C
CPUREG_OFFSET_STATUS_ACTIVE             = 0x00000020
CPUREG_OFFSET_STATUS_ERRS               = 0x00000024
