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
// Module counts the number of packets transferred via an AXI4-Stream and
// outputs the counter value via the 'cntr_o' signal.

`timescale 1 ns / 1ps

module nt_packet_counter (
  // clock and resets
  input wire clk,
  input wire rstn,
  input wire rst_sw,

  // AXI4-Stream signals
  input wire axis_tvalid,
  input wire axis_tready,
  input wire axis_tlast,

  output reg [31:0]    cntr_o
);

  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      cntr_o <= 32'b0;
    end else begin
      if (axis_tvalid & axis_tready & axis_tlast) begin
        // packet transfer completed, increment counter
        cntr_o <= cntr_o + 1;
      end else begin
        cntr_o <= cntr_o;
      end
    end
  end

endmodule
