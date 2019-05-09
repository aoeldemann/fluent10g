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
// This measurement application captures arriving network traffic on all
// four network interfaces for 10 seconds. It then writes the recorded data
// into four separate output network traces and prints out the number of packets
// captured on each interface. During capturing, it prints out the TX and RX
// datarates of the network interfaces of the network tester.

package main

import (
	"time"

	"github.com/aoeldemann/gofluent10g"
)

// define a list of IDs containing the network interfaces on which traffic
// shall be captured. the NetFPGA-SUME has four network interfaces (0 - 3)
var interfaces = []int{0, 1, 2, 3}

// define a list of output trace filenames, one for each network interface
var fnameTraces = []string{
	"trace0.trace",
	"trace1.trace",
	"trace2.trace",
	"trace3.trace",
}

// define for how long traffic shall be captured
var captureDuration = 10 * time.Second

func main() {
	// open fluent10g network tester
	nt := gofluent10g.NetworkTesterCreate()
	defer nt.Close()

	// iterate over the interface IDs we want to capture traffic on
	for _, iface := range interfaces {
		// get the receiver on this interface
		recv := nt.GetReceiver(iface)

		// enable packet capturing. the first argument defines the capture
		// length, i.e. the maximum number of bytes we want to capture of each
		// arriving packet. we decide to capture all packet data, so we set the
		// capture length to the maximum packet size of 1518 bytes. meta data
		// such as packet lengths and arrival times are captured even if the
		// capture length is set to zero. the second argument defines the
		// amount of memory we want to reserve in the host system's memory for
		// packet capture. this should be set to the maximum amount of data we
		// want to capture on this interface (1 GByte in this example). In the
		// future host memory should automatically be reserved, but
		// implementation has not been completed yet...
		recv.EnableCapture(1518, 1024*1024*1024)
	}

	// write configuration to hardware
	nt.WriteConfig()

	// start printing out the current TX and RX datarates of all network
	// interfaces in 500 us intervals (starts a parallel thread)
	nt.PrintDataratesStart(500 * time.Millisecond)

	// start capturing packets on the configured interfaces. this function is
	// non-blocking, i.e. it returns right after capturing has been started
	nt.StartCapture()

	// nothing more for us to do right now. wait for the desired capture
	// period
	time.Sleep(captureDuration)

	// okay, enough time has passed. stop packet capturing
	nt.StopCapture()

	// stop the thread printing out datarates
	nt.PrintDataratesStop()

	// iterate over the interface IDs we were capturing traffic on
	for i, iface := range interfaces {
		// get the receiver on this interface again
		recv := nt.GetReceiver(iface)

		// get the captured packet data ...
		capture := recv.GetCapture()

		// ... and write it to an output trace file
		capture.WriteToFile(fnameTraces[i])

		// print out the number of packets we have captured on this interface
		gofluent10g.Log(gofluent10g.LOG_INFO, "IF%d: Captured %d packets",
			iface, recv.GetPacketCountCaptured())
	}
}
