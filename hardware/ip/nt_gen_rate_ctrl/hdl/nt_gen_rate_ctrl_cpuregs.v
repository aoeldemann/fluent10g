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
// AXI-Lite slave that contains control/status registers that can be
// read/written by the software running on the host computer via PCIExpress.
// Code partly generated by Xilinx Vivado peripheral generator.

`timescale 1 ns / 1ps

`include "nt_gen_rate_ctrl_cpuregs_defines.vh"

module nt_gen_rate_ctrl_cpuregs #
(
  parameter C_AXI_BASE_ADDRESS = 32'h00000000
)
(
  input wire          clk,
  input wire          rstn,

  input wire [31:0]   s_axi_awaddr,
  input wire [2:0]    s_axi_awport,
  input wire          s_axi_awvalid,
  output wire         s_axi_awready,
  input wire [31:0]   s_axi_wdata,
  input wire [3:0]    s_axi_wstrb,
  input wire          s_axi_wvalid,
  output wire         s_axi_wready,
  output wire [1:0]   s_axi_bresp,
  output wire         s_axi_bvalid,
  input wire          s_axi_bready,
  input wire [31:0]   s_axi_araddr,
  input wire [2:0]    s_axi_arprot,
  output wire         s_axi_arready,
  input wire          s_axi_arvalid,
  output wire [31:0]  s_axi_rdata,
  output wire [1:0]   s_axi_rresp,
  output wire         s_axi_rvalid,
  input wire          s_axi_rready,

  input wire [`CPUREG_STATUS_BITS] cpureg_status_i
);

  reg [31:0]  axi_awaddr;
  reg         axi_awready;
  reg         axi_wready;
  reg [1:0]   axi_bresp;
  reg         axi_bvalid;
  reg [31:0]  axi_araddr;
  reg         axi_arready;
  reg [31:0]  axi_rdata;
  reg [1:0]   axi_rresp;
  reg         axi_rvalid;

  assign s_axi_awready  = axi_awready;
  assign s_axi_wready   = axi_wready;
  assign s_axi_bresp    = axi_bresp;
  assign s_axi_bvalid   = axi_bvalid;
  assign s_axi_arready  = axi_arready;
  assign s_axi_rdata    = axi_rdata;
  assign s_axi_rresp    = axi_rresp;
  assign s_axi_rvalid   = axi_rvalid;

  /* axi_awready */
  always @(posedge clk) begin
    if (~rstn) begin
      axi_awready <= 1'b0;
    end else begin
      axi_awready <= ~axi_awready & s_axi_awvalid & s_axi_wvalid;
    end
  end

  /* axi_awaddr */
  always @(posedge clk) begin
    if (~rstn) begin
      axi_awaddr <= 0;
    end else begin
      if (~axi_awready & s_axi_awvalid & s_axi_wvalid) begin
        axi_awaddr <= s_axi_awaddr ^ C_AXI_BASE_ADDRESS;
      end
    end
  end

  /* axi_wready */
  always @(posedge clk) begin
    if (~rstn) begin
      axi_wready <= 1'b0;
    end else begin
      axi_wready <= ~axi_wready & s_axi_wvalid & s_axi_awvalid;
    end
  end

  /* axi_bvalid + axi_bresp */
  always @(posedge clk ) begin
    if (~rstn) begin
      axi_bvalid <= 0;
      axi_bresp <= 2'b0;
    end else begin
      if (axi_awready & s_axi_awvalid & ~axi_bvalid & axi_wready & s_axi_wvalid)
      begin
        axi_bvalid <= 1'b1;
        axi_bresp <= 2'b0;
      end else begin
        if (s_axi_bready & axi_bvalid) begin
          axi_bvalid <= 1'b0;
        end
      end
    end
  end

  /* axi_arready + axi_araddr */
  always @(posedge clk) begin
    if (~rstn) begin
      axi_arready <= 1'b0;
      axi_araddr <= {32{1'b0}};
    end else begin
      if (~axi_arready & s_axi_arvalid) begin
        axi_arready <= 1'b1;
        axi_araddr <= s_axi_araddr ^ C_AXI_BASE_ADDRESS;
      end else begin
        axi_arready <= 1'b0;
      end
    end
  end

  /* axi_rvalid + axi_resp */
  always @(posedge clk) begin
    if (~rstn) begin
      axi_rvalid <= 0;
      axi_rresp <= 0;
    end else begin
      if (axi_arready & s_axi_arvalid & ~axi_rvalid) begin
        axi_rvalid <= 1'b1;
        axi_rresp <= 2'b0;
      end else if (axi_rvalid & s_axi_rready) begin
        axi_rvalid <= 1'b0;
      end
    end
  end


  wire [31:0] addr_wr;
  assign addr_wr = axi_awaddr[31:2] << 2;

  /* register write */
  always @(posedge clk) begin
    if (~rstn) begin
    end else begin
      if (axi_wready & s_axi_wvalid) begin
        case(addr_wr)

        endcase
      end else begin

      end
    end
  end


  wire [31:0] addr_rd;
  assign addr_rd = axi_araddr[31:2] << 2;

  /* register read */
  always @(*) begin
    axi_rdata = 32'b0;

    if (axi_rvalid) begin
      case(addr_rd)

        `CPUREG_STATUS_ADDR:
          axi_rdata[`CPUREG_STATUS_BITS] = cpureg_status_i;

      endcase
    end
  end

endmodule
