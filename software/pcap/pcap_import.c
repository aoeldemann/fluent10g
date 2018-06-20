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
// Convers a PCAP file to a trace file that can be replay by the FlueNT10G
// network tester. Currently only PCAP files containing nanosecond precision
// timestamps can be converted.

#include <pcap/pcap.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

#define PCAP_MAGIC_NUMBER 0xa1b23c4d // nanosecond timestamp precision
#define PCAP_MAX_PKT_SIZE 1518 // maximum packet size
#define CLK_FREQ 156.25e6 // clock frequency of the hardware replay logic

/**
 * Struct containing user data, which is passed along between pcap packet
 * handler calls.
 */
struct pcap_user_data_t {
  uint64_t n_pkts; // number of packets that have been processed
  struct pcap_pkthdr pkt_hdr_prev; // pcap header infos of previous packet
  uint8_t pkt_data_prev[PCAP_MAX_PKT_SIZE]; // data of previous packet
  double ts_rounding_err; // accumulated timestamp rounding error
  FILE *f_trace; // trace file handle
};

/**
 * Print usage message.
 * @param argv arguments passed on the command-line.
 */
void usage(char **argv) {
  printf("Usage: %s <input_pcap_file> <output_trace_file>\n", argv[0]);
  exit(-1);
}

/**
 * Print error message.
 * @param msg error message.
 */
void error(char * msg) {
  printf("ERROR: %s\n", msg);
  exit(-1);
}

/**
 * Write packet to trace file.
 * @param f_trace trace file handle.
 * @param ts_diff number of clock cycles until next packet transmission.
 * @param pkt_hdr pcap packet header struct.
 * @param pkt_data pcap packet data.
 */
void write_packet(FILE *f_trace, uint32_t ts_diff, struct pcap_pkthdr *pkt_hdr,
                  uint8_t *pkt_data) {
  // assemble 8 byte meta data
  uint64_t meta = 0;
  meta |= (uint64_t) ts_diff;
  meta |= ((uint64_t) pkt_hdr->caplen) << 32;
  meta |= ((uint64_t) pkt_hdr->len) << 48;

  // write meta data to file
  uint32_t bytes_written = fwrite(&meta, 1, 8, f_trace);
  if (bytes_written != 8) {
    error("could not write packet meta data");
  }

  // write packet data to file
  bytes_written = fwrite(pkt_data, 1, pkt_hdr->len, f_trace);
  if (bytes_written != pkt_hdr->len) {
    error("could not write packet data");
  }

  // packet data must be 8 byte aligned. add padding if necessary
  if (pkt_hdr->len % 8 != 0) {
    // calculate number of bytes we need to append
    uint8_t bytes_padding = 8 * (pkt_hdr->len / 8 + 1) - pkt_hdr->len;

    // add padding
    for (uint8_t i = 0; i < bytes_padding; i++) {
      fputc(0, f_trace);
    }
  }
}

/**
 * PCAP packet handler callback function.
 * @param user_data user data passed between packet handler calls.
 * @param pkt_hdr pcap packet header struct.
 * @param pkt_data pcap packet data.
 */
