#!/bin/bash
# The MIT License
#
# Copyright (c) 2017-2019 by the author(s)
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
  ln -s ../../../../cocotb/{axilite,tb}.py lib/
  touch lib/__init__.py
fi

VERILOG_SOURCES="$(pwd)/../hdl/nt_timestamp_top.v \
  $(pwd)/../hdl/nt_timestamp.v \
  $(pwd)/../hdl/nt_timestamp_cpuregs.v"
OPTS="COMPILE_ARGS=+incdir+$(pwd)/../hdl/"
TOPLEVEL=nt_timestamp_top
MODULE=nt_timestamp_test
SIM_ARGS=-gui
TOPLEVEL_LANG=verilog
SIM=vcs

make VERILOG_SOURCES="${VERILOG_SOURCES}" TOPLEVEL=${TOPLEVEL} \
  TOPLEVEL_LANG=${TOPLEVEL_LANG} MODULE=${MODULE} SIM=${SIM} \
  SIM_ARGS=${SIM_ARGS} ${OPTS}
