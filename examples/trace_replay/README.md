# trace_replay

This example measurement application replays a constant-bit-rate network trace
(10 Gbps, 64 bytes packets) on all four interfaces of the network tester
simultaneously.

## Prerequisites

1. FlueNT10G hard- and software set up
2. Python 3 interpreter (tested with v3.5.2)
3. [Scapy](https://scapy.net) Python library (new version with nanosecond precision timestamps required, tested with v2.4.2)

## How to use

1. We first generate a PCAP network trace, which will later be replayed by the
   network tester:

   ```bash
   ./generate_pcap_trace.py
   ```

   This script generates a PCAP trace with constant-bit-rate traffic using the
   [Scapy](https://scapy.net) Python library. The script is parameterized to
   generate a 100 ms trace with a raw data rate of 10 Gbps. The packet size is
   set to 60 byte (excluding Ethernet frame checksum). You can change these
   parameters as you like by modifying the variables in the file. Instead of
   generating a trace, you can also use a PCAP file you already may have
   (as long as it has nanosecond precision timestamps). Just place it in this
   folder and name it ``trace.pcap``.

2. Currently, FlueNT10G does not replay native PCAP files, but instead requires
   file conversion before performing a network test. Please do so by executing
   (don't worry, it's fast!):

   ```bash
   ./convert_trace.bash
   ```

   This creates an output file named ``trace.trace``.

3. Ready for replay! If you have installed the FlueNT10G software library
   natively on your system, compile the measurement application and start it:

   ```bash
   go build trace_replay.go
   sudo ./trace_replay
   ```

   If instead you are using a Docker setup, you may start the measurement
   application directly:

   ```bash
   ../../software/docker/fluent10g run trace_replay.go
   ```

   The measurement application replays the trace file 100 times (without
   pauses) on all four network interfaces of the network tester. If you are
   using the 100 ms generated trace file from step 1, replay lasts 10 seconds.
   During the measurements you are able to observe the TX and RX data rates of
   the network interfaces of the tester.

Feel free to familiarize yourself with the source code (``trace_replay.go`` is
probably the most important) and make changes as you like.
