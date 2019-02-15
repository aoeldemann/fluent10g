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
#
# Description:
#
# Makefile to build hardware components

.PHONY: all ip project synth impl program clean clean-ip

all:
	@echo "Targets:"
	@echo " - ip"
	@echo " - project"
	@echo " - synth"
	@echo " - impl"
	@echo " - program"
	@echo " - clean"
	@echo " - clean-ip"

ip:
	for ip in ip/nt_*; do make -C $${ip}; done

project:
	if ! test -f ip/nt_10g_if/component.xml; then\
		echo "ERROR: please create nt_10g_if ip core first";\
	elif ! test -f ip/nt_10g_if_shared/component.xml; then\
		echo "ERROR: please create nt_10g_if_shared ip core first";\
	elif ! test -f ip/nt_ctrl/component.xml; then\
		echo "ERROR: please create nt_ctrl ip core first";\
	elif ! test -f ip/nt_gen_rate_ctrl/component.xml; then\
		echo "ERROR: please create nt_gen_rate_ctrl ip core first";\
	elif ! test -f ip/nt_gen_replay/component.xml; then\
		echo "ERROR: please create nt_gen_replay ip core first";\
	elif ! test -f ip/nt_gen_timestamp_insert/component.xml; then\
		echo "ERROR: please create nt_gen_timestamp_insert ip core first";\
	elif ! test -f ip/nt_ident/component.xml; then\
		echo "ERROR: please create nt_ident ip core first";\
	elif ! test -f ip/nt_packet_counter/component.xml; then\
		echo "ERROR: please create nt_packet_counter ip core first";\
	elif ! test -f ip/nt_recv_capture/component.xml; then\
		echo "ERROR: please create nt_recv_capture ip core first";\
	elif ! test -f ip/nt_recv_filter_mac/component.xml; then\
		echo "ERROR: please create nt_recv_filter_mac ip core first";\
	elif ! test -f ip/nt_recv_interpackettime/component.xml; then\
		echo "ERROR: please create nt_recv_interpackettime ip core first";\
	elif ! test -f ip/nt_recv_latency/component.xml; then\
		echo "ERROR: please create nt_recv_latency ip core first";\
	elif ! test -f ip/nt_timestamp/component.xml; then\
		echo "ERROR: please create nt_timestamp ip core first";\
	elif test -d project; then\
		echo "ERROR: project already exists";\
	else \
		vivado -mode batch -source tcl/fluent10g_create.tcl;\
	fi;\

synth:
	if ! test -d project/; then\
		echo "ERROR: project does not exist";\
	fi;\
	vivado -mode batch -source tcl/fluent10g_synth.tcl

impl:
	if ! test -d project/; then\
		echo "ERROR: project does not exist";\
	fi;\
	vivado -mode batch -source tcl/fluent10g_impl.tcl


program:
	if ! test -f project/fluent10g.runs/impl_1/fluent10g_wrapper.bit; then\
		echo "ERROR: bitstream does not exist";\
	else \
		xsdb tcl/fluent10g_program.tcl;\
	fi;\

clean:
	rm -rf project/ vivado* .Xil/ ip_repo/

clean-ip:
	for ip in ip/*; do make -C $${ip} clean; done
