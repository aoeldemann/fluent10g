#!/usr/bin/env bash
# compile software, if not done yet
if [[ ! -f ../../software/pcap/pcap_import ]]; then
  make -C ../../software/pcap
fi

# convert trace file
../../software/pcap/pcap_import trace.pcap trace.trace
