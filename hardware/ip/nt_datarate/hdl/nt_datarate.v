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
// The module counts the bytes that are transferred on an AXI4-Stream interface
// within a configurable sample interval period. The number of counted bytes
// are written to the output registers whenever a sampling period ends. The
// duration of the sampling period is specified in number of clock cycles via
// the 'sample_interval_i' input signal. The output register 'n_bytes_o'
// contains the number of bytes transferred in the last sampling period. It
// includes Ethernet frame data starting at the destination MAC address until
// the end of the payload. To account for the preamble, start of frame
// delimiter, FCS and inter-frame gap, the output register 'n_bytes_raw_o'
// contains a byte count in which 24 bytes have been added for each observed
// packet.

`timescale 1 ns / 1ps

module nt_datarate (
  // clock and resets
  input wire clk,
  input wire rstn,
  input wire rst_sw,

  // AXI4-Stream signals
  input wire        axis_tvalid,
  input wire        axis_tready,
  input wire        axis_tlast,
  input wire [7:0]  axis_tkeep,

  // sample interval length in clock cycles
  input wire [31:0] sample_interval_i,

  // number of bytes received/transmitted in last sample interval
  output reg [31:0] n_bytes_o,

  // number of bytes received/transmitted in last sample interval (including
  // FCS, preample and gap)
  output reg [31:0] n_bytes_raw_o
);

  // clock cycle counter
  reg [31:0] clk_cntr;

  // number of bytes that have been transferred so far in the current interval
  reg [31:0] n_bytes, n_bytes_raw;


  // number of bytes that are transferred in this clock cycle
  reg [3:0] n_bytes_cycle;
  reg [5:0] n_bytes_raw_cycle;

  // determine how many bytes are transferred in this clock cycle
  always @(axis_tvalid, axis_tready, axis_tlast, axis_tkeep) begin
    if (axis_tvalid & axis_tready) begin
      if (axis_tlast) begin
        // this is the last word of the axi stream transaction. evaluate tkeep
        // to see how many bytes are transferred
        case (axis_tkeep)
          8'b00000001: n_bytes_cycle = 4'd1;
          8'b00000011: n_bytes_cycle = 4'd2;
          8'b00000111: n_bytes_cycle = 4'd3;
          8'b00001111: n_bytes_cycle = 4'd4;
          8'b00011111: n_bytes_cycle = 4'd5;
          8'b00111111: n_bytes_cycle = 4'd6;
          8'b01111111: n_bytes_cycle = 4'd7;
          8'b11111111: n_bytes_cycle = 4'd8;
          default: n_bytes_cycle = 4'd0;
        endcase

        // we do not see preamble, SOD, FCS and inter-frame gap. add 24 byte to
        // account for the raw data rate
        n_bytes_raw_cycle = n_bytes_cycle + 6'd24;
      end else begin
        // not the last word, so always transferring 8 byte
        n_bytes_cycle = 4'd8;
        n_bytes_raw_cycle = 4'd8;
      end
    end else begin
      n_bytes_cycle = 4'd0;
      n_bytes_raw_cycle = 4'd0;
    end
  end

  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      clk_cntr <= 32'b0;
      n_bytes_o <= 32'b0;
      n_bytes_raw_o <= 32'b0;
      n_bytes <= 32'b0;
      n_bytes_raw <= 32'b0;
    end else begin
      if (clk_cntr == (sample_interval_i - 32'b1)) begin
        // end of sample interval has been reached. write counters to output
        // registers. reset counters for a fresh sample interval
        clk_cntr <= 32'b0;
        n_bytes_o <= n_bytes + n_bytes_cycle;
        n_bytes_raw_o <= n_bytes_raw + n_bytes_raw_cycle;
        n_bytes <= 32'b0;
        n_bytes_raw <= 32'b0;
      end else begin
        // end of sample interval has not been reached. leave output registers
        // as they are and increment byte counters for the current interval
        clk_cntr <= clk_cntr + 32'b1;
        n_bytes_o <= n_bytes_o;
        n_bytes_raw_o <= n_bytes_raw_o;
        n_bytes <= n_bytes + n_bytes_cycle;
        n_bytes_raw <= n_bytes_raw + n_bytes_raw_cycle;
      end
    end
  end

endmodule
