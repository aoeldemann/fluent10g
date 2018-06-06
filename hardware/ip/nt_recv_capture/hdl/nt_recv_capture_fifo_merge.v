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
// This module combines the data from two input FIFOs (data + meta) into a
// single output FIFO. The flow is as follows:
//
//   1.) Read one 64 bit FIFO entry from the 'fifo_meta' FIFO.
//   3.) Write the entry read in 1.) to the output FIFO.
//   3.) Bits [52:42] of the read word contain the number of bytes that shall be
//       read from the 'fifo_data' FIFO. Since FIFO elements are 64 bits wide,
//       calculate how many entires must be read to cover at least the extracted
//       number of bytes. If the number of entries to be read is larger than zero
//       go to 4.) otherwise start over at 1.)
//   4.) Read one 64 bit FIFO entry from the 'fifo_data' FIFO.
//   5.) Write entry read in 4.) to the output FIFO.
//   6.) Go back to 4.) if the number of entries read is smaller than the number
//       calculated in 3.)
//   7.) Go back to 1.)

`timescale 1 ns / 1ps

module nt_recv_capture_fifo_merge
(
  // clock and resets
  input wire          clk,
  input wire          rstn,
  input wire          rst_sw,

  // meta data input fifo
  input wire [74:0]   fifo_meta_dout_i,
  input wire          fifo_meta_empty_i,
  output wire         fifo_meta_rd_en_o,

  // data input fifo
  input wire [63:0]   fifo_data_dout_i,
  input wire          fifo_data_empty_i,
  output wire         fifo_data_rd_en_o,

  // output fifo
  output wire [63:0]  fifo_din_o,
  output wire         fifo_wr_en_o,
  input wire          fifo_full_i
);

  // extract packet capture length from meta data
  wire [10:0] meta_len_capture;
  assign meta_len_capture = fifo_meta_dout_i[74:64];

  // number of 64 bit words we need to read from data fifo
  reg [7:0] data_word_cnt_sig;

  // process calculates the number of data words that need to be read from the
  // data input fifo for the current packet
  always @(*) begin
    if ((meta_len_capture & 11'h7) == 0) begin
      // meta_len_capture is a multiple of 8
      data_word_cnt_sig = meta_len_capture >> 3;
    end else begin
      // meta_len_capture is not a multiple of 8 bytes -> round up
      data_word_cnt_sig = (meta_len_capture >> 3) + 11'b1;
    end
  end

  // FSM states
  parameter META = 1'b0,
            DATA = 1'b1;

  reg           state, nxt_state;
  reg [7:0]     data_word_cnt, nxt_data_word_cnt;
  reg [7:0]     data_word_cntr, nxt_data_word_cntr;

  // FSM
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      state <= META;
    end else begin
      state <= nxt_state;
    end

    data_word_cnt <= nxt_data_word_cnt;
    data_word_cntr <= nxt_data_word_cntr;
  end

  // FSM
  always @(*) begin
    nxt_state = state;
    nxt_data_word_cnt = data_word_cnt;
    nxt_data_word_cntr = data_word_cntr;

    case (state)
      META: begin
        if (~fifo_full_i & ~fifo_meta_empty_i) begin
          // there is data to be read from the meta input FIFO and the output
          // FIFO is not full. Initialize the number of data words that need to
          // be read from the data FIFO
          nxt_data_word_cnt = data_word_cnt_sig;
          nxt_data_word_cntr = 8'b0;

          if (data_word_cnt_sig > 0) begin
            // we are going to read at least one data word from the data fifo
            nxt_state = DATA;
          end
        end
      end

      DATA: begin
        if (~fifo_full_i & ~fifo_data_empty_i) begin
          // the output FIFO is not full and there is data to be read from the
          // data input FIFO

          // increment counter
          nxt_data_word_cntr = data_word_cntr + 1;

          if ((data_word_cntr + 1) == data_word_cnt) begin
            // all data words have been read
            nxt_state = META;
          end
        end
      end

    endcase
  end

  // assign output FIFO input signals (capture length in bits [74:64] of the
  // meta data word is not transferred to software)
  assign fifo_din_o = (state == META) ? fifo_meta_dout_i[63:0] :
                        fifo_data_dout_i;
  assign fifo_wr_en_o = ~fifo_full_i &
                          (((state == META) & ~fifo_meta_empty_i) ||
                           ((state == DATA) & ~fifo_data_empty_i));

  // assign input FIFOs output signals
  assign fifo_meta_rd_en_o
    = ~fifo_full_i & (state == META) & ~fifo_meta_empty_i;
  assign fifo_data_rd_en_o
    = ~fifo_full_i & (state == DATA) & ~fifo_data_empty_i;

endmodule
