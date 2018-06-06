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
// This module continously fetches trace data from a ring buffer in memory via
// an AXI4 master interface and then stores it into a FIFO via its output
// signals. The module starts operation when the input signal 'ctrl_start_i'
// becomes high (the signal is expected to stay high for only a single clock
// cycle). The input signals 'ctrl_mem_addr_hi_i' and 'ctrl_mem_addr_lo_i'
// specify the location of the ring buffer in the memory. The input signal
// 'ctrl_mem_range_i' specifies the size of the ring buffer (or rather the
// valid address range -> size - 1). Furthermore, the input signals
// 'ctrl_trace_size_hi_i' and 'ctrl_trace_size_lo_i' specifiy the total amount
// of trace data that shall be read from the ring buffer. The current ring
// buffer write pointer is provided by software via the 'ctrl_addr_wr_i' input
// signal. The current ring buffer read pointer is provided to the software via
// the 'ctrl_addr_rd_o' output signal. When the entire trace data has been read
// and stored in the FIFO, the module becomes inactive and can be retriggered by
// setting the input signal 'ctrl_start_i' high again. Whenever the module is
// active (i.e. reading data from the memory), the output signal
// 'status_active_o' is asserted.
//
// The ring buffer read and write pointers are offsets, which are added to the
// ring buffer memory base address 'ctrl_mem_addr_(hi/lo)_i'. While the maximum
// trace size is almost unlimited (it still may not exceed 2^64 byte), the size
// of the ring buffer may currently not exceed 4 GByte.
//
// Data is read from the memory in bursts. Each burst contains a maximum of 256
// beats. Each beat always contains 512 bits of data. A read transaction is only
// started when a complete burst of 256 beats can fit into the FIFO. The input
// signal 'fifo_prog_full_i' becomes high when no complete burst fits into the
// FIFO. The module then waits until 'fifo_prog_full_i' becomes low and then
// starts a new burst. If the data that can possibly be read from the ring
// buffer becomes smaller than 256x 512 bit (due to the fact that almost
// all trace data has been read), the number of beats is decreased appropiately.
// Ring buffer address and size must be algigned to 512 bit boundaries! There is
// currently no error checking to validate this.

