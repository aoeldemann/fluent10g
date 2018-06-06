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
// This module receives Ethernet frames via an AXI4-Stream slave interface.
// Besides the packet data, an optional 16/24 bit timestamp is received in bits
// [23:0] of the TUSER side-band signal. Bit 24 denotes whether the timestamp
// in bits [23:0] is valid. The 28 bit inter-packet arrival time is received
// in bits [52:25] of the TUSER side-band data. TUSER data is only valid for the
// last transfer of each packet (i.e. TLAST is high). At all other times it is
// zero.
//
// The module only operates while the 'active_i' input signal is high. While
// the module is active, the 'active_o' signal is asserted.
//
// For each incoming packet, up to 'max_len_capture_i' bytes of the packet data
// are written to a FIFO via the 'fifo_data_*' signals. Both the AXI4-Stream
// interface and the FIFO are 64 bits wide, so no width conversion is required.
// There are no strobe signals, so even if 'max_len_capture_i' is not a multiple
// of 64 bits, the full 64 bit of the last word may be written to the FIFO
// without data being masked off.
//
// For each incoming packet, the modules assembles a 75 bit data word containing
// packet meta data. It is created and written to a FIFO via the 'fifo_meta_*'
// signals after an entire packet has been received. It contains the following
// information:
//
//    Bits 23:0:  Packet latency in 6.4 ns clock cycles
//    Bit 24:24: Packet latency present/not present
//    Bits 52:25: Packet inter-arrival in 6.4 ns clock cycles
//    Bits 63:53: Wire length of the packet in bytes
//    Bits 74:64: Capture length of the packet in bytes
//
// The module counts the number of received packets and outputs the counter
// value via the 'pkt_cnt_o' signal. The counter is reset each time the module
// is (re-) activated.
//
// Whenever one of the FIFOs to be written becomes full, the error output signals
// 'err_meta_fifo_full_o' and/or 'err_data_fifo_full_o' are asserted. The module
// becomes inactive and the signals remain asserted until a reset is performed.

