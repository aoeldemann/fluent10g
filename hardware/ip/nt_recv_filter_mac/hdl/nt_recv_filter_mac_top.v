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
// This is the destination MAC address filter toplevel module. See description
// of the 'nt_recv_filter_mac' module for further information.

`timescale 1 ns / 1ps

`include "nt_recv_filter_mac_cpuregs_defines.vh"

module nt_recv_filter_mac_top # (
  parameter C_AXI_BASE_ADDRESS = 32'h00000000
)
(
  // clock and resets
  input wire           clk,
  input wire           rstn,
  input wire           rst_sw,

  // AXI4-Lite control interface
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

  // AXI4-Stream slave interface
  input wire [63:0]    s_axis_tdata,
  input wire [7:0]     s_axis_tkeep,
  input wire           s_axis_tvalid,
  input wire           s_axis_tlast,
  input wire [52:0]    s_axis_tuser,
  output wire          s_axis_tready,

  // AXI4-Stream master interface
  output wire [63:0]   m_axis_tdata,
  output wire [7:0]    m_axis_tkeep,
  output wire          m_axis_tvalid,
  output wire          m_axis_tlast,
  output wire [52:0]   m_axis_tuser,
  input wire           m_axis_tready
);

  // CPU regs
  wire [`CPUREG_CTRL_ADDR_DST_HI_BITS] cpureg_ctrl_addr_dst_hi;
  wire [`CPUREG_CTRL_ADDR_DST_LO_BITS] cpureg_ctrl_addr_dst_lo;
  wire [`CPUREG_CTRL_ADDR_MASK_DST_HI_BITS] cpureg_ctrl_addr_mask_dst_hi;
  wire [`CPUREG_CTRL_ADDR_MASK_DST_LO_BITS] cpureg_ctrl_addr_mask_dst_lo;

  // CPU regs
  nt_recv_filter_mac_cpuregs # (
    .C_AXI_BASE_ADDRESS(C_AXI_BASE_ADDRESS)
  ) nt_recv_filter_mac_cpuregs_inst (
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

    .cpureg_ctrl_addr_dst_hi_o(cpureg_ctrl_addr_dst_hi),
    .cpureg_ctrl_addr_dst_lo_o(cpureg_ctrl_addr_dst_lo),
    .cpureg_ctrl_addr_mask_dst_hi_o(cpureg_ctrl_addr_mask_dst_hi),
    .cpureg_ctrl_addr_mask_dst_lo_o(cpureg_ctrl_addr_mask_dst_lo)
  );

  // assemble MAC address and mask
  wire [47:0] addr_dst;
  assign addr_dst = (cpureg_ctrl_addr_dst_hi << 32) | cpureg_ctrl_addr_dst_lo;

  wire [47:0] addr_mask_dst;
  assign addr_mask_dst = (cpureg_ctrl_addr_mask_dst_hi << 32)
                          | cpureg_ctrl_addr_mask_dst_lo;

  // filter module
  nt_recv_filter_mac nt_recv_filter_mac_inst (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),

    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser(s_axis_tuser),
    .s_axis_tready(s_axis_tready),

    .m_axis_tdata(m_axis_tdata),
    .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tuser(m_axis_tuser),
    .m_axis_tready(m_axis_tready),

    .addr_dst_i(addr_dst),
    .addr_mask_dst_i(addr_mask_dst)
  );

endmodule