`timescale 1 ns / 1ps

module nt_gen_replay_mem_read (
  // clock and reset
  input wire         clk,
  input wire         rstn,
  input wire         rst_sw,

  // AXI4 master interface
  output reg [32:0]  m_axi_awaddr,
  output reg [7:0]   m_axi_awlen,
  output reg [2:0]   m_axi_awsize,
  output reg [1:0]   m_axi_awburst,
  output reg         m_axi_awlock,
  output reg [3:0]   m_axi_awcache,
  output reg [2:0]   m_axi_awprot,
  output reg [3:0]   m_axi_awqos,
  output reg         m_axi_awvalid,
  input wire         m_axi_awready,
  output reg [511:0] m_axi_wdata,
  output reg [63:0]  m_axi_wstrb,
  output reg         m_axi_wlast,
  output reg         m_axi_wvalid,
  input wire         m_axi_wready,
  output reg         m_axi_bready,
  input wire [1:0]   m_axi_bresp,
  input wire         m_axi_bvalid,
  output reg [32:0]  m_axi_araddr,
  output reg [7:0]   m_axi_arlen,
  output reg [2:0]   m_axi_arsize,
  output reg [1:0]   m_axi_arburst,
  output reg         m_axi_arlock,
  output reg [3:0]   m_axi_arcache,
  output reg [2:0]   m_axi_arprot,
  output reg [3:0]   m_axi_arqos,
  output reg         m_axi_arvalid,
  input wire         m_axi_arready,
  output reg         m_axi_rready,
  input wire [511:0] m_axi_rdata,
  input wire [1:0]   m_axi_rresp,
  input wire         m_axi_rlast,
  input wire         m_axi_rvalid,

  // output FIFO signals
  output reg [511:0] fifo_din_o,
  output reg         fifo_wr_en_o,
  input wire         fifo_prog_full_i,

  // trace memory (ring buffer) address and size
  input wire [31:0]  ctrl_mem_addr_hi_i,
  input wire [31:0]  ctrl_mem_addr_lo_i,
  input wire [31:0]  ctrl_mem_range_i,

  // trace data size
  input wire [31:0]  ctrl_trace_size_hi_i,
  input wire [31:0]  ctrl_trace_size_lo_i,

  // ring buffer read and write pointers
  input wire [31:0]  ctrl_addr_wr_i,
  output reg [31:0]  ctrl_addr_rd_o,

  // start trigger
  input wire         ctrl_start_i,

  // active status
  output reg         status_active_o
);

  wire [32:0] ctrl_mem_addr;
  assign ctrl_mem_addr = (ctrl_mem_addr_hi_i << 32) | ctrl_mem_addr_lo_i;

  wire [32:0] ctrl_mem_size;
  assign ctrl_mem_size = ctrl_mem_range_i + 1'b1;

  wire [63:0] ctrl_trace_size;
  assign ctrl_trace_size = (ctrl_trace_size_hi_i << 32) | ctrl_trace_size_lo_i;

  // FSM states
  parameter IDLE = 2'b00,
            WAIT = 2'b01,
            REQ  = 2'b10,
            READ = 2'b11;

  reg [1:0]   state, nxt_state;
  reg [32:0]  nxt_m_axi_araddr;
  reg [7:0]   nxt_m_axi_arlen;
  reg         nxt_m_axi_arvalid;
  reg [63:0]  read_byte_cntr, nxt_read_byte_cntr;
  reg [31:0]  nxt_ctrl_addr_rd;

  // FSM
  always @(posedge clk) begin
    if (~rstn | rst_sw) begin
      state <= IDLE;
    end else begin
      state <= nxt_state;
    end

    // we don't do writes!
    m_axi_awaddr <= 33'b0;
    m_axi_awlen <= 8'b0;
    m_axi_awsize <= 3'b0;
    m_axi_awburst <= 2'b0;
    m_axi_awlock <= 1'b0;
    m_axi_awcache <= 4'b0011;
    m_axi_awprot <= 3'b0;
    m_axi_awqos <= 4'b0;
    m_axi_awvalid <= 1'b0;
    m_axi_wdata <= 512'b0;
    m_axi_wstrb <= 64'b0;
    m_axi_wlast <= 1'b0;
    m_axi_wvalid <= 1'b0;
    m_axi_bready <= 1'b0;

    // fixed read signals
    m_axi_arsize <= 4'h6; // 64 bytes per burst beat
    m_axi_arburst <= 2'b01; // incrementing address burst
    m_axi_arlock <= 1'b0;
    m_axi_arcache <= 4'b0011; // Xilinx recommend
    m_axi_arprot <= 3'b0;
    m_axi_arqos <= 4'b0;

    // always gladly accepting data! we only issue read requests when space in
    // FIFO to store entire burst is available
    m_axi_rready <= 1'b1;

    m_axi_araddr <= nxt_m_axi_araddr;
    m_axi_arlen <= nxt_m_axi_arlen;
    m_axi_arvalid <= nxt_m_axi_arvalid;
    fifo_wr_en_o <= m_axi_rvalid;
    read_byte_cntr <= nxt_read_byte_cntr;
    ctrl_addr_rd_o <= nxt_ctrl_addr_rd;
    status_active_o <= (state != IDLE);

    // reverse order of 64 bit words before writing data to fifo
    fifo_din_o <= { m_axi_rdata[0+:64], m_axi_rdata[64+:64],
                    m_axi_rdata[128+:64], m_axi_rdata[192+:64],
                    m_axi_rdata[256+:64], m_axi_rdata[320+:64],
                    m_axi_rdata[384+:64], m_axi_rdata[448+:64]};
  end

  always @(*) begin
    nxt_state = state;
    nxt_m_axi_araddr = m_axi_araddr;
    nxt_m_axi_arlen = m_axi_arlen;
    nxt_m_axi_arvalid = 1'b0;
    nxt_read_byte_cntr = read_byte_cntr;
    nxt_ctrl_addr_rd = ctrl_addr_rd_o;

    case (state)

      IDLE: begin
        if (ctrl_start_i) begin
          // start signal triggered -> go to next state
          nxt_state = WAIT;
        end

        // init axi read address to memory region start address
        nxt_m_axi_araddr = ctrl_mem_addr;
        nxt_read_byte_cntr = 64'b0; // reset read byte counter
        nxt_ctrl_addr_rd = 32'b0; // reset read pointer
      end

      WAIT: begin
        if (fifo_prog_full_i) begin
          // output FIFO is currently full -> wait in this state
        end else if (ctrl_addr_rd_o == ctrl_addr_wr_i) begin
          // no data available to be read -> wait in this state
        end else begin
          if ((ctrl_mem_size - ctrl_addr_rd_o) >= 'h4000) begin
            // bytes until end of memory region can fill an entire 256x 64
            // byte burst
            if ((ctrl_trace_size - read_byte_cntr) >= 'h4000) begin
              // bytes that still remain to be read can fill an entire 256x 64
              // byte burst
              if (ctrl_addr_wr_i > ctrl_addr_rd_o) begin
                if ((ctrl_addr_wr_i - ctrl_addr_rd_o) >= 'h4000) begin
                  // enough data available in memory to fill an entire burst ->
                  // start reading
                  nxt_state = REQ;
                  nxt_m_axi_arlen = 8'hFF;
                  nxt_m_axi_arvalid = 1'b1;
                end
              end else begin
                // since write pointer is smaller than read pointer, we can be
                // sure that enough data is available in memory to fill an
                // entire burst -> start reading
                nxt_state = REQ;
                nxt_m_axi_arlen = 8'hFF;
                nxt_m_axi_arvalid = 1'b1;
              end
            end else begin
              // bytes that remain to be read do NOT fill an entire 256x 64
              // byte burst
              if (ctrl_addr_wr_i > ctrl_addr_rd_o) begin
                if ((ctrl_addr_wr_i - ctrl_addr_rd_o) ==
                    (ctrl_trace_size - read_byte_cntr)) begin
                  // all data remaning to be sent is avaiable in memory ->
                  // start reading it
                  nxt_state = REQ;
                  nxt_m_axi_arlen
                    = ((ctrl_trace_size - read_byte_cntr) >> 6) - 1'b1;
                  nxt_m_axi_arvalid = 1'b1;
                end
              end
            end
          end else begin
            // bytes until end of memory region can NOT fill an entire 256x 64
            // byte burst
            if ((ctrl_trace_size - read_byte_cntr) >=
                (ctrl_mem_size - ctrl_addr_rd_o)) begin
              // all bytes until end of memory region still need to be read
              if (ctrl_addr_wr_i > ctrl_addr_rd_o) begin
                if (ctrl_addr_wr_i == ctrl_mem_size) begin
                  nxt_state = REQ;
                  nxt_m_axi_arlen
                    = ((ctrl_mem_size - ctrl_addr_rd_o) >> 6) - 1'b1;
                  nxt_m_axi_arvalid = 1'b1;
                end
              end else begin
                nxt_state = REQ;
                nxt_m_axi_arlen
                  = ((ctrl_mem_size - ctrl_addr_rd_o) >> 6) - 1'b1;
                nxt_m_axi_arvalid = 1'b1;
              end
            end else begin
              // NOT all bytes until end of memory region need to be read
              // anymore
              if (ctrl_addr_wr_i > ctrl_addr_rd_o) begin
                if ((ctrl_addr_wr_i - ctrl_addr_rd_o) ==
                    (ctrl_trace_size - read_byte_cntr)) begin
                  nxt_state = REQ;
                  nxt_m_axi_arlen
                    = ((ctrl_trace_size - read_byte_cntr) >> 6) - 1'b1;
                  nxt_m_axi_arvalid = 1'b1;
                end
              end
            end
          end
        end
      end

      REQ: begin
        if (m_axi_arvalid & m_axi_arready) begin
          // read request has been recongnized by the slave
          nxt_state = READ;
        end else begin
          // read request still pending, leave arvalid high
          nxt_m_axi_arvalid = 1'b1;
        end
      end

      READ: begin
        if (m_axi_rvalid) begin
          // received a 64 byte data word
          nxt_read_byte_cntr = read_byte_cntr + 'h40;

          // increment read pointer
          if (ctrl_addr_rd_o == (ctrl_mem_size - 'h40)) begin
            // wrap around
            nxt_ctrl_addr_rd = 32'b0;
          end else begin
            nxt_ctrl_addr_rd = ctrl_addr_rd_o + 'h40;
          end

          // increment memory read address
          if (m_axi_araddr == (ctrl_mem_addr + ctrl_mem_size - 'h40)) begin
            // wrap around
            nxt_m_axi_araddr = ctrl_mem_addr;
          end else begin
            nxt_m_axi_araddr = m_axi_araddr + 'h40;
          end

          if (m_axi_rlast) begin
            // this is the last beat of the current transfer
            if ((read_byte_cntr + 'h40) == ctrl_trace_size) begin
              // all trace data has been read --> done!
              nxt_state = IDLE;
            end else begin
              nxt_state = WAIT;
            end
          end
        end
      end

    endcase
  end

endmodule
