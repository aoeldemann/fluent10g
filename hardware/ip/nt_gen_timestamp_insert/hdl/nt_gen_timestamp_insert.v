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
// If enabled, the module inserts a 16/24 bit timestamp into the packet data.
// It receives incoming packets via an AXI4-Stream slave interface and transmits
// the (possibly) modified packets via an AXI4-Stream master interface.
// modified packets via an AXI4-Stream master interface.
//
// If the input signal 'mode_i' is set to MODE_FIXED_POS (b01), the timestamp
// is inserted in a configurable fixed byte position for each packet. The start
// byte position (in relation to the first byte of the packet) is specified by
// the 'pos_i' input signal. If 'width_i' is deasserted a 16 bit timestamp is
// inserted at the configured position, a 24 bit timestamp is inserted if
// 'width_i' is asserted. If the packet size is smaller than
// pos_i + timestamp width, no timestamp is inserted in the packet at all.
// Currently, the timestamp may not spread across multiple 8 byte AXI4-Stream
// data words. This means that for 16 bit timestamps the condition
// 'pos_i % 8 < 7' must hold true. For 24 bit timestamps the condition
// 'pos_i % 8 < 6' must be satisfied.
//
// If the input signal 'mode_i' is set to MODE_HEADER (b10), 16 bit timestamps
// are inserted into the IPv4 header checksum field of IPv4 packets and the
// IPv6 header flowlabel field of IPv6 packets. For non-IP packets, no
// timestamp is inserted at all. In this case, the input signals 'pos_i' and
// 'width_i' are not evaluated.
//
// If the input signal 'mode_i' is set to MODE_DISABLED (b00), the module is
// disabled and simply passes through packets without inserting a timestamp
// value.
//
// The module only inserts the timestamp at the appropriate location. All other
// packet data is left untouched. Packets where no timestamp can be inserted are
// simply passed through.
//
//
// The timestamps to be inserted are provided to the module via the
// 'timestamp_i' input signal.