void pcap_pkt_handler(uint8_t *user_data_, const struct pcap_pkthdr *pkt_hdr,
                      const uint8_t *pkt_data) {

  struct pcap_user_data_t *user_data =  (struct pcap_user_data_t*) user_data_;

  // make sure packet's capture length does not exceed the maximum configured
  // length
  if (pkt_hdr->caplen > PCAP_MAX_PKT_SIZE) {
    error("packet size exceeds configured maximum length");
  }

  if (user_data->n_pkts > 0) {
    // calculate inter-packet time in relation to previous packet
    struct timeval ts_diff;
    timersub(&pkt_hdr->ts, &user_data->pkt_hdr_prev.ts, &ts_diff);

    // convert timeval struct inter-packet time to nanoseconds (for nano-second
    // precision pcap files the 'tv_usec' value actually contains nanoseconds!)
    uint64_t ts_diff_nsecs = ts_diff.tv_sec * 1e9 + ts_diff.tv_usec;

    // convert inter-packet time to nanoseconds, do not round yet
    double ts_diff_cycles = (double)ts_diff_nsecs * CLK_FREQ / 1e9;

    // round number of cycles to integer number. track rounding error and try
    // to evenly round up and down
    uint32_t ts_diff_cycles_rounded;
    if (user_data->ts_rounding_err < 1.0) {
      ts_diff_cycles_rounded = ceil(ts_diff_cycles);
      user_data->ts_rounding_err += ceil(ts_diff_cycles) - ts_diff_cycles;
    } else {
      ts_diff_cycles_rounded = floor(ts_diff_cycles);
      user_data->ts_rounding_err -= ts_diff_cycles - floor(ts_diff_cycles);
    }

    // write the previous(!) packet to the trace file
    write_packet(user_data->f_trace, ts_diff_cycles_rounded,
                 &user_data->pkt_hdr_prev, user_data->pkt_data_prev);
  }

  // store packet header and data in user data
  memcpy(&user_data->pkt_hdr_prev, pkt_hdr, sizeof(struct pcap_pkthdr));
  memcpy(&user_data->pkt_data_prev, pkt_data, pkt_hdr->caplen);

  // increment packet number
  user_data->n_pkts++;
}


/**
 * Main function.
 * @param argc number of command-line parameters.
 * @param argv command-line parameters.
 * @return exit code.
 */
int32_t main(int argc, char **argv) {
  // make sure both input and output file names have been provided
  if (argc != 3) {
    usage(argv);
  }

  // extract filenames from command line options
  char *filename_pcap = argv[1];
  char *filename_trace = argv[2];

  // create buffer for error messages
  char errMsg[256];

  // open pcap file for reading
  FILE *fp = fopen(filename_pcap, "rb");
  if (fp == NULL) {
    error("could not open pcap file for reading");
  }

  // read the first 4 bytes from the pcap file, they contain the magic number
  int32_t magic_number;
  size_t bytes_read = fread(&magic_number, 1, 4, fp);

  // close pcap file
  fclose(fp);

  // make sure we were able to read the magic number
  if (bytes_read != 4) {
    error("could not read pcap magic number");
  }

  // make sure magic number is correct
  if (magic_number != PCAP_MAGIC_NUMBER) {
    sprintf(errMsg, "pcap magic number is: 0x%8x, expected: 0x%x. only "\
                    "nano-second precision pcap files supported right now.",
            magic_number, PCAP_MAGIC_NUMBER);
    error(errMsg);
  }

  char pcapErrbuf[256];

  // open pcap file
  pcap_t *f_pcap =
    pcap_open_offline_with_tstamp_precision(filename_pcap,
                                            PCAP_TSTAMP_PRECISION_NANO,
                                            errMsg);
  if (f_pcap == NULL) {
    error(errMsg);
  }

  // open trace output file for writing
  FILE *f_trace = fopen(filename_trace, "wb");
  if (f_trace == NULL) {
    error("could not open trace file for writing");
  }

  // initialize user data
  struct pcap_user_data_t user_data;
  user_data.n_pkts = 0;
  user_data.ts_rounding_err = 0.0;
  user_data.f_trace = f_trace;

  // packet processing loop
  if (pcap_loop(f_pcap, 0, pcap_pkt_handler, (uint8_t*) &user_data) < 0) {
    error(pcap_geterr(f_pcap));
  }

  // write the last packet to the trace file
  write_packet(f_trace, 0, &user_data.pkt_hdr_prev, user_data.pkt_data_prev);

  // the total length of the output trace file must be 64 byte aligned. add
  // padding (all bits set to one) if necessary
  uint64_t trace_size = ftell(f_trace);
  if (trace_size % 64 != 0) {
    // calculate number of bytes we need to append
    uint8_t bytes_padding = 64 * (trace_size / 64 + 1) - trace_size;

    // add padding
    for (uint8_t i = 0; i < bytes_padding; i++) {
      fputc(0xFF, f_trace);
    }
  }

  // close files
  pcap_close(f_pcap);
  fclose(f_trace);

  // print some infos
  printf("Successfully wrote %ld packets to trace file!\n", user_data.n_pkts);

  return 0;
}
