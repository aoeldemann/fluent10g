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
// Toplevel HDL file that intantiates the nt_recv_capture_rx and
// nt_recv_capture_fifo_merge modules for testing. Additionally, it also
// instantiates the two fifos between these modules.

`timescale 1 ns / 1ps

module nt_recv_capture_rx_fifo_merge_test
(
  // clock and resets
  input wire          clk,
  input wire          rstn,
  input wire          rst_sw,

  // AXI-S slave interface
  input wire [63:0]   s_axis_tdata,
  input wire          s_axis_tvalid,
  input wire          s_axis_tlast,
  input wire [7:0]    s_axis_tkeep,
  input wire [52:0]   s_axis_tuser,
  output wire         s_axis_tready,

  // activation signals
  input wire          active_i,
  input wire [15:0]   max_len_capture_i,

  // fifo output
  output wire [63:0]  fifo_din_o,
  output wire         fifo_wr_en_o,
  input wire          fifo_full_i,

  // activation status output
  output wire         active_o,

  // packet counter output
  output wire [31:0]  pkt_cnt_o,

  // fifo full error output
  output wire         err_meta_fifo_full_o,
  output wire         err_data_fifo_full_o
);

  wire [74:0] fifo_meta_din, fifo_meta_dout;
  wire [63:0] fifo_data_din, fifo_data_dout;
  wire fifo_meta_rd_en, fifo_meta_empty, fifo_meta_wr_en, fifo_meta_full;
  wire fifo_data_rd_en, fifo_data_empty, fifo_data_wr_en, fifo_data_full;

  // instantiate nt_recv_capture_rx module
  nt_recv_capture_rx nt_recv_capture_rx_inst (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tuser(s_axis_tuser),
    .s_axis_tready(s_axis_tready),
    .active_i(active_i),
    .max_len_capture_i(max_len_capture_i),
    .fifo_meta_din_o(fifo_meta_din),
    .fifo_meta_wr_en_o(fifo_meta_wr_en),
    .fifo_meta_full_i(fifo_meta_full),
    .fifo_data_din_o(fifo_data_din),
    .fifo_data_wr_en_o(fifo_data_wr_en),
    .fifo_data_full_i(fifo_data_full),
    .active_o(active_o),
    .pkt_cnt_o(pkt_cnt_o),
    .err_meta_fifo_full_o(err_meta_fifo_full_o),
    .err_data_fifo_full_o(err_data_fifo_full_o)
  );

  // instantiate nt_recv_capture_fifo_merge module
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
    .din(fifo_meta_din),
    .wr_en(fifo_meta_wr_en),
    .rd_en(fifo_meta_rd_en),
    .dout(fifo_meta_dout),
    .full(fifo_meta_full),
    .empty(fifo_meta_empty)
  );

  // instantiate data fifo
  nt_recv_capture_data_fifo nt_recv_capture_data_fifo_inst (
    .clk(clk),
    .srst(~rstn | rst_sw),
    .din(fifo_data_din),
    .wr_en(fifo_data_wr_en),
    .rd_en(fifo_data_rd_en),
    .dout(fifo_data_dout),
    .full(fifo_data_full),
    .empty(fifo_data_empty)
  );

endmodule
