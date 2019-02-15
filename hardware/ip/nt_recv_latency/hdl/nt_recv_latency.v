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
// The module extracts a 16/24 bit timestamp from packet data and calculates
// the latency of the packet by comapring the transmission timestamp extracted
// from the packet to the current time provided via the 'timestamp_i' input
// signal. It receives incoming packets via an AXI4-Stream slave interface and
// passes the received packets through to an AXI4-Stream master interface
// without modifying them. If a transmission timestamp was extracted and thus
// the latency has been calculated, the latency value is inserted in bits [23:0]
// of the AXI4-Stream TUSER signal when the last data word of the packet
// is being transferred (i.e. when TLAST is high). Bit 24 is set high if a
// a latency value has been inserted, it is set low if no latency value was
// calculated and inserted (in this case also bits [23:0] are zero). Whenever
// TLAST is not asserted, all bits of TUSER are set to zero.

// If the input signal 'mode_i' is set to MODE_HEADER (b10), the 16 bit
// transmission timestamp is extracted from the header of IPv4 or IPv6 packets.
// For IPv4 packets, the timestamp is located in the checksum header field, for
// IPv6 packets it is located in the flowlabel header field. For non-IP
// packets, no timestamp is being extracted and thus no latency is calculated.
//
// If the input signal 'mode_i' is set to MODE_FIXED_POS (b01), the transmission
// timestamp is extracted from a configurable fixed byte position for each
// packet. The start byte position (in reloation to the first byte of the
// packet) is specified by the 'pos_i' input signal. If 'width_i' is
// deasserted, a 16 bit timestamp is extracted. A 24 bit timestamp is extracted
// if 'width_i' is asserted. If the packet size is smaller than
// pos_i + timestamp width, the packet is too short to contain a timestamp and
// thus no extraction and latency calculation takes place. Currently, the
// timestamp may not spread across multiple 8 byte AXI4-Stream data words.
// This means that for 16 bit timestamps the condition 'pos_i % 8 < 7' must hold
// true. For 24 bit timestamps the condition 'pos_i % 8 < 6' must be satisfied.
//
// If the input signal 'mode_i' is set to MODE_DISABLED (b00), timestamp is
// disabled and thus no timestamp is extracted.

