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
// Toplevel HDL file for the nt_recv_capture_mem_write module. In addition to
// the tested module itself, it also instantiate the input fifo.

`timescale 1 ns / 1ps

module nt_recv_capture_mem_write_test
(
  // clock and resets
  input wire          clk,
  input wire          rstn,
  input wire          rst_sw,

  // AXI master data interface to DDR memory
  output wire [32:0]  m_axi_awaddr,
  output wire [7:0]   m_axi_awlen,
  output wire [2:0]   m_axi_awsize,
  output wire [1:0]   m_axi_awburst,
  output wire         m_axi_awlock,
  output wire [3:0]   m_axi_awcache,
  output wire [2:0]   m_axi_awprot,
  output wire [3:0]   m_axi_awqos,
  output wire         m_axi_awvalid,
  input wire          m_axi_awready,
  output wire [511:0] m_axi_wdata,
  output wire [63:0]  m_axi_wstrb,
  output wire         m_axi_wlast,
  output wire         m_axi_wvalid,
  input wire          m_axi_wready,
  output wire         m_axi_bready,
  input wire [1:0]    m_axi_bresp,
  input wire          m_axi_bvalid,
  output wire [32:0]  m_axi_araddr,
  output wire [7:0]   m_axi_arlen,
  output wire [2:0]   m_axi_arsize,
  output wire [1:0]   m_axi_arburst,
  output wire         m_axi_arlock,
  output wire [3:0]   m_axi_arcache,
  output wire [2:0]   m_axi_arprot,
  output wire [3:0]   m_axi_arqos,
  output wire         m_axi_arvalid,
  input wire          m_axi_arready,
  output wire         m_axi_rready,
  input wire [511:0]  m_axi_rdata,
  input wire [1:0]    m_axi_rresp,
  input wire          m_axi_rlast,
  input wire          m_axi_rvalid,

  // ring buffer address and size
  input wire [31:0]   mem_addr_hi_i,
  input wire [31:0]   mem_addr_lo_i,
  input wire [31:0]   mem_range_i,

  // ring buffer read and write pointers
  output wire [31:0]  addr_wr_o,
  input wire  [31:0]  addr_rd_i,

  // activation signals
  input wire          active_i,
  input wire          flush_i,

  // status signals
  output wire         active_o,

  // data fifo signals
  input wire [511:0]  fifo_din_i,
  input wire          fifo_wr_en_i,
  output wire         fifo_full_o
);

  wire [511:0] fifo_dout;
  wire [10:0]  fifo_rd_data_count;
  wire fifo_rd_en, fifo_empty, fifo_prog_empty;

  // nt_recv_capture_mem_write module
  nt_recv_capture_mem_write nt_recv_capture_mem_write_inst (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awqos(m_axi_awqos),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bready(m_axi_bready),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arqos(m_axi_arqos),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rready(m_axi_rready),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .mem_addr_hi_i(mem_addr_hi_i),
    .mem_addr_lo_i(mem_addr_lo_i),
    .mem_range_i(mem_range_i),
    .addr_wr_o(addr_wr_o),
    .addr_rd_i(addr_rd_i),
    .active_i(active_i),
    .flush_i(flush_i),
    .active_o(active_o),
    .fifo_dout_i(fifo_dout),
    .fifo_empty_i(fifo_empty),
    .fifo_prog_empty_i(fifo_prog_empty),
    .fifo_rd_data_count_i(fifo_rd_data_count),
    .fifo_rd_en_o(fifo_rd_en)
  );

  // input data fifo
  nt_recv_capture_mem_write_fifo nt_recv_capture_mem_write_fifo_inst (
    .clk(clk),
    .srst(~rstn | rst_sw),
    .din(fifo_din_i),
    .wr_en(fifo_wr_en_i),
    .rd_en(fifo_rd_en),
    .dout(fifo_dout),
    .full(fifo_full_o),
    .empty(fifo_empty),
    .rd_data_count(fifo_rd_data_count),
    .prog_empty(fifo_prog_empty)
  );

endmodule
