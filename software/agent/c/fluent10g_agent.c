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

#include "fluent10g_agent.h"
#include <zmq.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include "cJSON.h"

#define FLUENT10G_MAX_N_EVT_HANDLERS 32
#define FLUENT10G_MAX_N_ARGS 16
#define FLUENT10G_MAX_LEN_ZMQ_MSG_RX 64
#define FLUENT10G_MAX_LEN_ERR_MSG 128
#define FLUENT10G_MAX_LEN_EVT_HANDLER_NAME 32

#define FLUENT10G_ARG_TYPE_NUMBER 0
#define FLUENT10G_ARG_TYPE_STRING 1

/*
ZeroMQ socket
*/
void *sock = NULL;

/*
Event handler struct. Contains event name and callback function.
*/
struct fluent10g_event_handlers {
  char name[FLUENT10G_MAX_LEN_EVT_HANDLER_NAME];
  fluent10g_evt_handler_t cb_func;
};

/*
Numeric argument struct.
*/
struct fluent10g_arg_number {
  struct fluent10g_arg arg;
  int32_t value_int;
  double value_double;
};

/*
String argument struct.
*/
struct fluent10g_arg_string {
  struct fluent10g_arg arg;
  char *value;
};

/*
Event handlers
*/
struct fluent10g_event_handlers event_handlers[FLUENT10G_MAX_N_EVT_HANDLERS];

/*
Number of registered event handlers.
*/
uint16_t n_event_handlers = 0;

/*
Print out error message and exit agent appliction.
*/
void error(const char* msg) {
  // print error message
  printf("ERROR: %s\n", msg);

  // the zmq socket probably still has data that needs to be sent to the
  // measurement application. sleep a bit to let that happen.
  // TODO: is there a way to explicity flush the socket data?
  usleep(1000);

  // close zmq socket
  zmq_close(sock);

  // and finally exit
  exit(-1);
}

/*
Print out warning message.
*/
void warn(const char* msg) {
  // print warning message
  printf("WARN: %s\n", msg);
}

/*
Return whether argument contains a numeric value.
*/
uint8_t arg_is_number(struct fluent10g_arg *arg) {
  return arg->type == FLUENT10G_ARG_TYPE_NUMBER;
}

/*
Return whether argument contains a string value.
*/
uint8_t arg_is_string(struct fluent10g_arg *arg) {
  return arg->type == FLUENT10G_ARG_TYPE_STRING;
}

/*
Delete a list of arguments.
*/
void args_delete(struct fluent10g_arg** args, uint8_t n_args) {
  for (uint8_t i = 0; i < n_args; i++) {
    free(args[i]);
  }
}

/*
Create a base JSON message.
*/
cJSON* create_msg(const char *evt_name) {
  // create empty json message
  cJSON *msg = cJSON_CreateObject();
  assert(msg);

  // add event name
  cJSON_AddItemToObject(msg, "evt_name", cJSON_CreateString(evt_name));

  // return message
  return msg;
}

/*
Create an ACK JSON message.
*/
cJSON* create_msg_ack() {
  // create ack message
  cJSON *msg = create_msg("ack");

  // return message
  return msg;
}

/*
Create a NACK JSON message.
*/
cJSON* create_msg_nack(const char *reason) {
  // create nack message
  cJSON *msg = create_msg("nack");

  // add arguments
  cJSON *args = cJSON_CreateObject();
  assert(args);
  cJSON_AddItemToObject(args, "reason", cJSON_CreateString(reason));
  cJSON_AddItemToObject(msg, "args", args);

  // return message
  return msg;
}

/*
Send a JSON message to the measurement application.
*/
void send_msg(cJSON *msg) {
  // send message
  char *buf = cJSON_Print(msg);
  int rc = zmq_send(sock, buf, strlen(buf), 0);
  assert(rc >= 0);

  // delete message
  cJSON_Delete(msg);
}