`timescale 1 ns / 1ps

module nt_recv_latency (
  // clock and reset
  input wire clk156,
  input wire rstn156,
  input wire rst_sw156,

  // AXI-S slave interface
  input wire [63:0]    s_axis_tdata,
  input wire [7:0]     s_axis_tkeep,
  input wire           s_axis_tvalid,
  input wire           s_axis_tlast,
  output wire          s_axis_tready,

  // AXI-S master interface
  output reg [63:0]    m_axis_tdata,
  output reg [7:0]     m_axis_tkeep,
  output reg           m_axis_tvalid,
  output reg           m_axis_tlast,
  input wire           m_axis_tready,
  output reg [24:0]    m_axis_tuser,

  // timestamp extraction configuration
  input wire [1:0]  mode_i,
  input wire [10:0] pos_i,
  input wire        width_i,

  // current time
  input wire [23:0] timestamp_i
);

  localparam [1:0] MODE_DISABLED  = 2'b00,
                   MODE_FIXED_POS = 2'b01,
                   MODE_HEADER    = 2'b10;

  // packet's ethertype
  reg [15:0] ethertype;

  // counts the number of AXI4-Stream words that have been transferred for each
  // indivial packet
  reg [7:0] axis_word_cntr;

  // pass through TREADY from slave to master
  assign s_axis_tready = m_axis_tready;

  // axi stream word in which the timestamp is located (if mode_i is set to
  // MODE_FIXED_POS)
  wire [7:0] axis_word_select;
  assign axis_word_select = pos_i >> 3; // divide by 8 (axi stream word width)

  // byte position in the axi stream word at which the timestamp is located
  // (if mode_i is set to MODE_FIXED_POS)
  wire [2:0] axis_word_pos;
  assign axis_word_pos = pos_i - (pos_i & 11'h7F8); // modulo 8

  reg [15:0] timestamp_fixed_pos16;
  always @(*) begin
    case (axis_word_pos)
      3'h0: timestamp_fixed_pos16 = s_axis_tdata[0+:16];
      3'h1: timestamp_fixed_pos16 = s_axis_tdata[8+:16];
      3'h2: timestamp_fixed_pos16 = s_axis_tdata[16+:16];
      3'h3: timestamp_fixed_pos16 = s_axis_tdata[24+:16];
      3'h4: timestamp_fixed_pos16 = s_axis_tdata[32+:16];
      3'h5: timestamp_fixed_pos16 = s_axis_tdata[40+:16];
      3'h6: timestamp_fixed_pos16 = s_axis_tdata[48+:16];
    endcase
  end

  reg [23:0] timestamp_fixed_pos24;
  always @(*) begin
    case (axis_word_pos)
      3'h0: timestamp_fixed_pos24 = s_axis_tdata[0+:24];
      3'h1: timestamp_fixed_pos24 = s_axis_tdata[8+:24];
      3'h2: timestamp_fixed_pos24 = s_axis_tdata[16+:24];
      3'h3: timestamp_fixed_pos24 = s_axis_tdata[24+:24];
      3'h4: timestamp_fixed_pos24 = s_axis_tdata[32+:24];
      3'h5: timestamp_fixed_pos24 = s_axis_tdata[40+:24];
    endcase
  end

  // determines whether the extracted timestamp at a fixed byte position (i.e.
  // mode_i set to MODE_FIXED_POS) is valid
  reg timestamp_fixed_pos_valid;
  always @(*) begin
    // is current axi stream word long enough to contain a timestamp?
    if (~width_i) begin
      // 16 bit timestamp
      timestamp_fixed_pos_valid = s_axis_tkeep[axis_word_pos+1];
    end else begin
      // 24 bit timestamp
      timestamp_fixed_pos_valid = s_axis_tkeep[axis_word_pos+2];
    end
  end

  // latency calculation based on timestamp extracted from IP header
  wire [15:0] latency_header;
  assign latency_header = (timestamp_i[15:0] >= s_axis_tdata[15:0]) ?
                            (timestamp_i[15:0] - s_axis_tdata[15:0])
                          : (16'hFFFF - s_axis_tdata[15:0] + timestamp_i[15:0] +
                              16'b1);

  // latency calculation based on 16 bit timestamp extracted from fixed byte
  // position
  wire [15:0] latency_fixed16;
  assign latency_fixed16 = (timestamp_i[15:0] >= timestamp_fixed_pos16) ?
                              (timestamp_i[15:0] - timestamp_fixed_pos16)
                            : (16'hFFFF - timestamp_fixed_pos16 +
                              timestamp_i[15:0] + 16'b1);

  // latency calculation based on 24 bit timestamp extracted from fixed byte
  // position
  wire [23:0] latency_fixed24;
  assign latency_fixed24 = (timestamp_i >= timestamp_fixed_pos24) ?
                              (timestamp_i - timestamp_fixed_pos24)
                            : (24'hFFFFFF - timestamp_fixed_pos24 +
                              timestamp_i + 24'b1);

  reg [23:0] latency;
  reg        latency_valid;

  // process passes AXI4-Stream slave interface to AXI4-Stream master interface,
  // extracts timestamps and inserts latency value in TUSER
  always @(posedge clk156) begin
    if (~rstn156 | rst_sw156) begin
      m_axis_tdata <= 64'b0;
      m_axis_tkeep <= 8'b0;
      m_axis_tvalid <= 1'b0;
      m_axis_tlast <= 1'b0;
      m_axis_tuser <= 25'b0;
      ethertype <= 16'b0;
      latency <= 24'b0;
      latency_valid <= 1'b0;
      axis_word_cntr <= 8'b0;
    end else begin
      if (m_axis_tready) begin

        if (mode_i == MODE_HEADER) begin
          // 16 bit timestamps are located in the IPv4 checksum or IPv6
          // flowlabel fields

          // slave is ready to receive
          if (axis_word_cntr == 1) begin
            // this is the second AXI4-Stream word -> includes ethertype
            ethertype <= s_axis_tdata[47:32];
            m_axis_tuser <= 25'b0;
            latency <= 24'b0;
            latency_valid <= 1'b0;
          end else if (axis_word_cntr == 2) begin
            // this is the third AXI4-Stream word -> includes ipv6 flowlabel
            if (ethertype == 16'hdd86) begin
              if (s_axis_tlast) begin
                m_axis_tuser <= {1'b1, 8'b0, latency_header};
                latency <= 24'b0;
                latency_valid <= 1'b0;
              end else begin
                m_axis_tuser <= 25'b0;
                latency <= {8'b0, latency_header};
                latency_valid <= 1'b1;
              end
            end else begin
              if (s_axis_tlast) begin
                m_axis_tuser <= {latency_valid, latency};
                latency <= 24'b0;
                latency_valid <= 1'b0;
              end else begin
                m_axis_tuser <= 25'b0;
                latency <= latency;
                latency_valid <= latency_valid;
              end
            end
          end else if (axis_word_cntr == 3) begin
            // this is the fourth AXI4-Stream word -> includes ipv4 checksum
            if (ethertype == 16'h0008) begin
              if (s_axis_tlast) begin
                m_axis_tuser <= {1'b1, 8'b0, latency_header};
                latency <= 24'b0;
                latency_valid <= 1'b0;
              end else begin
                m_axis_tuser <= 25'b0;
                latency <= {8'b0, latency_header};
                latency_valid <= 1'b1;
              end
            end else begin
              if (s_axis_tlast) begin
                m_axis_tuser <= {latency_valid, latency};
                latency <= 24'b0;
                latency_valid <= 1'b0;
              end else begin
                m_axis_tuser <= 25'b0;
                latency <= latency;
                latency_valid <= latency_valid;
              end
            end
          end else begin
            if (s_axis_tlast) begin
              m_axis_tuser <= {latency_valid, latency};
              latency <= 24'b0;
              latency_valid <= 1'b0;
            end else begin
              m_axis_tuser <= 25'b0;
              latency <= latency;
              latency_valid <= latency_valid;
            end
          end
        end else if (mode_i == MODE_FIXED_POS) begin
          // timestamps are located at a fixed byte position

          if (axis_word_cntr == axis_word_select) begin
            // this is the axi stream word in which the timestamp is located

            // enough data to contain timestamp?
            if (timestamp_fixed_pos_valid) begin
              if (~width_i) begin
                // 16 bit timestamp
                if (s_axis_tlast) begin
                  m_axis_tuser <= {1'b1, 8'b0, latency_fixed16};
                  latency <= 24'b0;
                  latency_valid <= 1'b0;
                end else begin
                  m_axis_tuser <= 25'b0;
                  latency <= {8'b0, latency_fixed16};
                  latency_valid <= 1'b1;
                end
              end else begin
                // 24 bit timestamp
                if (s_axis_tlast) begin
                  m_axis_tuser <= {1'b1, latency_fixed24};
                  latency <= 24'b0;
                  latency_valid <= 1'b0;
                end else begin
                  m_axis_tuser <= 25'b0;
                  latency <= latency_fixed24;
                  latency_valid <= 1'b1;
                end
              end
            end else begin
              // timestamp not valid
              m_axis_tuser <= 25'b0;
              latency <= 24'b0;
              latency_valid <= 1'b0;
            end
          end else begin
            // this is not that axi stream data word that contains the
            // timestamp

            if (s_axis_tlast) begin
              m_axis_tuser <= {latency_valid, latency};
              latency <= 24'b0;
              latency_valid <= 1'b0;
            end else begin
              m_axis_tuser <= 25'b0;
              latency <= latency;
              latency_valid <= latency_valid;
            end
          end
        end else begin
          // timestamping is disabled, so there is nothing to extract
          m_axis_tuser <= 25'b0;
          latency <= 24'b0;
          latency_valid <= 1'b0;
        end

        // pass through data and control signals
        m_axis_tdata <= s_axis_tdata;
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
        m_axis_tdata <= m_axis_tdata;
        m_axis_tkeep <= m_axis_tkeep;
        m_axis_tvalid <= m_axis_tvalid;
        m_axis_tlast <= m_axis_tlast;
        m_axis_tuser <= m_axis_tuser;

        ethertype <= ethertype;

        latency <= latency;
        latency_valid <= latency_valid;

        axis_word_cntr <= axis_word_cntr;
      end
    end
  end

endmodule
