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
// Global control.

`timescale 1 ns / 1ps

`include "nt_ctrl_cpuregs_defines.vh"

module nt_ctrl_top # (
  parameter C_AXI_BASE_ADDRESS = 32'h00000000
)
(
  input wire clk,
  input wire rstn,

  input wire clk156,
  input wire rstn156,

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

  output reg [3:0] rate_ctrl_active_o,
  output reg       rst_sw,
  output reg       rstn_sw,
  output reg       rst_sw156,
  output reg       rstn_sw156
);

  // cpu register wires
  wire [`CPUREG_CTRL_RATE_CTRL_ACTIVE_BITS] cpureg_ctrl_rate_ctrl_active;
  wire [`CPUREG_RST_BITS]                   cpureg_rst;

  nt_ctrl_cpuregs # (
    .C_AXI_BASE_ADDRESS(C_AXI_BASE_ADDRESS)
  ) nt_ctrl_cpuregs_inst (
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

    .cpureg_ctrl_rate_ctrl_active_o(cpureg_ctrl_rate_ctrl_active),
    .cpureg_rst_o(cpureg_rst)
  );

  // TX rate control active signal
  always @(posedge clk156) begin
    if (~rstn156 | cpureg_rst[0:0]) begin
      rate_ctrl_active_o <= 4'b0;
    end else begin
      rate_ctrl_active_o <= cpureg_ctrl_rate_ctrl_active;
    end
  end

  // software reset signal in 200 MHz clock domain
  always @(posedge clk) begin
    if (~rstn) begin
      rst_sw <= 1'b0;
      rstn_sw <= 1'b1;
    end else begin
      rst_sw <= cpureg_rst[0:0];
      rstn_sw <= ~cpureg_rst[0:0];
    end
  end

  // software reset signal in 156.25 MHz clock domain
  always @(posedge clk156) begin
    if (~rstn156) begin
      rst_sw156 <= 1'b0;
      rstn_sw156 <= 1'b1;
    end else begin
      rst_sw156 <= cpureg_rst[0:0];
      rstn_sw156 <= ~cpureg_rst[0:0];
    end
  end

endmodule