/*
Handle a received JSON message.
*/
void handle_msg(cJSON *msg) {
  // we first need to identify the event name
  cJSON *msg_evt_name = cJSON_GetObjectItemCaseSensitive(msg, "evt_name");
  assert(msg_evt_name && cJSON_IsString(msg_evt_name));
  char *evt_name = msg_evt_name->valuestring;

  // find event handler callback function
  fluent10g_evt_handler_t callback = NULL;
  for (uint16_t i = 0; i < n_event_handlers; i++) {
    if (strcmp(event_handlers[i].name, evt_name) == 0) {
      callback = event_handlers[i].cb_func;
      break;
    }
  }

  // if no event handler has been found, send an error to the measurement
  // application and print a warning
  if (callback == NULL) {
    char buf[256];
    sprintf(buf, "no event handler registered for '%s' event", evt_name);
    warn(buf);
    send_msg(create_msg_nack(buf));
    return;
  }

  // initialize an empty list of argument structs
  uint8_t n_args = 0;
  struct fluent10g_arg* args[FLUENT10G_MAX_N_ARGS];

  // iterate over all JSON argument objects
  cJSON *msg_args = cJSON_GetObjectItemCaseSensitive(msg, "args");
  cJSON *msg_arg;
  cJSON_ArrayForEach(msg_arg, msg_args) {
    if (cJSON_IsNumber(msg_arg)) {
      // numeric argument, create argument struct instance and save values
      args[n_args] = malloc(sizeof(struct fluent10g_arg_number));
      args[n_args]->name = msg_arg->string;
      args[n_args]->type = FLUENT10G_ARG_TYPE_NUMBER;
      ((struct fluent10g_arg_number*) args[n_args])->value_int =
        msg_arg->valueint;
      ((struct fluent10g_arg_number*) args[n_args])->value_double =
        msg_arg->valuedouble;
      n_args++;
    } else if (cJSON_IsString(msg_arg)) {
      // string argument, create argument struct instance and save values
      args[n_args] = malloc(sizeof(struct fluent10g_arg_string));
      args[n_args]->name = msg_arg->string;
      args[n_args]->type = FLUENT10G_ARG_TYPE_STRING;
      ((struct fluent10g_arg_string*) args[n_args])->value =
        msg_arg->valuestring;
      n_args++;
    } else {
      // argument is not numeric and not a string. print warning and send error
      // to measurement application
      warn("invalid argument type");
      send_msg(create_msg_nack("invalid argument type"));

      // delete arguments
      args_delete(args, n_args);

      // done for now
      return;
    }
  }

  // call event handler callback
  callback(args, n_args);

  // delete arguments
  args_delete(args, n_args);

  // send an ack back to the measurement application
  send_msg(create_msg_ack());
}

/*
Callback function for 'get_monitor_data' event.
*/
void cb_get_monitor_data(struct fluent10g_arg** args, uint8_t n_args) {
  // TODO: implement this! :-)
  send_msg(create_msg_nack("monitor data retrieval not implemented yet in C "
                           "version of Fluent10G agent"));
  error("monitor data retrieval not implemented yet in C version of Fluent10G "
        "agent");
}

/*
Register an event handler callback function
*/
void fluent10g_register_evt_handler(const char *evt_name,
                                    fluent10g_evt_handler_t cb_func) {
  // make sure no event handler is registered for this event name yet
  for (uint16_t i = 0; i < n_event_handlers; i++) {
    if (strcmp(event_handlers[i].name, evt_name) == 0) {
      char msg[256];
      sprintf(msg, "handler for event '%s' already registered.", evt_name);
      error(msg);
    }
  }

  // save event handler name and callback function
  memcpy(event_handlers[n_event_handlers].name, evt_name, strlen(evt_name));
  event_handlers[n_event_handlers].cb_func = cb_func;
  n_event_handlers++;
}

