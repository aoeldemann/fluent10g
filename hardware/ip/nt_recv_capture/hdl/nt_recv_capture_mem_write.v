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
// This module transfers received packet and meta data from an input FIFO to
// a ring buffer located in DDR3 memory via an AXI4 master interface. The module
// starts operation when the 'active_i' signal is asserted. When the signal is
// deasserted, the module becomes inactive. During operation, the 'active_o'
// output signal is asserted. The input signals 'mem_addr_hi_i' and
// 'mem_addr_lo_i' specify the location of the ring buffer in memory. The
// input signal 'mem_range_i' specifies the size of the ring buffer (or rather
// the valid address range -> size - 1). The current ring buffer read pointer is
// provided by software via the 'addr_rd_i' input signal. The current ring
// buffer write pointer is provided to the software via the 'addr_wr_o' output
// signal.
//
// To optimize performance, data is written to the memory in bursts consisting
// of 256x 64 byte bursts. Thus, write transactions are only started if the
// input FIFO contains at least 16 kByte of data. However, since the total size
// of the data that must be transferred may not be a multiple of 16kByte, data
// may remain in the FIFO at the end of a measurement. After capturing is
// stopped (i.e. 'active_i' is set low and acknowledged by 'active_o' going
// low), the user may assert the 'flush_i' signal. If there are between 1 and
// 255 data words in the FIFO, this will initiate a final transfer of smaller
// burst size. The 'flush_i' input signal is expected to stay asserted for only
// a single clock cycle. While the flush is active, the output signal
// 'active_o' is high. Only one flush may be performed per measurement (i.e.
// 'active_i' must have been set high before performing the next flush).
//
// Size requirements:
//
//  - Ring buffer size must be > 16384 byte
//  - Ring buffer size must be a multiple of 16384 byte
//  - Ring buffer READ transfer size (determined by software) must be a multiple
//    of 16384 byte (except last transfer)

