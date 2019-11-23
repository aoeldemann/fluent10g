########
Examples
########

Trace Replay
------------

`Source Code`__

This example measurement application replays a constant-bit-rate network trace (10 Gbps, 64 bytes packets) on all four interfaces of the network tester simultaneously.

.. _Replay: https://github.com/aoeldemann/fluent10g/tree/master/examples/trace_replay
__ Replay_

Trace Capture
-------------

`Source Code`__

This measurement application captures arriving network traffic on all four network interfaces for 10 seconds.
It then writes the recorded data into four separate output network traces and prints out the number of packets captured on each interface.
Each packet is accurately timestamped upon reception at the network interface, the resulting PCAP trace contains nanosecond resolution timestamps.

.. _Capture: https://github.com/aoeldemann/fluent10g/tree/master/examples/packet_capture
__ Capture_

Latency Measurements
--------------------

`Source Code`__

This measurement application replays a trace file (constant-bit-rate traffic, 10 Gbps, 64 byte packets) on network interface 0.
It expects the traffic to arrive back at the network tester at interface 1.
Therefore, make sure that these two ports are either directly looped-back or configure your attached device-under-test accordingly.
The network tester captures the latencies (= time from packet transmission until reception back at the tester) for every packet and writes the values to an output text file after the measurement (6.4 ns time resolution).

.. _Latency: https://github.com/aoeldemann/fluent10g/tree/master/examples/latency
__ Latency_


