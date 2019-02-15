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
// Global control FSM.

`timescale 1 ns / 1ps

module nt_recv_capture_ctrl
(
  input wire clk,
  input wire rstn,
  input wire rst_sw,

  input wire ctrl_active_i,
  output reg status_active_o,

  output reg rx_active_o,
  input wire rx_active_i,

  output reg mem_write_active_o,
  input wire mem_write_active_i,
  output reg mem_write_flush_o,

  output reg mem_write_fifo_align_o,
  input wire mem_write_fifo_align_done_i,
  input wire mem_write_fifo_prog_empty_i,

  input wire fifo_meta_empty_i,
  input wire fifo_data_empty_i
);

  reg [3:0] state, nxt_state;

  localparam  IDLE                        = 4'b0000,
              ACTIVE                      = 4'b0001,
              RX_DISABLE                  = 4'b0010,
              MEM_WRITE_FIFO_ALIGN        = 4'b0011,
              WAIT_MEM_WRITE_FIFO_ALIGN   = 4'b0100,
              WAIT_MEM_WRITE_FIFO_EMPTY   = 4'b0101,
              MEM_WRITE_DISABLE           = 4'b0110,
              MEM_WRITE_FIFO_FLUSH        = 4'b0111,
              WAIT_MEM_WRITE_FIFO_FLUSH1  = 4'b1000,
              WAIT_MEM_WRITE_FIFO_FLUSH2  = 4'b1001;

  reg nxt_status_active_o;
  reg nxt_rx_active_o;
  reg nxt_mem_write_active_o;
  reg nxt_mem_write_flush_o;
  reg nxt_mem_write_fifo_align_o;

  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      state <= IDLE;
    end else begin
      state <= nxt_state;
    end

    status_active_o <= nxt_status_active_o;
    rx_active_o <= nxt_rx_active_o;
    mem_write_active_o <= nxt_mem_write_active_o;
    mem_write_flush_o <= nxt_mem_write_flush_o;
    mem_write_fifo_align_o <= nxt_mem_write_fifo_align_o;
  end

  always @(*) begin

    nxt_state = state;
    nxt_status_active_o = 1'b0;
    nxt_rx_active_o = 1'b0;
    nxt_mem_write_active_o = 1'b0;
    nxt_mem_write_flush_o = 1'b0;
    nxt_mem_write_fifo_align_o = 1'b0;

    case (state)

      IDLE: begin
        // in this state the module is non-operational
        if (ctrl_active_i) begin
          // start operation
          nxt_state = ACTIVE;
        end
      end

      ACTIVE: begin
        // in this state the module is operational
        if (~ctrl_active_i) begin
          // disable
          nxt_state = RX_DISABLE;
        end
        nxt_status_active_o = 1'b1;
        nxt_rx_active_o = 1'b1;
        nxt_mem_write_active_o = 1'b1;
      end

      RX_DISABLE: begin
        // in this state the rx module is being disabled
        if (~rx_active_i & fifo_meta_empty_i & fifo_data_empty_i) begin
          // rx module went inactive in the data it has written to the meta
          // and data fifos has been consumed
          nxt_state = MEM_WRITE_FIFO_ALIGN;
        end
        nxt_status_active_o = 1'b1;
        nxt_mem_write_active_o = 1'b1;
      end

      MEM_WRITE_FIFO_ALIGN: begin
        // we must align the data in the mem write fifo to 256 bits. trigger
        // alignment here
        nxt_state = WAIT_MEM_WRITE_FIFO_ALIGN;
        nxt_status_active_o = 1'b1;
        nxt_mem_write_active_o = 1'b1;
        nxt_mem_write_fifo_align_o = 1'b1;
      end

      WAIT_MEM_WRITE_FIFO_ALIGN: begin
        // in this state we wait for the alignment to complete
        if (mem_write_fifo_align_done_i) begin
          nxt_state = WAIT_MEM_WRITE_FIFO_EMPTY;
        end
        nxt_status_active_o = 1'b1;
        nxt_mem_write_active_o = 1'b1;
      end

      WAIT_MEM_WRITE_FIFO_EMPTY: begin
        // in this state we wait for the mem write fifo to become (almost)
        // empty
        if (mem_write_fifo_prog_empty_i) begin
          nxt_state = MEM_WRITE_DISABLE;
        end
        nxt_status_active_o = 1'b1;
        nxt_mem_write_active_o = 1'b1;
      end

      MEM_WRITE_DISABLE: begin
        // in this state we disable the mem write module
        if (~mem_write_active_i) begin
          nxt_state = MEM_WRITE_FIFO_FLUSH;
        end
        nxt_status_active_o = 1'b1;
      end

      MEM_WRITE_FIFO_FLUSH: begin
        // in this state the mem write fifo flush signal is asserted
        nxt_state = WAIT_MEM_WRITE_FIFO_FLUSH1;
        nxt_status_active_o = 1'b1;
        nxt_mem_write_flush_o = 1'b1;
      end

      WAIT_MEM_WRITE_FIFO_FLUSH1: begin
        // delay state. the mem write module needs one cycle to start the
        // flush
        nxt_state = WAIT_MEM_WRITE_FIFO_FLUSH2;
        nxt_status_active_o = 1'b1;
      end

      WAIT_MEM_WRITE_FIFO_FLUSH2: begin
        // in this state we wait for the mem write module to become inactive
        // again
        if (~mem_write_active_i) begin
          nxt_state = IDLE;
        end
        nxt_status_active_o = 1'b1;
      end

    endcase

  end

endmodule