/*
Start the agent.

Start an infinite loop in which messages are received from the ZeroMQ server
socket and then are processed. For each received message, an ACK/NACK is sent
back to the measurement application.
*/
void fluent10g_start(const char* listen_ip_addr, const uint16_t listen_port) {
  // set up ZeroMQ socket
  void *ctx = (void*) zmq_ctx_new();
  sock = zmq_socket(ctx, ZMQ_REP);
  char endpoint[128];
  sprintf(endpoint, "tcp://%s:%d", listen_ip_addr, listen_port);
  int rc = zmq_bind(sock, endpoint);
  assert(rc == 0);

  // register event handler for the 'get_monitor_data' event
  fluent10g_register_evt_handler("get_monitor_data", cb_get_monitor_data);

  // create buffer to hold received messages
  char buf[FLUENT10G_MAX_LEN_ZMQ_MSG_RX];

  // parsed json message
  cJSON *msg;

  while(1) {
    // wait for next message
    rc = zmq_recv(sock, buf, FLUENT10G_MAX_LEN_ZMQ_MSG_RX, 0);
    assert(rc >= 0);

    // parse json message
    msg = cJSON_Parse(buf);
    if(msg == NULL) {
      // not a JSON message, print warning and send nack
      warn("non-JSON message");
      send_msg(create_msg_nack("non-JSON message"));
      continue;
    }

    // handle the message
    handle_msg(msg);

    // delete json message
    cJSON_Delete(msg);
  }
}

/*
Return integer argument value.
*/
int32_t fluent10g_get_arg_int(const char *name,
                              struct fluent10g_arg** args,
                              uint8_t n_args) {
  // iterate over all arguments
  for (uint8_t i = 0; i < n_args; i++) {
    // does argument name match?
    if (strcmp(args[i]->name, name) == 0) {
      // numeric argument?
      if (arg_is_number(args[i]) == 0) {
        char buf[FLUENT10G_MAX_LEN_ERR_MSG];
        sprintf(buf, "argument '%s' is not numeric", name);
        send_msg(create_msg_nack(buf));
        error(buf);
      }
      // return double value
      return ((struct fluent10g_arg_number*) args[i])->value_int;
    }
  }

  char buf[FLUENT10G_MAX_LEN_ERR_MSG];
  sprintf(buf, "argument '%s' does not exist", name);
  send_msg(create_msg_nack(buf));
  error(buf);

  return -1;
}

/*
Return double argument value.
*/
double fluent10g_get_arg_double(const char *name,
                                struct fluent10g_arg** args,
                                uint8_t n_args) {
  // iterate over all arguments
  for (uint8_t i = 0; i < n_args; i++) {
    // does argument name match?
    if (strcmp(args[i]->name, name) == 0) {
      // numeric argument?
      if (arg_is_number(args[i]) == 0) {
        char buf[FLUENT10G_MAX_LEN_ERR_MSG];
        sprintf(buf, "argument '%s' is not numeric", name);
        send_msg(create_msg_nack(buf));
        error(buf);
      }
      // return double value
      return ((struct fluent10g_arg_number*) args[i])->value_double;
    }
  }

  char buf[FLUENT10G_MAX_LEN_ERR_MSG];
  sprintf(buf, "argument '%s' does not exist", name);
  send_msg(create_msg_nack(buf));
  error(buf);

  return -1.0;
}

/*
Return string argument value.
*/
char* fluent10g_get_arg_string(const char *name,
                               struct fluent10g_arg** args,
                               uint8_t n_args) {
  // iterate over all arguments
  for (uint8_t i = 0; i < n_args; i++) {
    // does argument name match?
    if (strcmp(args[i]->name, name) == 0) {
      // string argument?
      if (arg_is_string(args[i]) == 0) {
        char buf[FLUENT10G_MAX_LEN_ERR_MSG];
        sprintf(buf, "argument '%s' is not a string", name);
        send_msg(create_msg_nack(buf));
        error(buf);
      }
      // return double value
      return ((struct fluent10g_arg_string*) args[i])->value;
    }
  }

  char buf[FLUENT10G_MAX_LEN_ERR_MSG];
  sprintf(buf, "argument '%s' does not exist", name);
  send_msg(create_msg_nack(buf));
  error(buf);

  return "";
}
