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
// This library implements the FlueNT10G agent. The agent is executed on the
// device-under-test (DuT). The measurement application controlling the
// FlueNT10G hardware can communicate with this agent via a ZeroMQ-based
// control channel (by exchanging JSON messages). The agent acts as an
// intermediary of the measurement application. It can trigger code execution on
// the DuT. The agent does not actually implement the code that shall be
// executed. Instead, the user may register event handler callback functions,
// which are called when a certain event is triggered by a measurement
// application, via the fluent10g_register_evt_handler() function. In this C
// version of the agent, the retrieval of monitoring data by the measurement
// application is not implemented yet.

#include <stdint.h>

struct fluent10g_arg {
  char *name;
  uint8_t type;
};

typedef void (*fluent10g_evt_handler_t)(struct fluent10g_arg**, uint8_t);

void fluent10g_register_evt_handler(const char* evt_name,
                                    fluent10g_evt_handler_t cb_func);

void fluent10g_start(const char* listen_ip_addr, const uint16_t listen_port);

int32_t fluent10g_get_arg_int(const char *name,
                              struct fluent10g_arg** args,
                              uint8_t n_args);

double fluent10g_get_arg_double(const char *name,
                                struct fluent10g_arg** args,
                                uint8_t n_args);

char* fluent10g_get_arg_string(const char *name,
                               struct fluent10g_arg** args,
                               uint8_t n_args);

