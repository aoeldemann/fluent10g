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

`define CPUREG_CTRL_ACTIVE_BITS             0:0
`define CPUREG_CTRL_ACTIVE_ADDR             32'h00
`define CPUREG_CTRL_ACTIVE_DEFAULT          1'b0

`define CPUREG_CTRL_MEM_ADDR_LO_BITS        31:0
`define CPUREG_CTRL_MEM_ADDR_LO_ADDR        32'h04
`define CPUREG_CTRL_MEM_ADDR_LO_DEFAULT     32'b0

`define CPUREG_CTRL_MEM_ADDR_HI_BITS        31:0
`define CPUREG_CTRL_MEM_ADDR_HI_ADDR        32'h08
`define CPUREG_CTRL_MEM_ADDR_HI_DEFAULT     32'b0

`define CPUREG_CTRL_MEM_RANGE_BITS          31:0
`define CPUREG_CTRL_MEM_RANGE_ADDR          32'h0C
`define CPUREG_CTRL_MEM_RANGE_DEFAULT       32'b0

`define CPUREG_CTRL_ADDR_WR_BITS            31:0
`define CPUREG_CTRL_ADDR_WR_ADDR            32'h10

`define CPUREG_CTRL_ADDR_RD_BITS            31:0
`define CPUREG_CTRL_ADDR_RD_ADDR            32'h14
`define CPUREG_CTRL_ADDR_RD_DEFAULT         32'b0

`define CPUREG_CTRL_MAX_LEN_CAPTURE_BITS    15:0
`define CPUREG_CTRL_MAX_LEN_CAPTURE_ADDR    32'h18
`define CPUREG_CTRL_MAX_LEN_CAPTURE_DEFAULT 16'b0

`define CPUREG_STATUS_PKT_CNT_BITS          31:0
`define CPUREG_STATUS_PKT_CNT_ADDR          32'h1C

`define CPUREG_STATUS_ACTIVE_BITS           0:0
`define CPUREG_STATUS_ACTIVE_ADDR           32'h20

`define CPUREG_STATUS_ERRS_BITS             1:0
`define CPUREG_STATUS_ERRS_ADDR             32'h24
