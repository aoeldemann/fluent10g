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
// The module reads raw trace trace from an input FIFO, assembles packets
// and transmits the assembled packets via an AXI4-Stream master interface.
// For each packet, the module first reads 8 byte of meta information from the
// FIFO. The meta data includes:
//
// - Bits [31:0]:   Number of clock cycles that shall pass until next packet
//                  transmission
// - Bits [42:32]:  Packet's snap length
// - Bits [58:48]:  Packet's wire length
//
// The packet's snap length determines how many data words will be read from the
// input FIFO. Even though snap length may not be a multiple of 8 bytes, packet
// data in the FIFO is always aligned to 8 byte. If the snap length is smaller
// than the packet's wire length, the module appends (wire length - snap length)
// zero bytes to the packet data to restore the original size. Once all 8 byte
// packet data words have been consumed from the FIFO, the next FIFO data word
// again contains meta data and the process starts over. The timing information
// extracted from the meta data (i.e. inter-packet transmission times) are
// passed down the pipeline via the AXI4-Stream interface's TUSER signal. The
// TUSER signal is only valid when the first word of a packet is transmitted via
// the AXI4-Stream interface. At all other times it is zero.
//
// The module starts operation as soon as the 'ctrl_start_i' input signal is
// asserted. The input signal is expected to stay asserted for only a single
// clock cycle. As long as the module is active, the 'status_active_o' output
// signal is asserted. If an error occured while draining the FIFO, the
// 'status_err_fifo_drain_o' output signal is asserted and the module quits
// operation. In this case the module needs to be reset before operation can
// be restarted. The input signal 'status_mem_read_active_i' is expected to
// provide information on data is currently being read to the FIFO from the
// DRAM memory. It is required to determine when all packets have been and
// assembled.

