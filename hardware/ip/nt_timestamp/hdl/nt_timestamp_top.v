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
// Module creates a 24 bit timestamp and provides it to other modules to allow
// determination of packet latencies. The timestamp is tapped from a 16 bit
// counter register, whose value is incremented every few clock cycles. The
// number of clock cycles that shall pass between counter increments can by
// specified by the software using the CPUREG_CTRL_CYCLES_PER_TICK register.
// The maximum latency that the network tester can measure is defined as
// 2^16 * CPUREG_CTRL_CYCLES_PER_TICK * 6.4 ns (@ 156.25 MHz frequency).
// Setting CPUREG_CTRL_CYCLES_PER_TICK to a small value results in measurment
// accuracy improvements, but limits the range in which latencies can be
// measured.
//
// Further software can configure the values of the 'mode_o', 'pos_o' and
// 'width_o' output signals. If 'mode_o' is asserted, the timestamp values
// are inserted/extracted to/from IP header fields. If 'mode_o' is deasserted,
// the timestamps are inserted/extracted from a fixed byte location within the
// packet data. The byte position (in relation to the start of each packet)
// is configured via the 'pos_o' output signal. If 'width_o' is asserted, a
// 24 bit timestamp is inserted/extracted from the packet data. If the signal
// is asserted, a 16 bit timestamp is used instead.

`timescale 1 ns / 1 ps

`include "nt_timestamp_cpuregs_defines.vh"

module nt_timestamp_top # (
  parameter C_AXI_BASE_ADDRESS = 32'h00000000
)
(
  // clock and reset
  input wire clk156,
  input wire rstn156,

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

  // timestamp output
  output wire [23:0]   timestamp_o,
  output wire          mode_o,
  output wire [10:0]   pos_o,
  output wire          width_o
);

  // cpu registers
  wire [`CPUREG_CTRL_CYCLES_PER_TICK_BITS] cpureg_ctrl_cycles_per_tick;

  nt_timestamp_cpuregs # (
    .C_AXI_BASE_ADDRESS(C_AXI_BASE_ADDRESS)
  ) nt_timestamp_cpuregs_inst (
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

    .cpureg_ctrl_cycles_per_tick_o(cpureg_ctrl_cycles_per_tick),
    .cpureg_ctrl_mode_o(mode_o),
    .cpureg_ctrl_pos_o(pos_o),
    .cpureg_ctrl_width_o(width_o)
  );

  nt_timestamp nt_timestamp_inst (
    .clk(clk156),
    .rstn(rstn156),
    .cycles_per_tick_i(cpureg_ctrl_cycles_per_tick),
    .timestamp_o(timestamp_o)
  );

endmodule
