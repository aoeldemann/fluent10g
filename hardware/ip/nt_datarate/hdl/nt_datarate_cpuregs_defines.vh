// The MIT License
//
// Copyright (c) 2017-2019 by the author(s)
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

`define CPUREG_CTRL_SAMPLE_INTERVAL_BITS      31:0
`define CPUREG_CTRL_SAMPLE_INTERVAL_ADDR      32'h00
`define CPUREG_CTRL_SAMPLE_INTERVAL_DEFAULT   32'h9502F90 // 156250000 (1 sec)

`define CPUREG_STATUS_TX_N_BYTES_BITS         31:0
`define CPUREG_STATUS_TX_N_BYTES_ADDR         32'h04

`define CPUREG_STATUS_TX_N_BYTES_RAW_BITS     31:0
`define CPUREG_STATUS_TX_N_BYTES_RAW_ADDR     32'h08

`define CPUREG_STATUS_RX_N_BYTES_BITS         31:0
`define CPUREG_STATUS_RX_N_BYTES_ADDR         32'h0C

`define CPUREG_STATUS_RX_N_BYTES_RAW_BITS     31:0
`define CPUREG_STATUS_RX_N_BYTES_RAW_ADDR     32'h10
