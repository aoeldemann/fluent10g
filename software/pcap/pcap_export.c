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
// Converts a trace file recorded by the FlueNT10G network tester to a
// nanosecond precision PCAP file.

#include <pcap/pcap.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define CLK_FREQ 156.25e6 // clock frequency of the hardware capture logic

/**
 * Print usage message.
 * @param argv arguments passed on the command-line.
 */
void usage(char **argv) {
  printf("Usage: %s <input_trace_file> <output_pcap_file> <max_caplen>\n",
         argv[0]);
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
 * Main function.
 * @param argc number of command-line parameters.
 * @param argv command-line parameters.
 * @return exit code.
 */
int32_t main(int argc, char **argv) {
  // make sure input and output file names and maximum capture length have been
  // provided
  if (argc != 4) {
    usage(argv);
  }

  // extract filenames from command line options
  char *filename_trace = argv[1];
  char *filename_pcap = argv[2];

  // extract maximum capture length
  uint16_t max_caplen = atoi(argv[3]);

  // open trace file for reading
  FILE *f_trace = fopen(filename_trace, "rb");
  if (f_trace == NULL) {
    error("could not open output pcap file for writing");
  }

  // determine trace file size
  fseek(f_trace, 0, SEEK_END);
  size_t f_trace_size = ftell(f_trace);
  rewind(f_trace);

  // make sure file size is a multiple of 64 bytes
  if (f_trace_size % 64 != 0) {
    error("input trace file size must be a multiple of 64 byte");
  }

  // create pcap handle
  pcap_t *f_pcap =
    pcap_open_dead_with_tstamp_precision(DLT_EN10MB, 65535,
                                         PCAP_TSTAMP_PRECISION_NANO);
  if (f_pcap == NULL) {
    error("could not create pcap handle");
  }

  // create pcap dumper
  pcap_dumper_t *d_pcap = pcap_dump_open(f_pcap, filename_pcap);
  if (d_pcap == NULL) {
    error("could not create pcap dumper");
  }

  // packet counter
  uint64_t n_pkts = 0;

  // create pcap packet header
  struct pcap_pkthdr pkt_hdr;

  // initialize pcap packet header timestamp to zero
  memset(&pkt_hdr.ts, 0, sizeof(struct timeval));

  // process input data until we reach the end of the file
  while(ftell(f_trace) < f_trace_size) {
    // read 8 byte meta data
    uint64_t meta;
    uint32_t bytes_read = fread(&meta, 1, 8, f_trace);
    if (bytes_read != 8) {
      error("could not read meta data");
    }

    // if all bits of the meta data are set high, we reached the end of
    // the capture data
    if (meta == 0xFFFFFFFFFFFFFFFF) {
      break;
    }

    // extract meta information
    uint32_t ts_diff_cycles = (meta >> 25) & 0xFFFFFFF;
    uint32_t len = (meta >> 53) & 0x7FF;
    uint32_t caplen;
    if (len > max_caplen) {
      caplen = max_caplen;
    } else {
      caplen = len;
    }

    // read packet data
    uint8_t pkt_data[caplen];
    bytes_read = fread(pkt_data, 1, caplen, f_trace);
    if (bytes_read != caplen) {
      error("could not read packet data");
    }

    // packet data is 8 byte aligned. in case packet data is padded to
    // reach alignment, do some dummy reads
    if (caplen % 8 != 0) {
      // calculate number of bytes we need to read
      uint8_t bytes_padding = 8 * (caplen / 8 + 1) - caplen;

      // read padding bytes
      for (uint8_t i = 0; i < bytes_padding; i++) {
        fgetc(f_trace);
      }
    }

    // set caplen and len
    pkt_hdr.caplen = caplen;
    pkt_hdr.len = len;

    // leave the timestamp set to zero for the first packet
    if (n_pkts > 0) {
      // convert number of clock cylces that have passed since last packet
      // arrival to nanoseconds (we always cut off the fractional part here)
      uint64_t ts_diff_nsecs = ts_diff_cycles / CLK_FREQ * 1e9;

      // since the timestamp value in clock cycles provided by the hardware
      // is only 25 bit wide, it never exceeds 1 seconds. so it is easy
      // to construct a timeval struct. Note that the libpcap expects a
      // nanosecond value in the 'tv_usec' field for nanosecond precision
      // timestamps
      struct timeval ts_diff;
      ts_diff.tv_sec = 0;
      ts_diff.tv_usec = ts_diff_nsecs;

      // increment pcap packet header timestamp
      timeradd(&pkt_hdr.ts, &ts_diff, &pkt_hdr.ts);
    }

    // write packet to pcap file
    pcap_dump((uint8_t* )d_pcap, &pkt_hdr, pkt_data);

    // increment packet counter
    n_pkts++;
  }

  // close files and handles
  fclose(f_trace);
  pcap_dump_close(d_pcap);
  pcap_close(f_pcap);

  // print some info
  printf("Succesfully wrote %ld packets to pcap file!\n", n_pkts);
}
