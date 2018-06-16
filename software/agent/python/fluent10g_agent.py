"""FlueNT10G Device-under-Test Agent."""
# The MIT License
#
# Copyright (c) 2017-2018 by the author(s)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Author(s):
#   - Andreas Oeldemann <andreas.oeldemann@tum.de>
#
# Description:
#
# This library implements the FlueNT10G agent. The agent is executed on the
# device-under-test (DuT). The measurement application controlling the
# FlueNT10G hardware can communicate with this agent via a ZeroMQ-based
# control channel (by exchanging JSON messages). The agent acts as an
# intermediary of the measurement application. It can trigger code execution on
# the DuT and in return obtain monitoring data. The agent does not actually
# implement the code that shall be executed. Instead, the user may register
# event handler callback functions, which are called when a certain event is
# triggered by a measurement application, via the register_evt_handler()
# function. Monitoring data can be stored via the store_monitor_data() function
# (the measurement application can then fetch the stored data, the data transfer
# to the measurement application is not initiated).

import inspect
import logging
import json
import zmq

# dictionary storing monitor data. key: data identifier, value: list of data
# values
MONITOR_DATA = {}


class AgentMsg(object):
    """Message received/to be sent from/to the measurement application."""

    def __init__(self, json_data):
        """Create message from JSON data."""
        # set event name
        self.evt_name = json_data['evt_name']

        # optionally add arguments
        if "args" in json_data:
            self.args = json_data['args']
        else:
            self.args = {}

    def json(self):
        """Convert message to JSON data."""
        return json.dumps({'evt_name': self.evt_name, 'args': self.args})


class AgentMsgAck(AgentMsg):
    """ACK message to be sent to the measurement application."""

    def __init__(self, return_data):
        """Initialize message."""
        # set event name
        self.evt_name = "ack"

        # optionally add return data
        if return_data is not None:
            self.args = {'return_data': return_data}
        else:
            self.args = None


class AgentMsgNack(AgentMsg):
    """NACK message to be sent to the measurement application."""

    def __init__(self, reason):
        """Initialize message."""
        # set event name and nack reason
        self.evt_name = "nack"
        self.args = {'reason': reason}


class AgentException(Exception):
    """Custom Exception class."""

    # it's all about the exception type, nothing to do here!
    pass


class AgentEventArgs(object):
    """Event arguments passed to the DuT by the measurement application."""

    def __init__(self, args):
        """Initialize event argument."""
        self._args = args

    def get(self, arg):
        """Return the argument value for a given key."""
        if self._args is None:
            raise AgentException(("argument '%s' does not exist (no " +
                                  "arguments have been passed)") % arg)
        try:
            return self._args[arg]
        except KeyError:
            raise AgentException("argument '%s' does not exist" % arg)


class Fluent10GAgent(object):
    """Fluent10G agent class."""

    def __init__(self, listenIPAddr, listenPort):
        """Initialize and start ZeroMQ socket."""
        # set up logging
        log_handler = logging.StreamHandler()
        log_formatter = logging.Formatter(
            '%(asctime)s %(levelname)-8s %(message)s')
        log_handler.setFormatter(log_formatter)
        self._logger = logging.getLogger()
        self._logger.addHandler(log_handler)
        self._logger.setLevel(logging.DEBUG)

        # set up ZeroMQ socket
        zmqctx = zmq.Context()
        self._zmqsock = zmqctx.socket(zmq.REP)
        self._zmqsock.bind("tcp://%s:%d" % (listenIPAddr, listenPort))
        self._logger.log(logging.INFO, "listening on %s:%d", listenIPAddr,
                         listenPort)

        # initialize empty event handler dict
        self._evt_handlers = {}

        # set up an event handler with the identifier "get_monitor_data", which
        # provides monitor data back to the measurement application when
        # requested
        self._evt_handlers["get_monitor_data"] = self._get_monitor_data

    def register_evt_handler(self, evt_name, cb_func):
        """Register an event handler callback function."""
        # check if callback for this event name is registered already and print
        # a warning if that's the case
        if evt_name in self._evt_handlers:
            self._logger.log(logging.WARN,
                             "handler for event '%s' already registered. " +
                             "overwriting.", evt_name)

        # make sure callback function expects exactly one argument
        if len(inspect.getfullargspec(cb_func).args) != 1:
            raise AgentException(("handler '%s()' for event '%s' must have " +
                                  "exactly one function parameter") %
                                 (evt_name, cb_func.__name__))

        # save callback function
        self._evt_handlers[evt_name] = cb_func


    def store_monitor_data(self, ident, data):
        """Store monitoring data."""
        # check if data for the given identifier has been saved yet. create
        # empty list if that's not the case
        if ident not in MONITOR_DATA:
            MONITOR_DATA[ident] = []

        # append monitor data to list for the specified identifier
        MONITOR_DATA[ident].append(data)

    def start(self):
        """Start the agent.

        Start an infinite loop in which messages are received from the ZeroMQ
        server socket and then are processed. For each received message, an
        ACK/NACK is sent back to the measurement application.
        """
        while True:
            # wait for next message
            try:
                msg = self._recv()
            except json.decoder.JSONDecodeError:
                # not a JSON message. print warning and send nack
                self._logger.log(logging.WARN, "non-JSON message")
                self._send(AgentMsgNack("non-JSON message"))
                continue
            except KeyboardInterrupt:
                exit(0)

            # create new message object
            try:
                msg = AgentMsg(msg)
            except Exception:
                # unexpected message format. print warning and send nack
                self._logger.log(logging.WARN, "invalid JSON message")
                self._send(AgentMsgNack("invalid JSON message"))
                continue

            # handle the message
            try:
                return_data = self._handle_msg(msg)
                # everything worked. send ack
                self._send(AgentMsgAck(return_data))
            except AgentException as exc:
                # print out a warning
                self._logger.log(logging.WARN, exc.args[0])
                # something went wrong, report error message to measurement
                # application
                self._send(AgentMsgNack(exc.args[0]))
            except KeyboardInterrupt:
                # application aborted, report to measurement application
                self._send(AgentMsgNack("agent quit"))
                exit(0)
            except Exception as exc:
                # something went wrong, but no error message is defined. report
                # to the measurement application
                self._send(AgentMsgNack("undefined error"))
                # raise error -> agent will exit
                raise exc

    def _recv(self):
        """Receive a message from the ZeroMQ socket."""
        return self._zmqsock.recv_json()

    def _send(self, msg):
        """Send a message via the ZeroMQ socket."""
        self._zmqsock.send_string(msg.json())

    def _handle_msg(self, msg):
        """Handle a message received from the measurement application.

        Determine what kind of event is triggered and call the appropriate
        event handler callback function. Also do some more error checking.
        """
        # make sure an event handler is registered
        if msg.evt_name not in self._evt_handlers:
            # no event handler registered for this event type, raise an
            # exception
            raise AgentException("no event handler registered for " +
                                 "'%s' event" % msg.evt_name)

        # call event handler
        return self._evt_handlers[msg.evt_name](AgentEventArgs(msg.args))

    def _get_monitor_data(self, args):
        """Callback function returning monitor data back to measurement app."""
        # get identifier of the data set that is requested
        ident = args.get("ident")

        # make sure data has been collected for that identifier
        if ident not in MONITOR_DATA:
            raise AgentException("no data '%s' found" % ident)

        # return the data
        return MONITOR_DATA[ident]
