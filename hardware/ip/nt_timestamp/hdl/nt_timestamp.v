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
// Module maintains a 24 bit timestamp counter that is incremented every
// cycles_per_tick_i clock cycles.

`timescale 1 ns / 1 ps

module nt_timestamp (
  // clock and reset
  input wire        clk,
  input wire        rstn,

  // number of clock cycles between two counter increments
  input wire [7:0]  cycles_per_tick_i,

  // timestamp counter output
  output reg [23:0] timestamp_o
);

  reg [7:0] tick_cntr;

  // process increments output timestamp_o counter every cycles_per_tick_i
  // cycles. when maximum value is reached, counter is reset to zero
  always @(posedge clk) begin
    if (~rstn) begin
      timestamp_o <= 24'b0;
    end else begin
      if (tick_cntr == (cycles_per_tick_i - 1)) begin
        if (timestamp_o == 24'hFFFFFF) begin
          timestamp_o <= 24'b0;
        end else begin
          timestamp_o <= timestamp_o + 24'b1;
        end
      end else begin
        timestamp_o <= timestamp_o;
      end
    end
  end

  // process increments tick_cntr every clock cycle. When cycles_per_tick_i is
  // reached, counter is reset
  always @(posedge clk) begin
    if (~rstn) begin
      tick_cntr <= 8'b0;
    end else begin
      if (tick_cntr >= (cycles_per_tick_i - 1)) begin
        tick_cntr <= 8'b0;
      end else begin
        tick_cntr <= tick_cntr + 8'b1;
      end
    end
  end

endmodule