`timescale 1 ns / 1ps

module nt_gen_replay_assemble
(
  // clock and resets
  input wire          clk,
  input wire          rstn,
  input wire          rst_sw,

  // meta and packet data input FIFO
  input wire [63:0]   fifo_dout_i,
  output wire         fifo_rd_en_o,
  input wire          fifo_empty_i,

  // AXI stream master interface
  output reg [63:0]   m_axis_tdata,
  output reg          m_axis_tvalid,
  output reg          m_axis_tlast,
  output reg [7:0]    m_axis_tkeep,
  output reg [31:0]   m_axis_tuser,
  input wire          m_axis_tready,

  // control and status signals
  input wire          ctrl_start_i,
  input wire          status_mem_read_active_i,
  output wire         status_active_o,
  output wire         status_err_fifo_drain_o
);

  parameter   IDLE            = 3'b000,
              START           = 3'b001,
              META            = 3'b010,
              DONE_FIFO_DRAIN = 3'b011,
              TX              = 3'b100,
              WAIT            = 3'b101,
              ERR_FIFO_DRAIN  = 3'b110;

  reg [2:0] state, nxt_state;

  // per-packet meta data
  reg [31:0] meta_delta_t, nxt_meta_delta_t;
  reg [10:0] meta_len_wire, nxt_meta_len_wire;
  reg [10:0] meta_len_snap, nxt_meta_len_snap;

  // error flag if fifo draining at the end of replay failed
  reg err_fifo_drain, nxt_err_fifo_drain;
  assign status_err_fifo_drain_o = err_fifo_drain;

  // per-packet AXI4-Stream word counter
  reg [7:0] m_axis_word_cntr;

  // determine whether enough 64 bit wide AXI4-Stream words have been
  // transferred to fit the snap data in
  wire tx_done_snap;
  assign tx_done_snap = ((m_axis_word_cntr) << 3) >= meta_len_snap;

  // determine whether enough 64 bit wide AXI4-Stream words have been
  // transferred to fit the entire packet wire data in
  wire tx_done_wire;
  assign tx_done_wire = ((m_axis_word_cntr + 1) << 3) >= meta_len_wire;

  // input FIFO read enable
  assign fifo_rd_en_o = (state == META) | (state == DONE_FIFO_DRAIN) |
    ((state == TX) & ~tx_done_snap & m_axis_tready);

  // data is being transmitted when we are in the TX state. If less than
  // snaplen bytes have been transferred, we must ensure that there is trace
  // data to read in the FIFO. if we are padding data with zero bytes we do
  // not need to read for data in the fifo to become ready.
  wire do_tx;
  assign do_tx =
    (state == TX) & (tx_done_snap | (~tx_done_snap & ~fifo_empty_i));

  // module is active whenever not in idle or error state
  assign status_active_o = (state != IDLE) & (state != ERR_FIFO_DRAIN);

  // control fsm
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      state <= IDLE;
    end else begin
      state <= nxt_state;
    end

    meta_delta_t <= nxt_meta_delta_t;
    meta_len_wire <= nxt_meta_len_wire;
    meta_len_snap <= nxt_meta_len_snap;

    err_fifo_drain <= nxt_err_fifo_drain;
  end

  always @(*) begin
    nxt_state = state;

    nxt_meta_delta_t = meta_delta_t;
    nxt_meta_len_wire = meta_len_wire;
    nxt_meta_len_snap = meta_len_snap;

    nxt_err_fifo_drain = 1'b0;

    case (state)

      IDLE: begin
        // leave idle state when module operation is started. ctrl_start_i is
        // expected to stay asserted for only a single clock cycle.
        if (ctrl_start_i) begin
          nxt_state = START;
        end
      end

      START: begin
        // we need to make sure that memory read module is active before we
        // start. thus, insert this dummy state here to delay start by one
        // cycle
        nxt_state = META;
      end

      META: begin
        if (fifo_empty_i & ~status_mem_read_active_i) begin
          // the input FIFO is empty and its not being filled with data from
          // the memory anymore. that means generation is done
          nxt_state = IDLE;
        end else if (~fifo_empty_i) begin
          if (fifo_dout_i == 64'hFFFFFFFFFFFFFFFF) begin
            // this meta word signals that the end of the trace has been
            // reached. we will drain the fifo and then stop operation
            nxt_state = DONE_FIFO_DRAIN;
          end else begin
            // FIFO output conatins meta data
            nxt_meta_delta_t = fifo_dout_i[31:0];
            nxt_meta_len_snap = fifo_dout_i[42:32];
            nxt_meta_len_wire = fifo_dout_i[58:48];

            // start packet transmission
            nxt_state = TX;
          end
        end
      end

      DONE_FIFO_DRAIN: begin
        if (status_mem_read_active_i) begin
          // we are now working under the assumption that we are done
          // replaying trace data. if the fifo is still being filled up with
          // data from memory, something went wrong!
          nxt_state = ERR_FIFO_DRAIN;
        end else begin
          if (fifo_empty_i) begin
            // draining complete!
            nxt_state = IDLE;
          end
        end
      end

      TX: begin
        if (tx_done_wire & m_axis_tready) begin
          // packet transmission done! start over for next packet
          nxt_state = META;
        end
      end

      ERR_FIFO_DRAIN: begin
        // flag error and do not leave this state until reset
        nxt_err_fifo_drain = 1'b1;
      end

    endcase
  end

  // process applies data to output AXI4-Stream master interface and counts
  // the number of transferred words
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      m_axis_tdata <= 64'b0;
      m_axis_tvalid <= 1'b0;
      m_axis_tlast <= 1'b0;
      m_axis_tkeep <= 8'b0;
      m_axis_tuser <= 32'b0;

      m_axis_word_cntr <= 8'b0;
    end else begin
      if (m_axis_tready) begin
        // slave is ready to receive data
        m_axis_tdata <= tx_done_snap ? 64'b0 : fifo_dout_i;
        m_axis_tvalid <= do_tx;
        m_axis_tlast <= do_tx & tx_done_wire;

        if (tx_done_wire) begin
          // last transaction for current packet, set strobe
          case (meta_len_wire[2:0] & 3'h7)
            3'h1: m_axis_tkeep <= 8'b00000001;
            3'h2: m_axis_tkeep <= 8'b00000011;
            3'h3: m_axis_tkeep <= 8'b00000111;
            3'h4: m_axis_tkeep <= 8'b00001111;
            3'h5: m_axis_tkeep <= 8'b00011111;
            3'h6: m_axis_tkeep <= 8'b00111111;
            3'h7: m_axis_tkeep <= 8'b01111111;
            3'h0: m_axis_tkeep <= 8'b11111111;
          endcase
        end else begin
          m_axis_tkeep <= 8'hFF;
        end

        // insert inter-packet transmission time in first TUSER word
        if (m_axis_word_cntr == 0) begin
          m_axis_tuser <= meta_delta_t;
        end else begin
          m_axis_tuser <= 32'b0;
        end

        if (do_tx) begin
          m_axis_word_cntr <= tx_done_wire ? 8'b0 : m_axis_word_cntr + 1;
        end else begin
          m_axis_word_cntr <= m_axis_word_cntr;
        end
      end else begin
        // slave not ready to receive data. keep output as it is.
        m_axis_tdata <= m_axis_tdata;
        m_axis_tvalid <= m_axis_tvalid;
        m_axis_tlast <= m_axis_tlast;
        m_axis_tkeep <= m_axis_tkeep;
        m_axis_tuser <= m_axis_tuser;

        m_axis_word_cntr <= m_axis_word_cntr;
      end
    end
  end

endmodule
