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
// Toplevel module of an IP core, which receives network packets via an
// AXI4-Stream interface and transfers the packets and meta data to a ring
// buffer in DDR3 memory via an AXI4 master interface.

`timescale 1 ns / 1ps

`include "nt_recv_capture_cpuregs_defines.vh"

module nt_recv_capture_top # (
  parameter C_AXI_BASE_ADDRESS = 32'h00000000
)
(
  // clock and reset
  input wire           clk,
  input wire           rstn,
  input wire           rst_sw,

  // AXI4-Lite slave control interface
  input wire [31:0]    s_axi_ctrl_awaddr,
  input wire [2:0]     s_axi_ctrl_awprot,
  input wire           s_axi_ctrl_awvalid,
  output wire          s_axi_ctrl_awready,
  input wire [31:0]    s_axi_ctrl_wdata,
  input wire [3:0]     s_axi_ctrl_wstrb,
  input wire           s_axi_ctrl_wvalid,
  output wire          s_axi_ctrl_wready,
  output wire [1:0]    s_axi_ctrl_bresp,
  output wire          s_axi_ctrl_bvalid,
  input wire           s_axi_ctrl_bready,
  input wire [31:0]    s_axi_ctrl_araddr,
  input wire [2:0]     s_axi_ctrl_arprot,
  output wire          s_axi_ctrl_arready,
  input wire           s_axi_ctrl_arvalid,
  output wire [31:0]   s_axi_ctrl_rdata,
  output wire [1:0]    s_axi_ctrl_rresp,
  output wire          s_axi_ctrl_rvalid,
  input wire           s_axi_ctrl_rready,

  // AXI4 master data interface to DDR memory
  output wire [32:0]   m_axi_ddr3_awaddr,
  output wire [7:0]    m_axi_ddr3_awlen,
  output wire [2:0]    m_axi_ddr3_awsize,
  output wire [1:0]    m_axi_ddr3_awburst,
  output wire          m_axi_ddr3_awlock,
  output wire [3:0]    m_axi_ddr3_awcache,
  output wire [2:0]    m_axi_ddr3_awprot,
  output wire [3:0]    m_axi_ddr3_awqos,
  output wire          m_axi_ddr3_awvalid,
  input wire           m_axi_ddr3_awready,
  output wire [511:0]  m_axi_ddr3_wdata,
  output wire [63:0]   m_axi_ddr3_wstrb,
  output wire          m_axi_ddr3_wlast,
  output wire          m_axi_ddr3_wvalid,
  input wire           m_axi_ddr3_wready,
  output wire          m_axi_ddr3_bready,
  input wire [1:0]     m_axi_ddr3_bresp,
  input wire           m_axi_ddr3_bvalid,
  output wire [32:0]   m_axi_ddr3_araddr,
  output wire [7:0]    m_axi_ddr3_arlen,
  output wire [2:0]    m_axi_ddr3_arsize,
  output wire [1:0]    m_axi_ddr3_arburst,
  output wire          m_axi_ddr3_arlock,
  output wire [3:0]    m_axi_ddr3_arcache,
  output wire [2:0]    m_axi_ddr3_arprot,
  output wire [3:0]    m_axi_ddr3_arqos,
  output wire          m_axi_ddr3_arvalid,
  input wire           m_axi_ddr3_arready,
  output wire          m_axi_ddr3_rready,
  input wire [511:0]   m_axi_ddr3_rdata,
  input wire [1:0]     m_axi_ddr3_rresp,
  input wire           m_axi_ddr3_rlast,
  input wire           m_axi_ddr3_rvalid,

  // AXI4-Stream slave data interface for arriving packet and meta data
  input wire [63:0]    s_axis_tdata,
  input wire           s_axis_tvalid,
  input wire           s_axis_tlast,
  input wire [7:0]     s_axis_tkeep,
  input wire [52:0]    s_axis_tuser,
  output wire          s_axis_tready
);

  // CPU registers
  wire [`CPUREG_CTRL_ACTIVE_BITS]             cpureg_ctrl_active;
  wire [`CPUREG_CTRL_MEM_ADDR_LO_BITS]        cpureg_ctrl_mem_addr_lo;
  wire [`CPUREG_CTRL_MEM_ADDR_HI_BITS]        cpureg_ctrl_mem_addr_hi;
  wire [`CPUREG_CTRL_MEM_RANGE_BITS]          cpureg_ctrl_mem_range;
  wire [`CPUREG_CTRL_ADDR_WR_BITS]            cpureg_ctrl_addr_wr;
  wire [`CPUREG_CTRL_ADDR_RD_BITS]            cpureg_ctrl_addr_rd;
  wire [`CPUREG_CTRL_MAX_LEN_CAPTURE_BITS]    cpureg_ctrl_max_len_capture;
  wire [`CPUREG_STATUS_PKT_CNT_BITS]          cpureg_status_pkt_cnt;
  wire [`CPUREG_STATUS_ACTIVE_BITS]           cpureg_status_active;
  wire [`CPUREG_STATUS_ERRS_BITS]             cpureg_status_errs;

  wire rx_active_ctrl;
  wire rx_active_status;
  wire mem_write_active_ctrl;
  wire mem_write_active_status;
  wire mem_write_flush;
  wire mem_write_fifo_align;
  wire mem_write_fifo_align_done;

  wire [74:0] fifo_meta_din, fifo_meta_dout;
  wire [63:0] fifo_data_din, fifo_data_dout;
  wire        fifo_meta_wr_en, fifo_meta_rd_en, fifo_meta_full,
                fifo_meta_empty;
  wire        fifo_data_wr_en, fifo_data_rd_en, fifo_data_full,
                fifo_data_empty;

  wire [63:0]   fifo_din;
  wire [511:0]  fifo_dout;
  wire [10:0]   fifo_rd_data_count;
  wire          fifo_wr_en, fifo_rd_en, fifo_full, fifo_empty, fifo_prog_empty;

  // registers accessiable by software
  nt_recv_capture_cpuregs # (
    .C_AXI_BASE_ADDRESS(C_AXI_BASE_ADDRESS)
  ) nt_recv_capture_cpuregs_inst (
    .clk(clk),
    .rstn(rstn),

    .s_axi_awaddr(s_axi_ctrl_awaddr),
    .s_axi_awport(s_axi_ctrl_awprot),
    .s_axi_awvalid(s_axi_ctrl_awvalid),
    .s_axi_awready(s_axi_ctrl_awready),
    .s_axi_wdata(s_axi_ctrl_wdata),
    .s_axi_wstrb(s_axi_ctrl_wstrb),
    .s_axi_wvalid(s_axi_ctrl_wvalid),
    .s_axi_wready(s_axi_ctrl_wready),
    .s_axi_bresp(s_axi_ctrl_bresp),
    .s_axi_bvalid(s_axi_ctrl_bvalid),
    .s_axi_bready(s_axi_ctrl_bready),
    .s_axi_araddr(s_axi_ctrl_araddr),
    .s_axi_arprot(s_axi_ctrl_arprot),
    .s_axi_arready(s_axi_ctrl_arready),
    .s_axi_arvalid(s_axi_ctrl_arvalid),
    .s_axi_rdata(s_axi_ctrl_rdata),
    .s_axi_rresp(s_axi_ctrl_rresp),
    .s_axi_rvalid(s_axi_ctrl_rvalid),
    .s_axi_rready(s_axi_ctrl_rready),

    .cpureg_ctrl_active_o(cpureg_ctrl_active),
    .cpureg_ctrl_mem_addr_lo_o(cpureg_ctrl_mem_addr_lo),
    .cpureg_ctrl_mem_addr_hi_o(cpureg_ctrl_mem_addr_hi),
    .cpureg_ctrl_mem_range_o(cpureg_ctrl_mem_range),
    .cpureg_ctrl_addr_wr_i(cpureg_ctrl_addr_wr),
    .cpureg_ctrl_addr_rd_o(cpureg_ctrl_addr_rd),
    .cpureg_ctrl_max_len_capture_o(cpureg_ctrl_max_len_capture),
    .cpureg_status_pkt_cnt_i(cpureg_status_pkt_cnt),
    .cpureg_status_active_i(cpureg_status_active),
    .cpureg_status_errs_i(cpureg_status_errs)
  );

  nt_recv_capture_ctrl nt_recv_capture_ctrl_inst (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),
    .ctrl_active_i(cpureg_ctrl_active[0:0]),
    .status_active_o(cpureg_status_active[0:0]),
    .rx_active_o(rx_active_ctrl),
    .rx_active_i(rx_active_status),
    .mem_write_active_o(mem_write_active_ctrl),
    .mem_write_active_i(mem_write_active_status),
    .mem_write_flush_o(mem_write_flush),
    .mem_write_fifo_align_o(mem_write_fifo_align),
    .mem_write_fifo_align_done_i(mem_write_fifo_align_done),
    .mem_write_fifo_prog_empty_i(fifo_prog_empty),
    .fifo_meta_empty_i(fifo_meta_empty),
    .fifo_data_empty_i(fifo_data_empty)
  );

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
    .active_i(rx_active_ctrl),
    .max_len_capture_i(cpureg_ctrl_max_len_capture),
    .fifo_meta_din_o(fifo_meta_din),
    .fifo_meta_wr_en_o(fifo_meta_wr_en),
    .fifo_meta_full_i(fifo_meta_full),
    .fifo_data_din_o(fifo_data_din),
    .fifo_data_wr_en_o(fifo_data_wr_en),
    .fifo_data_full_i(fifo_data_full),
    .active_o(rx_active_status),
    .pkt_cnt_o(cpureg_status_pkt_cnt),
    .err_meta_fifo_full_o(cpureg_status_errs[0:0]),
    .err_data_fifo_full_o(cpureg_status_errs[1:1])
  );

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
    .fifo_din_o(fifo_din),
    .fifo_wr_en_o(fifo_wr_en),
    .fifo_full_i(fifo_full)
  );

  nt_recv_capture_mem_write nt_recv_capture_mem_write_inst (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),
    .m_axi_awaddr(m_axi_ddr3_awaddr),
    .m_axi_awlen(m_axi_ddr3_awlen),
    .m_axi_awsize(m_axi_ddr3_awsize),
    .m_axi_awburst(m_axi_ddr3_awburst),
    .m_axi_awlock(m_axi_ddr3_awlock),
    .m_axi_awcache(m_axi_ddr3_awcache),
    .m_axi_awprot(m_axi_ddr3_awprot),
    .m_axi_awqos(m_axi_ddr3_awqos),
    .m_axi_awvalid(m_axi_ddr3_awvalid),
    .m_axi_awready(m_axi_ddr3_awready),
    .m_axi_wdata(m_axi_ddr3_wdata),
    .m_axi_wstrb(m_axi_ddr3_wstrb),
    .m_axi_wlast(m_axi_ddr3_wlast),
    .m_axi_wvalid(m_axi_ddr3_wvalid),
    .m_axi_wready(m_axi_ddr3_wready),
    .m_axi_bready(m_axi_ddr3_bready),
    .m_axi_bresp(m_axi_ddr3_bresp),
    .m_axi_bvalid(m_axi_ddr3_bvalid),
    .m_axi_araddr(m_axi_ddr3_araddr),
    .m_axi_arlen(m_axi_ddr3_arlen),
    .m_axi_arsize(m_axi_ddr3_arsize),
    .m_axi_arburst(m_axi_ddr3_arburst),
    .m_axi_arlock(m_axi_ddr3_arlock),
    .m_axi_arcache(m_axi_ddr3_arcache),
    .m_axi_arprot(m_axi_ddr3_arprot),
    .m_axi_arqos(m_axi_ddr3_arqos),
    .m_axi_arvalid(m_axi_ddr3_arvalid),
    .m_axi_arready(m_axi_ddr3_arready),
    .m_axi_rready(m_axi_ddr3_rready),
    .m_axi_rdata(m_axi_ddr3_rdata),
    .m_axi_rresp(m_axi_ddr3_rresp),
    .m_axi_rlast(m_axi_ddr3_rlast),
    .m_axi_rvalid(m_axi_ddr3_rvalid),
    .fifo_dout_i(fifo_dout),
    .fifo_empty_i(fifo_empty),
    .fifo_prog_empty_i(fifo_prog_empty),
    .fifo_rd_data_count_i(fifo_rd_data_count),
    .fifo_rd_en_o(fifo_rd_en),
    .mem_addr_hi_i(cpureg_ctrl_mem_addr_hi),
    .mem_addr_lo_i(cpureg_ctrl_mem_addr_lo),
    .mem_range_i(cpureg_ctrl_mem_range),
    .addr_wr_o(cpureg_ctrl_addr_wr),
    .addr_rd_i(cpureg_ctrl_addr_rd),
    .active_i(mem_write_active_ctrl),
    .flush_i(mem_write_flush),
    .active_o(mem_write_active_status)
  );

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

  nt_recv_capture_mem_write_fifo_wrapper
    nt_recv_capture_mem_write_fifo_wrapper_inst (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),
    .din_i(fifo_din),
    .wr_en_i(fifo_wr_en),
    .full_o(fifo_full),
    .dout_o(fifo_dout),
    .rd_en_i(fifo_rd_en),
    .empty_o(fifo_empty),
    .prog_empty_o(fifo_prog_empty),
    .rd_data_count_o(fifo_rd_data_count),
    .align_i(mem_write_fifo_align),
    .align_done_o(mem_write_fifo_align_done)
  );

endmodule