`timescale 1 ns / 1ps

module nt_gen_timestamp_insert (
  // clock and resets
  input wire clk156,
  input wire rstn156,
  input wire rst_sw156,

  // AXI4-Stream slave interface
  input wire [63:0]    s_axis_tdata,
  input wire [7:0]     s_axis_tkeep,
  input wire           s_axis_tvalid,
  input wire           s_axis_tlast,
  output wire          s_axis_tready,

  // AXI4-Stream maszer inface
  output reg [63:0]    m_axis_tdata,
  output reg [7:0]     m_axis_tkeep,
  output reg           m_axis_tvalid,
  output reg           m_axis_tlast,
  input wire           m_axis_tready,

  input wire [1:0]     mode_i,
  input wire [10:0]    pos_i,
  input wire           width_i,
  input wire [23:0]    timestamp_i
);

  localparam [1:0] MODE_DISABLED  = 2'b00,
                   MODE_FIXED_POS = 2'b01,
                   MODE_HEADER    = 2'b10;

  // pass through TREADY signal
  assign s_axis_tready = m_axis_tready;

  // packet's ethertype
  reg [15:0] ethertype;

  // counts the number of axi stream words that have been transferred for each
  // indivial packet
  reg [7:0] axis_word_cntr;

  // axi stream word in which the timestamp shall be inserted (if mode_i is set
  // to MODE_FIXED_POS)
  wire [7:0] axis_word_select;
  assign axis_word_select = pos_i >> 3; // divide by 8 (axi stream word width)

  // byte position in the axi stream word at which the timestamp shall be
  // inserted (if mode_i is set to MODE_FIXED_POS)
  wire [2:0] axis_word_pos;
  assign axis_word_pos = pos_i - (pos_i & 11'h7F8); // modulo 8

  // insert 16 bit timestamp in axi stream data word (if mode_i is set to
  // MODE_FIXED_POS and width_i is low)
  reg [63:0] axis_tdata_timestamp16;
  always @(*) begin
    // does the timestamp fit in the data word?
    if (s_axis_tkeep[axis_word_pos+1]) begin
      axis_tdata_timestamp16 = s_axis_tdata;
      case (axis_word_pos)
        3'h0: axis_tdata_timestamp16[0+:16] = timestamp_i[15:0];
        3'h1: axis_tdata_timestamp16[8+:16] = timestamp_i[15:0];
        3'h2: axis_tdata_timestamp16[16+:16] = timestamp_i[15:0];
        3'h3: axis_tdata_timestamp16[24+:16] = timestamp_i[15:0];
        3'h4: axis_tdata_timestamp16[32+:16] = timestamp_i[15:0];
        3'h5: axis_tdata_timestamp16[40+:16] = timestamp_i[15:0];
        3'h6: axis_tdata_timestamp16[48+:16] = timestamp_i[15:0];
      endcase
    end else begin
      // timestamp does not fit
      axis_tdata_timestamp16 = s_axis_tdata;
    end
  end

  // insert 24 bit timestamp in axi stream data word (if mode_i is set to
  // MODE_FIXED_POS and width_i is high)
  reg [63:0] axis_tdata_timestamp24;
  always @(*) begin
    // does the timestamp fit in the data word?
    if (s_axis_tkeep[axis_word_pos+2]) begin
      axis_tdata_timestamp24 = s_axis_tdata;
      case (axis_word_pos)
        3'h0: axis_tdata_timestamp24[0+:24] = timestamp_i;
        3'h1: axis_tdata_timestamp24[8+:24] = timestamp_i;
        3'h2: axis_tdata_timestamp24[16+:24] = timestamp_i;
        3'h3: axis_tdata_timestamp24[24+:24] = timestamp_i;
        3'h4: axis_tdata_timestamp24[32+:24] = timestamp_i;
        3'h5: axis_tdata_timestamp24[40+:24] = timestamp_i;
      endcase
    end else begin
      // timestamp does not fit
      axis_tdata_timestamp24 = s_axis_tdata;
    end
  end

  // passes data from slave interface to master interface an inserts timestamp
  // at correct location
  always @(posedge clk156) begin
    if (~rstn156 | rst_sw156) begin
      m_axis_tdata <= 64'b0;
      m_axis_tkeep <= 8'b0;
      m_axis_tvalid <= 1'b0;
      m_axis_tlast <= 1'b0;
      ethertype <= 16'b0;
      axis_word_cntr <= 8'b0;
    end else begin
      if (m_axis_tready) begin
        // slave is ready to receive

        if (mode_i == MODE_HEADER) begin
          // 16 bit timestamps are inserted into the IPv4 checksum or IPv6
          // flowlabel fields

          if (axis_word_cntr == 1) begin
            // this is the second axi stream word -> includes ethertype
            ethertype <= s_axis_tdata[47:32];

            if (s_axis_tdata[47:32] == 16'hdd86) begin
              // this is an ipv6 packet. null out the four MSB of the flowlabel,
              // since we do not use them
              m_axis_tdata <= {s_axis_tdata[63:60], 4'b0, s_axis_tdata[55:0]};
            end else begin
              m_axis_tdata <= s_axis_tdata;
            end
          end else if (axis_word_cntr == 2) begin
            // this is the third axi stream word -> includes ipv6 flowlabel
            if (ethertype == 16'hdd86) begin
              m_axis_tdata <= {s_axis_tdata[63:16], timestamp_i[15:0]};
            end else begin
              m_axis_tdata <= s_axis_tdata;
            end
          end else if (axis_word_cntr == 3) begin
            // this is the fourth axi stream word -> includes ipv4 checksum
            if (ethertype == 16'h0008) begin
              m_axis_tdata <= {s_axis_tdata[63:16], timestamp_i[15:0]};
            end else begin
              m_axis_tdata <= s_axis_tdata;
            end
          end else begin
            m_axis_tdata <= s_axis_tdata;
          end
        end else if (mode_i == MODE_FIXED_POS) begin
          // timestamps are inserted at a fixed byte position

          if (axis_word_cntr == axis_word_select) begin
            // this is the axi stream word we want to insert the timestamp in

            if (width_i == 0) begin
              // insert 16 bit timestamp if width_i is low
              m_axis_tdata <= axis_tdata_timestamp16;
            end else begin
              // insert 24 bit timestamp if width_i is high
              m_axis_tdata <= axis_tdata_timestamp24;
            end
          end else begin
            m_axis_tdata <= s_axis_tdata;
          end
        end else begin
          // no timestamps are inserted at all, simply pass through data
          m_axis_tdata <= s_axis_tdata;
        end

        // pass through control signals
        m_axis_tkeep <= s_axis_tkeep;
        m_axis_tvalid <= s_axis_tvalid;
        m_axis_tlast <= s_axis_tlast;

        // if transaction is active, increment / reset axis word counter
        if (s_axis_tvalid) begin
          axis_word_cntr <= s_axis_tlast ? 8'b0 : (axis_word_cntr + 1);
        end else begin
          axis_word_cntr <= axis_word_cntr;
        end
      end else begin
        // slave is not ready to receive, leave all master values as they are
        m_axis_tdata <= m_axis_tdata;
        m_axis_tkeep <= m_axis_tkeep;
        m_axis_tvalid <= m_axis_tvalid;
        m_axis_tlast <= m_axis_tlast;

        ethertype <= ethertype;
        axis_word_cntr <= axis_word_cntr;
      end
    end
  end

endmodule
