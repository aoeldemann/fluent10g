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
// Toplevel TX rate control module.

`timescale 1 ns / 1ps

`include "nt_gen_rate_ctrl_cpuregs_defines.vh"

module nt_gen_rate_ctrl_top # (
  parameter C_AXI_BASE_ADDRESS = 32'h00000000
)
(
  input wire clk156,
  input wire rstn156,
  input wire rst_sw156,

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

  input wire [63:0]    s_axis_tdata,
  input wire           s_axis_tvalid,
  input wire           s_axis_tlast,
  input wire [7:0]     s_axis_tkeep,
  input wire [31:0]    s_axis_tuser,
  output wire          s_axis_tready,

  output wire [63:0]   m_axis_tdata,
  output wire          m_axis_tvalid,
  output wire          m_axis_tlast,
  output wire [7:0]    m_axis_tkeep,
  input wire           m_axis_tready,

  input wire           active_i
);

  // cpu registers
  wire [`CPUREG_STATUS_BITS]  cpureg_status;

  nt_gen_rate_ctrl_cpuregs # (
    .C_AXI_BASE_ADDRESS(C_AXI_BASE_ADDRESS)
  ) nt_gen_rate_ctrl_cpuregs_inst (
    .clk(clk156),
    .rstn(rstn156),

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

    .cpureg_status_i(cpureg_status)
  );


  wire [63:0] axis_fifo_tdata;
  wire        axis_fifo_tvalid;
  wire        axis_fifo_tlast;
  wire [7:0]  axis_fifo_tkeep;
  wire [31:0] axis_fifo_tuser;
  wire        axis_fifo_tready;

  // rate control module instance
  nt_gen_rate_ctrl nt_gen_rate_ctrl_inst (
    .clk(clk156),
    .rstn(rstn156),
    .rst_sw(rst_sw156),
    .s_axis_tdata(axis_fifo_tdata),
    .s_axis_tvalid(axis_fifo_tvalid),
    .s_axis_tlast(axis_fifo_tlast),
    .s_axis_tkeep(axis_fifo_tkeep),
    .s_axis_tuser(axis_fifo_tuser),
    .s_axis_tready(axis_fifo_tready),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tready(m_axis_tready),
    .ctrl_active_i(active_i),
    .status_warn_timing_o(cpureg_status[0:0])
  );

  // axis input fifo
  nt_gen_rate_ctrl_axis_fifo nt_gen_rate_ctrl_axis_fifo_inst(
    .s_axis_aresetn(rstn156 & ~rst_sw156),
    .s_axis_aclk(clk156),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser(s_axis_tuser),
    .m_axis_tvalid(axis_fifo_tvalid),
    .m_axis_tready(axis_fifo_tready),
    .m_axis_tdata(axis_fifo_tdata),
    .m_axis_tkeep(axis_fifo_tkeep),
    .m_axis_tlast(axis_fifo_tlast),
    .m_axis_tuser(axis_fifo_tuser),
    .axis_data_count(),
    .axis_wr_data_count(),
    .axis_rd_data_count()
  );

endmodule
