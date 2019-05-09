# latency

This measurement application replays a trace file (constant-bit-rate traffic,
10 Gbps, 64 byte packets) on network interface 0. It expects the traffic to
arrive back at the network tester at interface 1. Therefore, make sure that
these two ports are either directly looped-back or configure your attached
device-under-test accordingly. The network tester captures the latencies (= time
from packet transmission until reception back at the tester) for every packet
and writes the values to an output text file after the measurement (6.4 ns
time resolution).

## Prerequisites

1. FlueNT10G hard- and software set up
2. Python 3 interpreter (tested with v3.5.2)
3. [Scapy](https://scapy.net) Python library (new version with nanosecond
   precision timestamps required, tested with v2.4.2)
4. Traffic transmitted on interface 0 must arrive back at the network tester
   on interface 1. Either loop-back these ports directly or make sure that an
   attached device-under-test ensures this. You are free to change the TX and
   RX interface IDs in the ``latency.go`` file.

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
   parameters as you like by modifying the variables in the file.

   Instead of generating a trace, you can also use a PCAP file you already may
   have (as long as it has nanosecond precision timestamps). Just place it in
   this folder and name it ``trace.pcap``. Additionally, please comment out line
   116 in ``latency.go``, since the the MAC addresses in your PCAP file will
   probably not match the ones of our generated trace.

2. Currently, FlueNT10G does not replay native PCAP files, but instead requires
   file conversion before performing a network test. Please do so by executing
   (don't worry, it's fast!):

   ```bash
   ./convert_trace.bash
   ```

   This creates an output file named ``trace.trace``.

3. Ready to measure! If you have installed the FlueNT10G software library
   natively on your system, compile the measurement application and start it:

   ```bash
   go build latency.go
   sudo ./latency
   ```

   If instead you are using a Docker setup, you may start the measurement
   application directly:

   ```bash
   ../../software/docker/fluent10g run latency.go
   ```

   The measurement application replays the trace file 10 times (without
   pauses) on network interface 0 of the tester. Since the trace file generated
   in step 1 is 100 ms long, the total measurement duration is 1 second. After
   the measurement is completed, an output file named ``latencies.txt`` is
   created, which contains one recorded packet latency value per line
   (floating-point values in seconds, 6.4 ns resolution).

Feel free to familiarize yourself with the source code (``latency.go`` is
probably the most important) and make changes as you like.
