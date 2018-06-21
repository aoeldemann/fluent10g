// The MIT License
//
// Copyright (c) 2017-2018 by the author(s)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// Author(s):
//   - Andreas Oeldemann <andreas.oeldemann@tum.de>
//
// Description:
//
// AXI-Lite interface register widths, addresses and default values.

`define CPUREG_CTRL_CYCLES_PER_TICK_BITS      7:0
`define CPUREG_CTRL_CYCLES_PER_TICK_ADDR      32'h00
`define CPUREG_CTRL_CYCLES_PER_TICK_DEFAULT   8'b1

`define CPUREG_CTRL_MODE_BITS                 0:0
`define CPUREG_CTRL_MODE_ADDR                 32'h04
`define CPUREG_CTRL_MODE_DEFAULT              2'b0

`define CPUREG_CTRL_POS_BITS                  10:0
`define CPUREG_CTRL_POS_ADDR                  32'h08
`define CPUREG_CTRL_POS_DEFAULT               11'b0

`define CPUREG_CTRL_WIDTH_BITS                0:0
`define CPUREG_CTRL_WIDTH_ADDR                32'h0C
`define CPUREG_CTRL_WIDTH_DEFAULT             1'b1