`timescale 1 ns / 1ps

module nt_recv_capture_mem_write (
  // clock and resets
  input wire           clk,
  input wire           rstn,
  input wire           rst_sw,

  // AXI master data interface to DDR memory
  output reg [32:0]   m_axi_awaddr,
  output reg [7:0]    m_axi_awlen,
  output reg [2:0]    m_axi_awsize,
  output reg [1:0]    m_axi_awburst,
  output reg          m_axi_awlock,
  output reg [3:0]    m_axi_awcache,
  output reg [2:0]    m_axi_awprot,
  output reg [3:0]    m_axi_awqos,
  output reg          m_axi_awvalid,
  input wire          m_axi_awready,
  output reg [511:0]  m_axi_wdata,
  output reg [63:0]   m_axi_wstrb,
  output reg          m_axi_wlast,
  output reg          m_axi_wvalid,
  input wire          m_axi_wready,
  output reg          m_axi_bready,
  input wire [1:0]    m_axi_bresp,
  input wire          m_axi_bvalid,
  output reg [32:0]   m_axi_araddr,
  output reg [7:0]    m_axi_arlen,
  output reg [2:0]    m_axi_arsize,
  output reg [1:0]    m_axi_arburst,
  output reg          m_axi_arlock,
  output reg [3:0]    m_axi_arcache,
  output reg [2:0]    m_axi_arprot,
  output reg [3:0]    m_axi_arqos,
  output reg          m_axi_arvalid,
  input wire          m_axi_arready,
  output reg          m_axi_rready,
  input wire [511:0]  m_axi_rdata,
  input wire [1:0]    m_axi_rresp,
  input wire          m_axi_rlast,
  input wire          m_axi_rvalid,

  // input FIFO signals
  input wire [511:0]  fifo_dout_i,
  input wire          fifo_empty_i,
  input wire          fifo_prog_empty_i,
  input wire [10:0]   fifo_rd_data_count_i,
  output reg          fifo_rd_en_o,

  // ring buffer address and size
  input wire [31:0]   mem_addr_hi_i,
  input wire [31:0]   mem_addr_lo_i,
  input wire [31:0]   mem_range_i,

  // ring buffer read and write pointers
  output reg [31:0]   addr_wr_o,
  input wire  [31:0]  addr_rd_i,

  // activation signals
  input wire          active_i,
  input wire          flush_i,

  // status signals
  output reg          active_o
);

  // assemble ring buffer memory address
  wire [32:0] mem_addr;
  assign mem_addr = (mem_addr_hi_i << 32) | mem_addr_lo_i;

  // calculate ring buffer memory size
  wire [32:0] mem_size;
  assign mem_size = mem_range_i + 1'b1;

  // FSM states
  parameter   RST             = 3'b000,
              INACTIVE        = 3'b001,
              START           = 3'b010,
              WAIT_RING_BUFF  = 3'b011,
              WAIT_FIFO       = 3'b100,
              WRITE_REQ       = 3'b101,
              WRITE           = 3'b110,
              WAIT_WRITE_RESP = 3'b111;

  reg [2:0]   state, nxt_state;
  reg [32:0]  nxt_m_axi_awaddr;
  reg         nxt_m_axi_awvalid;
  reg [7:0]   nxt_m_axi_awlen;
  reg         nxt_m_axi_wvalid;
  reg [7:0]   beats_cntr, nxt_beats_cntr;
  reg [31:0]  nxt_addr_wr;
  reg         flush, nxt_flush;

  // FSM
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      state <= RST;
    end else begin
      state <= nxt_state;
    end

    m_axi_awaddr <= nxt_m_axi_awaddr;
    m_axi_awlen <= nxt_m_axi_awlen;
    m_axi_awvalid <= nxt_m_axi_awvalid;
    m_axi_wvalid <= nxt_m_axi_wvalid;
    m_axi_wstrb <= 64'hFFFFFFFFFFFFFFFF; // always full 64 byte words
    m_axi_awsize <= 3'h6; // 64 bytes per beat
    m_axi_awburst <= 2'b01; // incrementing address burst
    m_axi_bready <= 1'b1; // always ready to receive responses
    m_axi_awlock <= 1'b0; // not used
    m_axi_awcache <= 4'b0011; // Xilinx recommend
    m_axi_awprot <= 3'b0; // not used
    m_axi_awqos <= 4'b0; // not used
    m_axi_araddr <= 33'b0; // no reads
    m_axi_arlen <= 8'b0; // no reads
    m_axi_arsize <= 3'b0; // no reads
    m_axi_arburst <= 2'b0; // no reads
    m_axi_arlock <= 1'b0; // no reads
    m_axi_arcache <= 4'b0; // no reads
    m_axi_arprot <= 3'b0; // no reads
    m_axi_arqos <= 4'b0; // no reads
    m_axi_arvalid <= 1'b0; // no reads
    m_axi_rready <= 1'b0; // no reads

    beats_cntr <= nxt_beats_cntr;
    addr_wr_o <= nxt_addr_wr;
    flush <= nxt_flush;
  end

  // FSM
  always @(*) begin
    nxt_state = state;
    nxt_m_axi_awaddr = m_axi_awaddr;
    nxt_m_axi_awlen = m_axi_awlen;
    nxt_m_axi_awvalid = 1'b0;
    nxt_m_axi_wvalid = 1'b0;
    nxt_beats_cntr = beats_cntr;
    nxt_addr_wr = addr_wr_o;
    nxt_flush = 1'b0;

    case (state)

      RST: begin
        // reset write address pointer
        nxt_addr_wr = 32'b0;

        // go to inactive state
        nxt_state = INACTIVE;
      end

      INACTIVE: begin
        if (flush_i) begin
          // flush has been triggered
          nxt_flush = 1'b1;
          nxt_state = WAIT_RING_BUFF;
        end else if (active_i) begin
          // module has been activated
          nxt_state = START;
        end
      end

      START: begin
        // initialize AXI4 write address to memory region start address
        nxt_m_axi_awaddr = mem_addr;

        // reset write pointer
        nxt_addr_wr = 32'b0;

        // go to state waiting for suffient ring buffer space to become
        // available
        nxt_state = WAIT_RING_BUFF;
      end

      WAIT_RING_BUFF: begin
        // in this state we wait for sufficient ring öbuffer space to become
        // available

        if (~active_i & ~flush) begin
          // module has been activated. go to idle state
          nxt_state = INACTIVE;
        end else begin
          if (addr_rd_i == addr_wr_o) begin
            // ring buffer is currently empty -> sufficient space!
            nxt_state = WAIT_FIFO;
          end else if (addr_rd_i < addr_wr_o) begin
            if (addr_rd_i != 0) begin
              // sufficient space!
              nxt_state = WAIT_FIFO;
            end else if ((addr_wr_o + 'h4000) != mem_size) begin
              // sufficient space!
              nxt_state = WAIT_FIFO;
            end
          end else if (addr_rd_i > addr_wr_o) begin
            if ((addr_rd_i - addr_wr_o) > 'h4000) begin
              // sufficient space!
              nxt_state = WAIT_FIFO;
            end
          end
        end

        // keep flush signal as it is
        nxt_flush = flush;
      end

      WAIT_FIFO: begin
        // to maximize axi throughput, we only write data from the FIFO to the
        // ring buffer in memory if we can fill an entire 256 beat burst.
        // However, since the incoming data may not be a multiple of 256x 512
        // bit, we perform one last write, which may have a shorter burst
        // length, when the 'flush' signal is asserted.

        // calculate burst size
        nxt_m_axi_awlen =
          ~fifo_prog_empty_i ? 8'hFF : (fifo_rd_data_count_i - 1);

        if (~active_i & ~flush) begin
          // module is inactive. return to INACTIVE state
          nxt_state = INACTIVE;
        end else if (active_i) begin
          // module is active. to maximize axi throughput, we only write data
          // from the FIFO to the ring buffer if we can fill an entire 256 beat
          // AXI burst (256x 64 byte = 16kByte). If there are more than 256 64
          // byte entries in the FIFO, the fifo_prog_empty_i input signal is
          // deasserted.
          if (~fifo_prog_empty_i) begin
            // at least 256 entries in the FIFO
            nxt_state = WRITE_REQ;
          end
        end else if (flush) begin
          if (fifo_prog_empty_i & ~fifo_empty_i) begin
            // there are less than 256 entries in the FIFO (but FIFO is not
            // empty
            nxt_state = WRITE_REQ;
          end else begin
            // nothing to be flushed, go back to inactive state
            nxt_state = INACTIVE;
          end
        end
      end

      WRITE_REQ: begin
        // in this state we issue the AXI4 write request and wait for it to be
        // acknowledged by the memory controller

        if (m_axi_awvalid & m_axi_awready) begin
          // write request has been recognized
          nxt_state = WRITE;

          // reset burst beat counter
          nxt_beats_cntr = 8'b0;
        end else begin
          // request still pending
          nxt_m_axi_awvalid = 1'b1;
        end
      end

      WRITE: begin
        // in this state the data is read from the FIFO and written to the
        // memory

        if (m_axi_wvalid & m_axi_wready) begin
          // data word has been transfered

          // increment beats counter
          nxt_beats_cntr = beats_cntr + 1;

          // increment write address
          if (m_axi_awaddr == (mem_addr + mem_size - 'h40)) begin
            // wrap around
            nxt_m_axi_awaddr = mem_addr;
          end else begin
            nxt_m_axi_awaddr = m_axi_awaddr + 'h40;
          end

          if (beats_cntr == m_axi_awlen) begin
            // all beats of the burst have been written
            nxt_state = WAIT_WRITE_RESP;
          end else begin
            // more beats to be written
            nxt_m_axi_wvalid = 1'b1;
          end
        end else begin
          // no data transfer active, keep wvalid high
          nxt_m_axi_wvalid = 1'b1;
        end
      end

      WAIT_WRITE_RESP: begin
        // wait for AXI4 write knowledgement. for now we don't do any error
        // checking here
        if (m_axi_bvalid) begin
          nxt_state = WAIT_RING_BUFF;

          // update write pointer
          if ((addr_wr_o + ((m_axi_awlen + 1) << 6)) == mem_size) begin
            nxt_addr_wr = 0;
          end else begin
            nxt_addr_wr = addr_wr_o + ((m_axi_awlen + 1) << 6);
          end
        end
      end

    endcase
  end

  // FIFO read enable and AXI4 WDATA + WLAST signals
  always @(*) begin
    fifo_rd_en_o = m_axi_wvalid & m_axi_wready;

    // reverse order of 64 bit words before writing data to memory
    m_axi_wdata = { fifo_dout_i[0+:64], fifo_dout_i[64+:64],
                    fifo_dout_i[128+:64], fifo_dout_i[192+:64],
                    fifo_dout_i[256+:64], fifo_dout_i[320+:64],
                    fifo_dout_i[384+:64], fifo_dout_i[448+:64]};

    // assert WLAST if burst beat counter reached burst size
    m_axi_wlast = (beats_cntr == m_axi_awlen);
  end

  // status output signals
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      active_o <= 1'b0;
    end else begin
      active_o <= (state != RST) & (state != INACTIVE);
    end
  end

endmodule
