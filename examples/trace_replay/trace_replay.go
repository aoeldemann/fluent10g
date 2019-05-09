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
// This measurement application replays a trace file 100 consecutive times on
// all four network interfaces simultaneously. During replay, it prints out the
// TX and RX datarates of the network interfaces of the network tester.

package main

import (
	"time"

	"github.com/aoeldemann/gofluent10g"
)

// define the IDs of the network interfaces on which the trace shall be replayed
var interfaces = []int{0, 1, 2, 3}

// define trace filename (see README.md for instructions on how to generate trace file)
var fnameTrace = "trace.trace"

func main() {
	// open fluent10g network tester
	nt := gofluent10g.NetworkTesterCreate()
	defer nt.Close()

	// open trace file and indicate that its content shall be concatenated 100
	// times for repeated replay
	trace := gofluent10g.TraceCreateFromFile("trace.trace", 100)

	// assign trace to network interfaces
	for _, iface := range interfaces {
		nt.GetGenerator(iface).SetTrace(trace)
	}

	// write configuration to hardware
	nt.WriteConfig()

	// start printing out the current TX and RX datarates of all network
	// interfaces in 500 us intervals (starts a parallel thread)
	nt.PrintDataratesStart(500 * time.Millisecond)

	// start replay on all configured interfaces (blocks until replay has finished)
	nt.StartReplay()

	// stop the thread printing out datarates
	nt.PrintDataratesStop()

	// print out number of packets transmitted on the configured interfaces
	for _, iface := range interfaces {
		gofluent10g.Log(gofluent10g.LOG_INFO, "Sent %d packets",
			nt.GetInterface(iface).GetPacketCountTX())
	}
}
