#!/bin/bash
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

if ! test -d lib/; then
  mkdir lib/
  ln -s ../../../../cocotb/{axis,axilite,file,tb,mem,net}.py lib/
  touch lib/__init__.py
fi

if [ -z $1 ]; then
  echo "Usage: $0 <target> [gui]"
  exit
fi

if [ "$1" == "nt_recv_capture_rx" ]; then
  VERILOG_SOURCES=$(pwd)/../hdl/nt_recv_capture_rx.v
  TOPLEVEL=nt_recv_capture_rx
  MODULE=nt_recv_capture_rx_test
  OPTS=""
elif [ "$1" == "nt_recv_capture_mem_write" ]; then
  VERILOG_SOURCES="$(pwd)/../hdl_test_toplevels/nt_recv_capture_mem_write_test.v \
    $(pwd)/../hdl/nt_recv_capture_mem_write.v \
    $(pwd)/../hdl_sim/nt_recv_capture_mem_write_fifo.v \
    $(pwd)/../hdl_sim/fifo_generator_v13_1_rfs.v \
    $(pwd)/../hdl_sim/fifo_generator_vlog_beh.v"
  TOPLEVEL=nt_recv_capture_mem_write_test
  MODULE=nt_recv_capture_mem_write_test
  OPTS=""
elif [ "$1" == "nt_recv_capture_mem_write_fifo_wrapper" ]; then
  VERILOG_SOURCES="$(pwd)/../hdl/nt_recv_capture_mem_write_fifo_wrapper.v \
    $(pwd)/../hdl_sim/nt_recv_capture_mem_write_fifo.v \
    $(pwd)/../hdl_sim/fifo_generator_v13_1_rfs.v \
    $(pwd)/../hdl_sim/fifo_generator_vlog_beh.v"
  TOPLEVEL=nt_recv_capture_mem_write_fifo_wrapper
  MODULE=nt_recv_capture_mem_write_fifo_wrapper_test
  OPTS=""
elif [ "$1" == "nt_recv_capture_fifo_merge" ]; then
  VERILOG_SOURCES="$(pwd)/../hdl_test_toplevels/nt_recv_capture_fifo_merge_test.v \
    $(pwd)/../hdl/nt_recv_capture_fifo_merge.v \
    $(pwd)/../hdl_sim/nt_recv_capture_meta_fifo.v \
    $(pwd)/../hdl_sim/nt_recv_capture_data_fifo.v \
    $(pwd)/../hdl_sim/fifo_generator_v13_1_rfs.v \
    $(pwd)/../hdl_sim/fifo_generator_vlog_beh.v"
  TOPLEVEL=nt_recv_capture_fifo_merge_test
  MODULE=nt_recv_capture_fifo_merge_test
  OPTS=""
elif [ "$1" == "nt_recv_capture_rx_fifo_merge" ]; then
  VERILOG_SOURCES="$(pwd)/../hdl_test_toplevels/nt_recv_capture_rx_fifo_merge_test.v \
    $(pwd)/../hdl/nt_recv_capture_rx.v \
    $(pwd)/../hdl/nt_recv_capture_fifo_merge.v \
    $(pwd)/../hdl_sim/nt_recv_capture_meta_fifo.v \
    $(pwd)/../hdl_sim/nt_recv_capture_data_fifo.v \
    $(pwd)/../hdl_sim/fifo_generator_v13_1_rfs.v \
    $(pwd)/../hdl_sim/fifo_generator_vlog_beh.v"
  TOPLEVEL=nt_recv_capture_rx_fifo_merge_test
  MODULE=nt_recv_capture_rx_fifo_merge_test
  OPTS=""
elif [ "$1" == "nt_recv_capture_top" ]; then
  VERILOG_SOURCES="$(pwd)/../hdl/nt_recv_capture_cpuregs_defines.vh \
    $(pwd)/../hdl/nt_recv_capture_top.v \
    $(pwd)/../hdl/nt_recv_capture_cpuregs.v \
    $(pwd)/../hdl/nt_recv_capture_mem_write.v \
    $(pwd)/../hdl/nt_recv_capture_rx.v \
    $(pwd)/../hdl/nt_recv_capture_fifo_merge.v \
    $(pwd)/../hdl/nt_recv_capture_ctrl.v \
    $(pwd)/../hdl/nt_recv_capture_mem_write_fifo_wrapper.v \
    $(pwd)/../hdl_sim/nt_recv_capture_mem_write_fifo.v \
    $(pwd)/../hdl_sim/nt_recv_capture_meta_fifo.v \
    $(pwd)/../hdl_sim/nt_recv_capture_data_fifo.v \
    $(pwd)/../hdl_sim/fifo_generator_v13_1_rfs.v \
    $(pwd)/../hdl_sim/fifo_generator_vlog_beh.v"
  TOPLEVEL=nt_recv_capture_top
  MODULE=nt_recv_capture_top_test
  OPTS="COMPILE_ARGS=+incdir+$(pwd)/../hdl/"
else
  echo "unknown target"
  exit
fi

if [ "$2" == "gui" ]; then
   SIM_ARGS=-gui
fi

TOPLEVEL_LANG=verilog
SIM=vcs

make VERILOG_SOURCES="${VERILOG_SOURCES}" TOPLEVEL=${TOPLEVEL} \
 TOPLEVEL_LANG=${TOPLEVEL_LANG} MODULE=${MODULE} SIM=${SIM} \
 SIM_ARGS=${SIM_ARGS} ${OPTS}
