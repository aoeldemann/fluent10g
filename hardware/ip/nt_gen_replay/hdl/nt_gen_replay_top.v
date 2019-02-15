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
// Toplevel module of an IP core, which reads trace data from a ring buffer in
// DDR3 memory via an AXI4 master interface and transmits the included packets
// via an AXI4-Stream interface.

`timescale 1 ns / 1ps

`include "nt_gen_replay_cpuregs_defines.vh"

module nt_gen_replay_top # (
  parameter C_AXI_BASE_ADDRESS = 32'h00000000
)
(
  input wire clk,
  input wire rstn,
  input wire rst_sw,

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

  output wire [63:0]   m_axis_tdata,
  output wire          m_axis_tvalid,
  output wire          m_axis_tlast,
  output wire [7:0]    m_axis_tkeep,
  output wire [31:0]   m_axis_tuser,
  input wire           m_axis_tready
);

  /* cpu registers */
  wire [`CPUREG_CTRL_MEM_ADDR_LO_BITS]      cpureg_ctrl_mem_addr_lo;
  wire [`CPUREG_CTRL_MEM_ADDR_HI_BITS]      cpureg_ctrl_mem_addr_hi;
  wire [`CPUREG_CTRL_MEM_RANGE_BITS]        cpureg_ctrl_mem_range;
  wire [`CPUREG_CTRL_TRACE_SIZE_LO_BITS]    cpureg_ctrl_trace_size_lo;
  wire [`CPUREG_CTRL_TRACE_SIZE_HI_BITS]    cpureg_ctrl_trace_size_hi;
  wire [`CPUREG_CTRL_ADDR_WR_BITS]          cpureg_ctrl_addr_wr;
  wire [`CPUREG_CTRL_ADDR_RD_BITS]          cpureg_ctrl_addr_rd;
  wire [`CPUREG_CTRL_START_BITS]            cpureg_ctrl_start;
  wire [`CPUREG_STATUS_BITS]                cpureg_status;

  nt_gen_replay_cpuregs # (
    .C_AXI_BASE_ADDRESS(C_AXI_BASE_ADDRESS)
  ) nt_gen_replay_cpuregs_inst (
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

    .cpureg_ctrl_mem_addr_lo_o(cpureg_ctrl_mem_addr_lo),
    .cpureg_ctrl_mem_addr_hi_o(cpureg_ctrl_mem_addr_hi),
    .cpureg_ctrl_mem_range_o(cpureg_ctrl_mem_range),
    .cpureg_ctrl_trace_size_lo_o(cpureg_ctrl_trace_size_lo),
    .cpureg_ctrl_trace_size_hi_o(cpureg_ctrl_trace_size_hi),
    .cpureg_ctrl_addr_wr_o(cpureg_ctrl_addr_wr),
    .cpureg_ctrl_addr_rd_i(cpureg_ctrl_addr_rd),
    .cpureg_ctrl_start_o(cpureg_ctrl_start),
    .cpureg_status_i(cpureg_status)
  );

  wire [511:0] mem_read_fifo_din;
  wire [63:0]  mem_read_fifo_dout;
  wire         mem_read_fifo_wr_en;
  wire         mem_read_fifo_rd_en;
  wire         mem_read_fifo_prog_full;
  wire         mem_read_fifo_empty;
  wire         mem_read_status_active;

  assign cpureg_status[0:0] = mem_read_status_active;

  nt_gen_replay_mem_read nt_gen_replay_mem_read_inst (
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

    .fifo_din_o(mem_read_fifo_din),
    .fifo_wr_en_o(mem_read_fifo_wr_en),
    .fifo_prog_full_i(mem_read_fifo_prog_full),

    .ctrl_mem_addr_hi_i(cpureg_ctrl_mem_addr_hi),
    .ctrl_mem_addr_lo_i(cpureg_ctrl_mem_addr_lo),
    .ctrl_mem_range_i(cpureg_ctrl_mem_range),
    .ctrl_trace_size_hi_i(cpureg_ctrl_trace_size_hi),
    .ctrl_trace_size_lo_i(cpureg_ctrl_trace_size_lo),
    .ctrl_addr_wr_i(cpureg_ctrl_addr_wr),
    .ctrl_addr_rd_o(cpureg_ctrl_addr_rd),
    .ctrl_start_i(cpureg_ctrl_start),
    .status_active_o(mem_read_status_active)
  );

  nt_gen_replay_mem_read_fifo nt_gen_replay_mem_read_fifo_inst (
    .clk(clk),
    .srst(~rstn | rst_sw),
    .din(mem_read_fifo_din),
    .wr_en(mem_read_fifo_wr_en),
    .rd_en(mem_read_fifo_rd_en),
    .dout(mem_read_fifo_dout),
    .full(),
    .empty(mem_read_fifo_empty),
    .prog_full(mem_read_fifo_prog_full)
  );

  nt_gen_replay_assemble nt_gen_replay_assemble_inst (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),

    .fifo_dout_i(mem_read_fifo_dout),
    .fifo_rd_en_o(mem_read_fifo_rd_en),
    .fifo_empty_i(mem_read_fifo_empty),

    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tready(m_axis_tready),
    .m_axis_tuser(m_axis_tuser),

    .ctrl_start_i(cpureg_ctrl_start),
    .status_mem_read_active_i(mem_read_status_active),
    .status_active_o(cpureg_status[1:1]),
    .status_err_fifo_drain_o(cpureg_status[2:2])
  );

endmodule
