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
// The module counts the bytes that are transferred on RX and TX AXI4-Stream
// interfaces within a configurable sample interval period. See nt_datarate.v
// for further information.
//
// AXI4-Stream interface signals are passed through without modifications from
// module input to output.

`timescale 1 ns / 1ps

`include "nt_datarate_cpuregs_defines.vh"

module nt_datarate_top # (
  parameter C_AXI_BASE_ADDRESS = 32'h00000000
)
(
  // clock and reset
  input wire clk156,
  input wire rstn156,
  input wire rst_sw156,

  // AXI4-Lite slave interface
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

  // AXI-S slave interface (rx)
  input wire [63:0]    s_axis_rx_tdata,
  input wire [7:0]     s_axis_rx_tkeep,
  input wire           s_axis_rx_tvalid,
  input wire           s_axis_rx_tlast,
  output wire          s_axis_rx_tready,
  input wire [52:0]    s_axis_rx_tuser,

  // AXI-S master interface (rx)
  output wire [63:0]   m_axis_rx_tdata,
  output wire [7:0]    m_axis_rx_tkeep,
  output wire          m_axis_rx_tvalid,
  output wire          m_axis_rx_tlast,
  input wire           m_axis_rx_tready,
  output wire [52:0]   m_axis_rx_tuser,

  // AXI-S slave interface (tx)
  input wire [63:0]    s_axis_tx_tdata,
  input wire [7:0]     s_axis_tx_tkeep,
  input wire           s_axis_tx_tvalid,
  input wire           s_axis_tx_tlast,
  output wire          s_axis_tx_tready,

  // AXI-S master interface (tx)
  output wire [63:0]   m_axis_tx_tdata,
  output wire [7:0]    m_axis_tx_tkeep,
  output wire          m_axis_tx_tvalid,
  output wire          m_axis_tx_tlast,
  input wire           m_axis_tx_tready
);

  // pass through axi-stream signals (rx)
  assign m_axis_rx_tdata = s_axis_rx_tdata;
  assign m_axis_rx_tvalid = s_axis_rx_tvalid;
  assign m_axis_rx_tlast = s_axis_rx_tlast;
  assign m_axis_rx_tkeep = s_axis_rx_tkeep;
  assign m_axis_rx_tuser = s_axis_rx_tuser;
  assign s_axis_rx_tready = m_axis_rx_tready;

  // pass through axi-stream signals (tx)
  assign m_axis_tx_tdata = s_axis_tx_tdata;
  assign m_axis_tx_tvalid = s_axis_tx_tvalid;
  assign m_axis_tx_tlast = s_axis_tx_tlast;
  assign m_axis_tx_tkeep = s_axis_tx_tkeep;
  assign s_axis_tx_tready = m_axis_tx_tready;

  // CPU registers
  wire [`CPUREG_CTRL_SAMPLE_INTERVAL_BITS]  cpureg_ctrl_sample_interval;
  wire [`CPUREG_STATUS_TX_N_BYTES_BITS]     cpureg_status_tx_n_bytes;
  wire [`CPUREG_STATUS_TX_N_BYTES_RAW_BITS] cpureg_status_tx_n_bytes_raw;
  wire [`CPUREG_STATUS_RX_N_BYTES_BITS]     cpureg_status_rx_n_bytes;
  wire [`CPUREG_STATUS_RX_N_BYTES_RAW_BITS] cpureg_status_rx_n_bytes_raw;

  // AXI4-Lite slave interface
  nt_datarate_ctrl_cpuregs # (
    .C_AXI_BASE_ADDRESS(C_AXI_BASE_ADDRESS)
  ) nt_datarate_cpuregs_inst (
    .clk(clk156),
    .rstn(rstn156),

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

    .cpureg_ctrl_sample_interval_o(cpureg_ctrl_sample_interval),
    .cpureg_status_tx_n_bytes_i(cpureg_status_tx_n_bytes),
    .cpureg_status_tx_n_bytes_raw_i(cpureg_status_tx_n_bytes_raw),
    .cpureg_status_rx_n_bytes_i(cpureg_status_rx_n_bytes),
    .cpureg_status_rx_n_bytes_raw_i(cpureg_status_rx_n_bytes_raw)
  );

  // rx datarate
  nt_datarate data_rate_rx (
    .clk(clk156),
    .rstn(rstn156),
    .rst_sw(rst_sw156),
    .axis_tvalid(s_axis_rx_tvalid),
    .axis_tready(s_axis_rx_tready),
    .axis_tlast(s_axis_rx_tlast),
    .axis_tkeep(s_axis_rx_tkeep),
    .sample_interval_i(cpureg_ctrl_sample_interval),
    .n_bytes_o(cpureg_status_rx_n_bytes),
    .n_bytes_raw_o(cpureg_status_rx_n_bytes_raw)
  );

  // tx datarate
  nt_datarate data_rate_tx (
    .clk(clk156),
    .rstn(rstn156),
    .rst_sw(rst_sw156),
    .axis_tvalid(s_axis_tx_tvalid),
    .axis_tready(s_axis_tx_tready),
    .axis_tlast(s_axis_tx_tlast),
    .axis_tkeep(s_axis_tx_tkeep),
    .sample_interval_i(cpureg_ctrl_sample_interval),
    .n_bytes_o(cpureg_status_tx_n_bytes),
    .n_bytes_raw_o(cpureg_status_tx_n_bytes_raw)
  );

endmodule
