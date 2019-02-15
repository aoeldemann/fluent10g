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
// 10GbE MAC wrapper.

`timescale 1 ns / 1ps

module nt_10g_if_shared (
  input wire [63:0]    s_axis_tdata,
  input wire           s_axis_tvalid,
  input wire           s_axis_tlast,
  input wire [7:0]     s_axis_tkeep,
  output wire          s_axis_tready,

  output wire [63:0]   m_axis_tdata,
  output wire          m_axis_tvalid,
  output wire          m_axis_tlast,
  output wire [7:0]    m_axis_tkeep,
  input wire           m_axis_tready,

  input wire           refclk_n,
  input wire           refclk_p,
  input wire           reset,
  input wire           tx_fault,
  input wire           tx_abs,
  output wire          tx_disable,
  input wire           rxn,
  input wire           rxp,
  output wire          txn,
  output wire          txp,
  output wire          areset_clk156_out,
  output wire          clk156_out,
  output wire          gtrxreset_out,
  output wire          gttxreset_out,
  output wire          qplllock_out,
  output wire          qplloutclk_out,
  output wire          qplloutrefclk_out,
  output wire          txuserrdy_out,
  output wire          txusrclk_out,
  output wire          txusrclk2_out,
  output wire          reset_counter_done_out,
  output wire          resetdone
);

  wire signal_detect;
  assign signal_detect = ~tx_abs;

  axi_10g_ethernet_shared axi_10g_ethernet_shared_inst (
    .tx_axis_aresetn(~areset_clk156_out),
    .rx_axis_aresetn(~areset_clk156_out),
    .tx_ifg_delay(8'b0),
    .dclk(clk156_out),
    .txp(txp),
    .txn(txn),
    .rxp(rxp),
    .rxn(rxn),
    .signal_detect(signal_detect),
    .tx_fault(tx_fault),
    .tx_disable(tx_disable),
    .pcspma_status(),
    .sim_speedup_control(1'b0),
    .mac_tx_configuration_vector('h402), // 0x402 => tx enable, deficit idle
    .mac_rx_configuration_vector('h2), // 0x2 -> rx enable
    .mac_status_vector(),
    .pcs_pma_configuration_vector(536'b0),
    .pcs_pma_status_vector(),
    .txusrclk_out(txusrclk_out),
    .txusrclk2_out(txusrclk2_out),
    .gttxreset_out(gttxreset_out),
    .gtrxreset_out(gtrxreset_out),
    .txuserrdy_out(txuserrdy_out),
    .coreclk_out(clk156_out),
    .areset_datapathclk_out(areset_clk156_out),
    .resetdone_out(resetdone),
    .reset_counter_done_out(reset_counter_done_out),
    .qplllock_out(qplllock_out),
    .qplloutclk_out(qplloutclk_out),
    .qplloutrefclk_out(qplloutrefclk_out),
    .refclk_p(refclk_p),
    .refclk_n(refclk_n),
    .reset(reset),
    .s_axis_tx_tdata(s_axis_tdata),
    .s_axis_tx_tkeep(s_axis_tkeep),
    .s_axis_tx_tlast(s_axis_tlast),
    .s_axis_tx_tready(s_axis_tready),
    .s_axis_tx_tvalid(s_axis_tvalid),
    .s_axis_tx_tuser(1'b0),
    .s_axis_pause_tdata(16'b0),
    .s_axis_pause_tvalid(1'b0),
    .m_axis_rx_tdata(m_axis_tdata),
    .m_axis_rx_tkeep(m_axis_tkeep),
    .m_axis_rx_tlast(m_axis_tlast),
    .m_axis_rx_tuser(),
    .m_axis_rx_tvalid(m_axis_tvalid),
    .tx_statistics_valid(),
    .tx_statistics_vector(),
    .rx_statistics_valid(),
    .rx_statistics_vector(),
    .rxrecclk_out()
  );

endmodule
