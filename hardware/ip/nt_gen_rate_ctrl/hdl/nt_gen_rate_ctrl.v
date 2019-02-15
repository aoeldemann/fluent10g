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
// The module receives Ethernet frames via an AXI4-Stream slave interface and
// outputs them on an AXI4-Stream master interface without (data) modifications.
// For each frame, the number of clock cycles that shall pass until the next
// packet shall be transmitted is provided via the TUSER side-band signal of
// the AXI4-Stream slave interface. The TUSER signal value is only valid when
// the first data word of each word is transferred. The module controls the
// output rate on the AXI4-Stream master interface such that the inter-packet
// transmission time information provided in the TUSER signal are enforced.
// The module only operates when the input signal 'ctrl_active_i' is asserted.
// If the input signal is deasserted, the AXI4-Stream slave interface's TREADY
// signal stays low. If the inter-packet transmission times provided in the
// TUSER data cannot be enforced (either because a backlog was signaled via the
// AXI4-Stream master interface's TREADY signal or because data is not provided
// fast enough on the AXI4-Stream slave interface), the 'status_warn_timing_o'
// is asserted and stays asserted until the module is reset. However, operation
// still continues.

`timescale 1 ns / 1ps

module nt_gen_rate_ctrl (
  // clock and reset
  input wire          clk,
  input wire          rstn,
  input wire          rst_sw,

  // AXI4-Stream slave interface
  input wire [63:0]   s_axis_tdata,
  input wire          s_axis_tvalid,
  input wire          s_axis_tlast,
  input wire [7:0]    s_axis_tkeep,
  input wire [31:0]   s_axis_tuser,
  output wire         s_axis_tready,

  // AXI4-Stream master interface
  output wire [63:0]  m_axis_tdata,
  output wire         m_axis_tvalid,
  output wire         m_axis_tlast,
  output wire [7:0]   m_axis_tkeep,
  input wire          m_axis_tready,

  // activation control signal
  input wire          ctrl_active_i,

  // output status warning signal
  output wire         status_warn_timing_o
);

  localparam  RST           = 3'b000,
              IDLE          = 3'b001,
              TX_START      = 3'b010,
              TX            = 3'b011,
              WAIT          = 3'b100;

  reg [2:0] state, nxt_state;

  // inter-packet time extracted from axi stream tuser information
  reg [31:0] n_cycles_interpacket, nxt_n_cycles_interpacket;

  // counting the clock cycles since the transfer of the first word of the
  // current axi transaction
  reg [63:0] cntr_cycles_interpacket, nxt_cntr_cycles_interpacket;

  // warning flags that are asserted when the module cannot maintain the
  // timing that is requested
  reg warn_timing, nxt_warn_timing;
  assign status_warn_timing_o = warn_timing;

  // determins whether data shall be transferred from slave to master
  // interface
  reg do_transfer, nxt_do_transfer;

  assign m_axis_tdata = s_axis_tdata;
  assign m_axis_tlast = s_axis_tlast;
  assign m_axis_tkeep = s_axis_tkeep;
  assign m_axis_tvalid = s_axis_tvalid & do_transfer;
  assign s_axis_tready = m_axis_tready & do_transfer;

  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      state <= RST;
    end else begin
      state <= nxt_state;
    end

    n_cycles_interpacket <= nxt_n_cycles_interpacket;
    cntr_cycles_interpacket <= nxt_cntr_cycles_interpacket;
    warn_timing <= nxt_warn_timing;
    do_transfer <= nxt_do_transfer;
  end

  always @(*) begin
    nxt_state = state;
    nxt_n_cycles_interpacket = n_cycles_interpacket;
    nxt_cntr_cycles_interpacket = cntr_cycles_interpacket + 1;
    nxt_warn_timing = warn_timing;
    nxt_do_transfer = 1'b0;

    case (state)

      RST: begin
        // reset warnings and go to idle state
        nxt_warn_timing = 1'b0;
        nxt_state = IDLE;
      end

      IDLE: begin
        if (ctrl_active_i) begin
          // module has been activated, start transmission of first packet in
          // the next cycle
          nxt_state = TX_START;
          nxt_n_cycles_interpacket = 1; // next cycle
          nxt_cntr_cycles_interpacket = 1;
          nxt_do_transfer = 1'b1;
        end
      end

      TX_START: begin
        if (~ctrl_active_i) begin
          // go back to idle
          nxt_state = IDLE;
        end if (s_axis_tvalid) begin
          if (cntr_cycles_interpacket > n_cycles_interpacket) begin
            // was not able to send data in time, flag a warning
            nxt_warn_timing = 1'b1;
          end

          if (s_axis_tready) begin
            // transfer next word
            nxt_state = TX;
            nxt_n_cycles_interpacket = s_axis_tuser;
            nxt_cntr_cycles_interpacket = 1;
          end
        end

        nxt_do_transfer = 1'b1;
      end

      TX: begin
        if (s_axis_tvalid & s_axis_tready & s_axis_tlast) begin
          // the entire frame has been transmitted
          if (~ctrl_active_i) begin
            // module has been deactivated -> go to idle state
            nxt_state = IDLE;
          end if (cntr_cycles_interpacket >= (n_cycles_interpacket - 1)) begin
            // we are transmitting packets back-to-back
            nxt_state = TX_START;
            nxt_do_transfer = 1'b1;
          end else begin
            // we need to wait some time before transmitting the next packet
            nxt_state = WAIT;
          end
        end else begin
          // the frame has not been completely transferred yet -> keep
          // transfering!
          nxt_do_transfer = 1'b1;
        end
      end

      WAIT: begin
        if (~ctrl_active_i) begin
          // module has been deactivated -> go to idle state
          nxt_state = IDLE;
        end if (cntr_cycles_interpacket == (n_cycles_interpacket - 1)) begin
          // waited enough! -> send next frame
          nxt_state = TX_START;
          nxt_do_transfer = 1'b1;
        end
      end

    endcase
  end

endmodule