`timescale 1 ns / 1ps

module nt_recv_capture_rx
(
  // clock and resets
  input wire          clk,
  input wire          rstn,
  input wire          rst_sw,

  // AXI4-Stream slave interface
  input wire [63:0]   s_axis_tdata,
  input wire          s_axis_tvalid,
  input wire          s_axis_tlast,
  input wire [7:0]    s_axis_tkeep,
  input wire [52:0]   s_axis_tuser,
  output reg          s_axis_tready,

  // activation signals
  input wire          active_i,
  input wire [15:0]   max_len_capture_i,

  // fifo signals for meta-data fifo
  output reg [74:0]   fifo_meta_din_o,
  output reg          fifo_meta_wr_en_o,
  input wire          fifo_meta_full_i,

  // fifo signals for data fifo
  output reg [63:0]   fifo_data_din_o,
  output reg          fifo_data_wr_en_o,
  input wire          fifo_data_full_i,

  // module status output
  output reg          active_o,

  // packet counter output
  output reg [31:0]   pkt_cnt_o,

  // fifo full error output
  output reg          err_meta_fifo_full_o,
  output reg          err_data_fifo_full_o
);

  // module is always ready to receive new data!
  always @(posedge clk) s_axis_tready <= 1'b1;

  // register stores whether there is a packet transmission currently active
  // on the AXI4-Stream interface
  reg s_axis_active;

  // process determines whether there is currently a packet transmission active
  // on the AXI4-Stream interface
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      // initially no transmission active
      s_axis_active <= 1'b0;
    end else begin
      if (s_axis_tvalid & s_axis_tready) begin
        // transmission of packet done when tlast signal is asserted
        s_axis_active <= ~s_axis_tlast;
      end else begin
        // no data word is transfered in this cycle
        s_axis_active <= s_axis_active;
      end
    end
  end

  // calculate number of bytes that are valid in the current AXI4-Stream word
  reg [3:0] s_axis_tdata_len;

  integer idx;
  always @(*) begin
    if (~s_axis_tlast) begin
      // not the last word -> all 8 bytes valid
      s_axis_tdata_len = 8;
    end else begin
      // last word -> number of 1s in TKEEP signal determines number of valid
      // bytes
      s_axis_tdata_len = 4'b0;
      for (idx = 0; idx < 8; idx = idx + 1) begin
        s_axis_tdata_len = s_axis_tdata_len + s_axis_tkeep[idx];
      end
    end
  end

  // states of FSM writing data
  parameter FSM_DATA_RST    = 3'b000,
            FSM_DATA_IDLE   = 3'b001,
            FSM_DATA_START  = 3'b010,
            FSM_DATA_RECORD = 3'b011,
            FSM_DATA_ERR    = 3'b100;

  reg [2:0]   state_fsm_data, nxt_state_fsm_data;
  reg         meta_wr, nxt_meta_wr;
  reg [23:0]  meta_latency, nxt_meta_latency;
  reg         meta_latency_valid, nxt_meta_latency_valid;
  reg [27:0]  meta_interpackettime, nxt_meta_interpackettime;
  reg [10:0]  meta_len_capture, nxt_meta_len_capture;
  reg [10:0]  meta_len_wire, nxt_meta_len_wire;
  reg [10:0]  len_capture, nxt_len_capture;
  reg [10:0]  len_wire, nxt_len_wire;
  reg         nxt_fifo_data_wr_en;
  reg [31:0]  nxt_pkt_cnt;

  // FSM writing packet data to FIFO
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      state_fsm_data <= FSM_DATA_RST;
    end else begin
      state_fsm_data <= nxt_state_fsm_data;
    end

    meta_wr <= nxt_meta_wr;
    meta_latency <= nxt_meta_latency;
    meta_latency_valid <= nxt_meta_latency_valid;
    meta_interpackettime <= nxt_meta_interpackettime;
    meta_len_capture <= nxt_meta_len_capture;
    meta_len_wire <= nxt_meta_len_wire;
    len_capture <= nxt_len_capture;
    len_wire <= nxt_len_wire;
    fifo_data_wr_en_o <= nxt_fifo_data_wr_en;
    fifo_data_din_o <= s_axis_tdata;
    pkt_cnt_o <= nxt_pkt_cnt;
  end

  // FSM writing packet data to FIFO
  always @(*) begin
    nxt_state_fsm_data = state_fsm_data;
    nxt_meta_wr = 1'b0;
    nxt_meta_latency = meta_latency;
    nxt_meta_latency_valid = meta_latency_valid;
    nxt_meta_interpackettime = meta_interpackettime;
    nxt_meta_len_capture = meta_len_capture;
    nxt_meta_len_wire = meta_len_wire;
    nxt_len_capture = len_capture;
    nxt_len_wire = len_wire;
    nxt_fifo_data_wr_en = 1'b0;
    nxt_pkt_cnt = pkt_cnt_o;

    case (state_fsm_data)

      FSM_DATA_RST: begin
        // reset packet counter
        nxt_pkt_cnt = 32'b0;

        // go to idle state
        nxt_state_fsm_data = FSM_DATA_IDLE;
      end

      FSM_DATA_IDLE: begin
        if (active_i) begin
          // module has been activated
          nxt_state_fsm_data = FSM_DATA_START;
        end
      end

      FSM_DATA_START: begin
        // reset per-packet length counters
        nxt_len_capture = 11'b0;
        nxt_len_wire = 11'b0;

        // reset packet counter
        nxt_pkt_cnt = 32'b0;

        // to prevent incomplete packet data to bet written to the FIFO, wait
        // in this state until there is no packet transmission active on the
        // axi stream slave interface anymore.
        if (~s_axis_active) begin
          nxt_state_fsm_data = FSM_DATA_RECORD;
        end
      end

      FSM_DATA_RECORD: begin
        if (~active_i & ~s_axis_active) begin
          // module is being deactivated and there is currently no packet
          // transmission active anymore -> go back to idle state
          nxt_state_fsm_data = FSM_DATA_IDLE;
        end else begin
          if (s_axis_tvalid & s_axis_tready) begin
            // AXI4-Stream word is being transfered

            if (len_capture < max_len_capture_i) begin
              // maximum capture length not reached yet -> store data
              nxt_fifo_data_wr_en = 1'b1;

              if (fifo_data_full_i) begin
                // FIFO is full -> go to error state_fsm_data
                nxt_state_fsm_data = FSM_DATA_ERR;
              end
            end

            if (s_axis_tlast) begin
              // this is the last word -> trigger writing of meta data
              nxt_meta_wr = 1'b1;

              // set meta data
              nxt_meta_latency = s_axis_tuser[23:0];
              nxt_meta_latency_valid = s_axis_tuser[24:24];
              nxt_meta_interpackettime = s_axis_tuser[52:25];
              if ((len_capture + s_axis_tdata_len) > max_len_capture_i) begin
                nxt_meta_len_capture = max_len_capture_i;
              end else begin
                nxt_meta_len_capture = len_capture + s_axis_tdata_len;
              end
              nxt_meta_len_wire = len_wire + s_axis_tdata_len;

              // increment packet counter
              nxt_pkt_cnt = pkt_cnt_o + 1;

              // reset packet length counters
              nxt_len_capture = 11'b0;
              nxt_len_wire = 11'b0;
            end else begin
              // not the last word yet, increment counters
              if ((len_capture + s_axis_tdata_len) > max_len_capture_i) begin
                nxt_len_capture = max_len_capture_i;
              end else begin
                nxt_len_capture = len_capture + s_axis_tdata_len;
              end
              nxt_len_wire = len_wire + s_axis_tdata_len;
            end
          end
        end
      end

      FSM_DATA_ERR: begin
        // stuck here until reset
      end

    endcase
  end

  // states of FSM writing meta info
  parameter FSM_META_ACTIVE = 1'b0,
            FSM_META_ERR    = 1'b1;

  reg         state_fsm_meta, nxt_state_fsm_meta;
  reg         nxt_fifo_meta_wr_en;
  reg [74:0]  nxt_fifo_meta_din;

  // FSM writing meta data to FIFO
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      state_fsm_meta <= FSM_META_ACTIVE;
    end else begin
      state_fsm_meta <= nxt_state_fsm_meta;
    end

    fifo_meta_wr_en_o <= nxt_fifo_meta_wr_en;
    fifo_meta_din_o <= nxt_fifo_meta_din;
  end

  // FSM writing meta data to FIFO
  always @(*) begin
    nxt_state_fsm_meta = state_fsm_meta;
    nxt_fifo_meta_wr_en = 1'b0;
    nxt_fifo_meta_din = fifo_meta_din_o;

    case (state_fsm_meta)

      FSM_META_ACTIVE: begin
        if (meta_wr) begin
          // assmeble meta data and write to FIFO
          nxt_fifo_meta_wr_en = 1'b1;
          nxt_fifo_meta_din[23:0] = meta_latency;
          nxt_fifo_meta_din[24:24] = meta_latency_valid;
          nxt_fifo_meta_din[52:25] = meta_interpackettime;
          nxt_fifo_meta_din[63:53] = meta_len_wire;
          nxt_fifo_meta_din[74:64] = meta_len_capture;

          if (fifo_meta_full_i) begin
            // fifo is full -> go to error state
            nxt_state_fsm_meta = FSM_META_ERR;
          end
        end
      end

      FSM_META_ERR: begin
        // stuck here until reset
      end

    endcase
  end

  // process sets status and error output signals
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      active_o <= 1'b0;
      err_meta_fifo_full_o <= 1'b0;
      err_data_fifo_full_o <= 1'b0;
    end else begin
      active_o <= (state_fsm_data == FSM_DATA_RECORD);
      err_data_fifo_full_o <= (state_fsm_data == FSM_DATA_ERR);
      err_meta_fifo_full_o <= (state_fsm_meta == FSM_META_ERR);
    end
  end

endmodule
