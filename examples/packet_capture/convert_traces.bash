#!/usr/bin/env bash
# compile software, if not done yet
if [[ ! -f ../../software/pcap/pcap_export ]]; then
  make -C ../../software/pcap
fi

# convert trace files (last argument specifies packet capture length)
../../software/pcap/pcap_export trace0.trace trace0.pcap 1518
../../software/pcap/pcap_export trace1.trace trace1.pcap 1518
../../software/pcap/pcap_export trace2.trace trace2.pcap 1518
../../software/pcap/pcap_export trace3.trace trace3.pcap 1518
