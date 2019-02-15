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
// AXI4-Stream packet counter toplevel module. The module has two AXI4-Stream
// slave interfaces and two AXI4-Stream master interfaces (one pair for RX,
// one pair for TX). Data is directly passed through.

`timescale 1 ns / 1ps

`include "nt_packet_counter_cpuregs_defines.vh"

module nt_packet_counter_top # (
  parameter C_AXI_BASE_ADDRESS = 32'h00000000
)
(
  input wire clk,
  input wire rstn,
  input wire rst_sw,

  input wire [31:0]    s_axi_awaddr,
  input wire [2:0]     s_axi_awprot,
  input wire           s_axi_awvalid,
  output wire          s_axi_awready,
  input wire [31:0]    s_axi_wdata,
  input wire [3:0]     s_axi_wstrb,
  input wire           s_axi_wvalid,
  output wire          s_axi_wready,
  output wire [1:0]    s_axi_bresp,
  output wire          s_axi_bvalid,
  input wire           s_axi_bready,
  input wire [31:0]    s_axi_araddr,
  input wire [2:0]     s_axi_arprot,
  output wire          s_axi_arready,
  input wire           s_axi_arvalid,
  output wire [31:0]   s_axi_rdata,
  output wire [1:0]    s_axi_rresp,
  output wire          s_axi_rvalid,
  input wire           s_axi_rready,

  input wire [63:0]    s_axis_rx_tdata,
  input wire           s_axis_rx_tvalid,
  input wire           s_axis_rx_tlast,
  input wire [7:0]     s_axis_rx_tkeep,
  input wire [52:0]    s_axis_rx_tuser,
  output wire          s_axis_rx_tready,

  output wire [63:0]   m_axis_rx_tdata,
  output wire          m_axis_rx_tvalid,
  output wire          m_axis_rx_tlast,
  output wire [7:0]    m_axis_rx_tkeep,
  output wire [52:0]   m_axis_rx_tuser,
  input wire           m_axis_rx_tready,

  input wire [63:0]    s_axis_tx_tdata,
  input wire           s_axis_tx_tvalid,
  input wire           s_axis_tx_tlast,
  input wire [7:0]     s_axis_tx_tkeep,
  input wire [31:0]    s_axis_tx_tuser,
  output wire          s_axis_tx_tready,

  output wire [63:0]   m_axis_tx_tdata,
  output wire          m_axis_tx_tvalid,
  output wire          m_axis_tx_tlast,
  output wire [7:0]    m_axis_tx_tkeep,
  output wire [31:0]   m_axis_tx_tuser,
  input wire           m_axis_tx_tready
);

  assign m_axis_rx_tdata = s_axis_rx_tdata;
  assign m_axis_rx_tvalid = s_axis_rx_tvalid;
  assign m_axis_rx_tlast= s_axis_rx_tlast;
  assign m_axis_rx_tkeep = s_axis_rx_tkeep;
  assign m_axis_rx_tuser = s_axis_rx_tuser;
  assign s_axis_rx_tready = m_axis_rx_tready;

  assign m_axis_tx_tdata = s_axis_tx_tdata;
  assign m_axis_tx_tvalid = s_axis_tx_tvalid;
  assign m_axis_tx_tlast= s_axis_tx_tlast;
  assign m_axis_tx_tkeep = s_axis_tx_tkeep;
  assign m_axis_tx_tuser = s_axis_tx_tuser;
  assign s_axis_tx_tready = m_axis_tx_tready;

  // CPU registers
  wire [`CPUREG_STATUS_N_PKTS_TX_BITS] cpureg_status_n_pkts_tx;
  wire [`CPUREG_STATUS_N_PKTS_RX_BITS] cpureg_status_n_pkts_rx;

  nt_packet_counter_cpuregs # (
    .C_AXI_BASE_ADDRESS(C_AXI_BASE_ADDRESS)
  ) nt_packet_counter_cpuregs_inst (
    .clk(clk),
    .rstn(rstn),

    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awport(s_axi_awprot),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arready(s_axi_arready),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),

    .cpureg_status_n_pkts_tx_i(cpureg_status_n_pkts_tx),
    .cpureg_status_n_pkts_rx_i(cpureg_status_n_pkts_rx)
  );

  // TX packet counter
  nt_packet_counter pkt_cntr_tx (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),
    .axis_tvalid(m_axis_tx_tvalid),
    .axis_tready(m_axis_tx_tready),
    .axis_tlast(m_axis_tx_tlast),
    .cntr_o(cpureg_status_n_pkts_tx)
  );

  // RX packet counter
  nt_packet_counter pkt_cntr_rx (
    .clk(clk),
    .rstn(rstn),
    .rst_sw(rst_sw),
    .axis_tvalid(m_axis_rx_tvalid),
    .axis_tready(m_axis_rx_tready),
    .axis_tlast(m_axis_rx_tlast),
    .cntr_o(cpureg_status_n_pkts_rx)
  );

  endmodule
