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
// Toplevel HDL file for the nt_recv_capture_fifo_merge module. In addition to
// the tested module itself, it also instantiates the two input fifos for packet
// and meta data.

`timescale 1 ns / 1ps

module nt_recv_capture_fifo_merge_test
(
  // clock and resets
  input wire          clk,
  input wire          rstn,
  input wire          rst_sw,

  // meta data fifo input
  input wire [74:0]   fifo_meta_din_i,
  input wire          fifo_meta_wr_en_i,
  output wire         fifo_meta_full_o,

  // packet data fifo input
  input wire [63:0]   fifo_data_din_i,
  input wire          fifo_data_wr_en_i,
  output wire         fifo_data_full_o,

  // merged fifo output
  output wire [63:0]  fifo_din_o,
  output wire         fifo_wr_en_o,
  input wire          fifo_full_i
);

  wire [74:0] fifo_meta_dout;
  wire [63:0] fifo_data_dout;
  wire fifo_meta_rd_en, fifo_meta_empty;
  wire fifo_data_rd_en, fifo_data_empty;

  // instantiate module to be tested
  nt_recv_capture_fifo_merge nt_recv_capture_fifo_merge_inst (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),
    .fifo_meta_dout_i(fifo_meta_dout),
    .fifo_meta_empty_i(fifo_meta_empty),
    .fifo_meta_rd_en_o(fifo_meta_rd_en),
    .fifo_data_dout_i(fifo_data_dout),
    .fifo_data_empty_i(fifo_data_empty),
    .fifo_data_rd_en_o(fifo_data_rd_en),
    .fifo_din_o(fifo_din_o),
    .fifo_wr_en_o(fifo_wr_en_o),
    .fifo_full_i(fifo_full_i)
  );

  // instantiate meta fifo
  nt_recv_capture_meta_fifo nt_recv_capture_meta_fifo_inst (
    .clk(clk),
    .srst(~rstn | rst_sw),
    .din(fifo_meta_din_i),
    .wr_en(fifo_meta_wr_en_i),
    .rd_en(fifo_meta_rd_en),
    .dout(fifo_meta_dout),
    .full(fifo_meta_full_o),
    .empty(fifo_meta_empty)
  );

  // instantiate data fifo
  nt_recv_capture_data_fifo nt_recv_capture_data_fifo_inst (
    .clk(clk),
    .srst(~rstn | rst_sw),
    .din(fifo_data_din_i),
    .wr_en(fifo_data_wr_en_i),
    .rd_en(fifo_data_rd_en),
    .dout(fifo_data_dout),
    .full(fifo_data_full_o),
    .empty(fifo_data_empty)
  );

endmodule
