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
// This measurement application replays a trace file 10 consecutive times on
// network interface 0. It expects the traffic to arrive back at the network
// tester at interface 1. Therefore, make sure that these two ports are either
// directly looped-back or configure your attached device-under-test
// accordingly. You are free to change the generation/reception interfaces
// below. The network tester captures the latencies (= time from packet
// transmission until reception back at the tester) for every packet and writes
// the values to an output text file after the measurement.

package main

import (
	"github.com/aoeldemann/gofluent10g"
)

// define ID of the network interface on which traffic shall be generated. the
// NetFPGA-SUME has four network interfaces (0 - 3)
var interfaceTX = 0

// define ID of the network interface on which traffic shall be captured. the
// NetFPGA-SUME has four network interfaces (0 - 3)
var interfaceRX = 1

// define the name of the output file to which the recorded latency values
// will be written
var fnameLatencies = "latencies.txt"

func main() {
	// open fluent10g network tester
	nt := gofluent10g.NetworkTesterCreate()
	defer nt.Close()

	// open trace file and indicate that its content shall be concatenated 10
	// times for repeated replay
	trace := gofluent10g.TraceCreateFromFile("trace.trace", 10)

	// assign trace to the generator
	nt.GetGenerator(interfaceTX).SetTrace(trace)

	// get the receiver on the rx port
	recv := nt.GetReceiver(interfaceRX)

	// enable packet capturing on rx interface. the first argument defines the
	// capture length, i.e. the maximum number of bytes we want to capture of
	// each arriving packet. in this measurement we are only interested in
	// packet latencies, but not the actual packet data. we therefore set the
	// capture length to zero. meta data such as packet lengths, arrival times
	// and latencies are captured even if the capture length is set to zero. the
	// second argument defines the amount of memory we want to reserve in the
	// host system's memory for packet capture (in this case only the meta
	// data). we reserve 1 GByte in this example. in the future host memory
	// should automatically be reserved, but implementation has not been
	// completed yet...
	recv.EnableCapture(0, 1024*1024*1024)

	// the packet latency (= time from transmission at the tx network interface
	// until the reception at the rx interface) is calculated based on a
	// timestamp, which is inserted into the packet right before the hardware
	// sends it out. this timestamp can be either inserted in the packet data
	// at a fixed byte position (as we do in this example), or in the IPv4
	// checksum/IPv6 flowlabel field. if we choose a fixed byte position, we
	// must determine whether the timestamp shall be 16 or 24 bits wide. longer
	// timestamp widths allow the measurement of larger latency values. with
	// 16 bit, latency values of up to 419 us can be represented. 24 bit can
	// represent values of up to 107 ms. the time resolution in both cases is
	// 6.4 ns.

	// insert timestamp at fixed byte position
	nt.SetTimestampMode(gofluent10g.TimestampModeFixedPos)

	// insert timestamp at byte position 14 (right after the ethernet header)
	nt.SetTimestampPos(14)

	// set timestamp width to 16 bit
	nt.SetTimestampWidth(16)

	// ALTERNATIVELY to write timestamps in IPv4/IPv6 header (no timestamps are
	// inserted in non-IP packets then):
	//
	//		nt.SetTimestampMode(gofluent10g.TimestampModeHeader)
	//

	// timestamps for latency calculation are only included in packets generated
	// by the network tester itself. to discard all other packets, we configure
	// a destination MAC address filter (see MAC address of generated packets
	// in generate_pcap_trace.py). we want to perform an exact match of the
	// destination MAC address, so we set the address mask to all 1s (-> match
	// all bits)
	recv.SetFilterMacAddrDst("53:00:00:00:00:02", 0xFFFFFFFFFFFF)

	// write configuration to hardware
	nt.WriteConfig()

	gofluent10g.Log(gofluent10g.LOG_INFO, "Starting measurement ...")

	// start capturing packets on the configured interfaces. this function is
	// non-blocking, i.e. it returns right after capturing has been started
	nt.StartCapture()

	// now that capturing is started, also start replaying our network trace.
	// this function is blocking, i.e. it returns after replay has been
	// completed
	nt.StartReplay()

	// after replay is done, stop capturing as well
	nt.StopCapture()

	gofluent10g.Log(gofluent10g.LOG_INFO, "Measurement done!")

	// get list of the packets that have been captured
	pkts := recv.GetCapture().GetPackets()

	// get a list of floating point packet latencies (in seconds)
	latencies := pkts.GetLatencies()

	// print out how many latency values we collected
	gofluent10g.Log(gofluent10g.LOG_INFO, "Captured %d packet latency values",
		len(latencies))

	gofluent10g.Log(gofluent10g.LOG_INFO, "Writing latencies to output file ...")

	// write latency values to output text file (one value per line)
	latencies.WriteToFile(fnameLatencies)
}
