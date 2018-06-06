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
// While the RX AXI4-Stream datapath is 64 bit wide, data is transferred to
// memory in words of 512 bits. Upsizing is performed by a FIFO with a
// non-symmetric aspect ratio. Data becomes valid at the FIFO output when
// excactly 8x 64 bit data words have been written to the FIFO. If the size of
// the input data is not a multiple of 512 bit, we need to add padding such that
// all input data is actually output by the FIFO. This FIFO wrapper writes this
// padding data to the FIFO when requested.
//
// The module continously writes the 64 bit input data to the FIFO. As soon as
// the input signal 'align_i' becomes high, the module inserts 64 bit padding
// data words if necessary. All bits of the padding data are set to 1. As soon
// as the process is completed, the output signal 'align_done_o' is asserted
// for a single clock cycle.

`timescale 1 ns / 1ps

module nt_recv_capture_mem_write_fifo_wrapper
(
  // clock and resets
  input wire          clk,
  input wire          rstn,
  input wire          rst_sw,

  // FIFO input
  input wire [63:0]   din_i,
  input wire          wr_en_i,
  output wire         full_o,

  // FIFO output
  output wire [511:0] dout_o,
  input wire          rd_en_i,
  output wire         empty_o,
  output wire         prog_empty_o,
  output wire [10:0]  rd_data_count_o,

  // start & status signals
  input wire align_i,
  output wire align_done_o
);

  // FSM states
  localparam  RST           = 2'b00,
              PASS_THROUGH  = 2'b01,
              ALIGN         = 2'b10;

  reg [1:0] state, nxt_state;

  // number of 64 bit words that have been written to the FIFO (modulo 8)
  reg [2:0] fifo_wr_word_cntr, nxt_fifo_wr_word_cntr;

  // output status
  reg align_done, nxt_align_done;
  assign align_done_o = align_done;

  // FIFO input data
  wire [63:0] fifo_din;

  // if in PASS_THROUGH state, write input data to the FIFO. Otherwise write
  // padding data, where all bits are set to 1.
  assign fifo_din = state == PASS_THROUGH ? din_i : 64'hFFFFFFFFFFFFFFFF;

  // FIFO write enable signal. If in PASS_THROUGH state, write input data to the
  // FIFO whenever it becomes available. If in ALIGN state, only write padding
  // data to the FIFO if 512 bit alignment has not been reached yet
  wire fifo_wr_en;
  assign fifo_wr_en = state == PASS_THROUGH ? wr_en_i :
    (state == ALIGN) & (fifo_wr_word_cntr != 0);

  // FSM
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      state <= RST;
    end else begin
      state <= nxt_state;
    end

    fifo_wr_word_cntr <= nxt_fifo_wr_word_cntr;
    align_done <= nxt_align_done;
  end

  // FSM
  always @(*) begin

    nxt_state = state;
    nxt_fifo_wr_word_cntr = fifo_wr_word_cntr;
    nxt_align_done = 1'b0;

    case (state)

      RST: begin
        // initially we go to the PASS_THROUGH state. no data has been written
        // yet.
        nxt_state = PASS_THROUGH;
        nxt_fifo_wr_word_cntr = 3'b0;
      end

      PASS_THROUGH: begin
        // in this state input data is written to the FIFO.
        if (align_i) begin
          // alignment triggered
          nxt_state = ALIGN;
        end

        if (wr_en_i) begin
          // data is being written. increment the FIFO write word counter.
          // Wrap around if 8x 64 bit words have been written
          nxt_fifo_wr_word_cntr
            = (fifo_wr_word_cntr == 7) ? 3'b0 : fifo_wr_word_cntr + 3'b1;
        end
      end

      ALIGN: begin
        // in this state padding data is written to the FIFO if necessary
        if (fifo_wr_word_cntr == 0) begin
          // 512 bit alignment has been reached -> we are done
          nxt_state = PASS_THROUGH;
          nxt_align_done = 1'b1;
        end else begin
          //increment the FIFO write word counter. Wrap around if 8x 64 bit
          // words have been written
          nxt_fifo_wr_word_cntr
            = (fifo_wr_word_cntr == 7) ? 3'b0 : fifo_wr_word_cntr + 3'b1;
        end
      end

    endcase
  end

  // FIFO instance
  nt_recv_capture_mem_write_fifo nt_recv_capture_mem_write_fifo_inst (
    .clk(clk),
    .srst(~rstn | rst_sw),
    .din(fifo_din),
    .wr_en(fifo_wr_en),
    .rd_en(rd_en_i),
    .dout(dout_o),
    .full(full_o),
    .empty(empty_o),
    .rd_data_count(rd_data_count_o),
    .prog_empty(prog_empty_o)
  );

endmodule
