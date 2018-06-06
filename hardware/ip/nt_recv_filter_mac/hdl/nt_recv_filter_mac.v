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
// The module receives Ethernet frames via an AXI4-Stream slave interface.
// It compares the destination address of the Ethernet frames to a
// pre-configured masked filter address. If the address matches, the inspected
// frame is sent out via an AXI4-Stream master interface. Frames whose address
// does not match are discarded.
//
// The module provides two signals to configure the destination MAC address to
// to match on: 'addr_dst_i' specifies the filter MAC address, 'addr_mask_dst_i'
// specify the bit mask determining which bits of the address must match.
// The latter signal allows the module to match entire regions of MAC addresses.

`timescale 1 ns / 1ps

module nt_recv_filter_mac (
  // clock and resets
  input wire clk,
  input wire rstn,
  input wire rst_sw,

  // AXI4-Stream slave interface
  input wire [63:0]    s_axis_tdata,
  input wire [7:0]     s_axis_tkeep,
  input wire           s_axis_tvalid,
  input wire           s_axis_tlast,
  output wire          s_axis_tready,
  input wire [52:0]    s_axis_tuser,

  // AXI4-Stream master interface
  output reg [63:0]    m_axis_tdata,
  output reg [7:0]     m_axis_tkeep,
  output reg           m_axis_tvalid,
  output reg           m_axis_tlast,
  input wire           m_axis_tready,
  output reg [52:0]    m_axis_tuser,

  // destination MAC address and mask
  input wire [47:0]    addr_dst_i,
  input wire [47:0]    addr_mask_dst_i
);

  // match destination MAC address
  wire addr_dst_match;
  assign addr_dst_match = (s_axis_tdata[47:0] & addr_mask_dst_i)
                            == (addr_dst_i & addr_mask_dst_i);

  // pass through TREADY signal
  assign s_axis_tready = m_axis_tready;

  parameter DO_MATCH  = 2'b00,
            MATCH     = 2'b01,
            NO_MATCH  = 2'b10;

  reg [1:0]   state, nxt_state;
  reg         nxt_m_axis_tvalid;

  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      m_axis_tdata <= 64'b0;
      m_axis_tkeep <= 8'b0;
      m_axis_tlast <= 1'b0;
      m_axis_tvalid <= 1'b0;
      m_axis_tuser <= 53'b0;

      state <= DO_MATCH;
    end else begin
      if (m_axis_tready) begin
        // slave is ready to receive, pass through data
        m_axis_tdata <= s_axis_tdata;
        m_axis_tkeep <= s_axis_tkeep;
        m_axis_tlast <= s_axis_tlast;
        m_axis_tuser <= s_axis_tuser;

        // TVALID must only be high when the frame arriving on the slave
        // interface matches the configured MAC address
        m_axis_tvalid <= nxt_m_axis_tvalid;
      end else begin
        // slave not ready to receive, keep register values as they are
        m_axis_tdata <= m_axis_tdata;
        m_axis_tkeep <= m_axis_tkeep;
        m_axis_tlast <= m_axis_tlast;
        m_axis_tuser <= m_axis_tuser;
        m_axis_tvalid <= m_axis_tvalid;
      end

      state <= nxt_state;
    end
  end


  always @(*) begin

    nxt_state = state;
    nxt_m_axis_tvalid = 1'b0;

    case (state)

      DO_MATCH: begin
        if (s_axis_tvalid) begin
          // first AXI4-Stream data word for each packet contains the
          // destination MAC address. do matching */
          if (addr_dst_match) begin
            // destination MAC address matches
            nxt_state = MATCH;
            nxt_m_axis_tvalid = 1'b1;
          end else begin
            // destination MAC address does not match. do not let the frame
            // pass
            nxt_state = NO_MATCH;
          end
        end
      end

      MATCH: begin
        if (s_axis_tvalid & m_axis_tready & s_axis_tlast) begin
          // the last data word of the current packet is being transferred,
          // we need to start matching again for the next packet
          nxt_state = DO_MATCH;
        end

        // pass through TVALID signal from slave to master interface
        nxt_m_axis_tvalid = s_axis_tvalid;
      end

      NO_MATCH: begin
        if (s_axis_tvalid & m_axis_tready & s_axis_tlast) begin
          // the last data word of the current packet is being transferred,
          // we need to start matching again for the next packet
          nxt_state = DO_MATCH;
        end
      end

    endcase
  end

endmodule
