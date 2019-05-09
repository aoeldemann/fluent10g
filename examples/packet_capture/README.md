# packet_capture

This measurement application captures arriving network traffic on all four
network interfaces for 10 seconds. It then writes the recorded data into four
separate output network traces and prints out the number of packets captured on
each interface. Each packet is accurately timestamped upon reception at the
network interface, the resulting PCAP trace contains nanosecond resolution
timestamps.

## Prerequisites

- FlueNT10G hard- and software set up

## How to use

1. Ready to capture! If you have installed the FlueNT10G software library
   natively on your system, compile the measurement application and start it:

   ```bash
   go build packet_capture.go
   sudo ./packet_capture
   ```

   If instead you are using a Docker setup, you may start the measurement
   application directly:

   ```bash
   ../../software/docker/fluent10g run packet_capture.go
   ```

   The measurement application captures traffic arriving on all four network
   interfaces for a duration of 10 seconds. Afterwards, it writes the captured
   data to four output files named ``trace[0,1,2,3].trace``, one for each
   network interface. During the capture you are able to observe the TX and RX
   data rates of the network interfaces of the tester.

   If you don't want to end up with empty trace capture files, make sure to
   connect at least one of the interfaces to a network.

2. Currently, FlueNT10G does not capture native PCAP files, but instead requires
   file conversion after performing a network test. Please do so by executing
   (don't worry, it's fast!):

   ```bash
   ./convert_traces.bash
   ```

   This creates PCAP files named ``trace[0,1,2,3].pcap``, again one per
   network interface. The PCAP files contain nanosecond precision timestamps.

3. Capture done! You can now work with the recorded trace file using standard
   tools such as tcpdump or wireshark.

Feel free to familiarize yourself with the source code (``packet_capture.go`` is
probably the most important) and make changes as you like.
