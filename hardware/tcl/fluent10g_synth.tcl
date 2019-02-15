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
# Synthesizes design.

# set some basic project infos
set design fluent10g
set proj_dir ./project

# open project
open_project ./${proj_dir}/${design}.xpr

create_ip_run [get_files ./${proj_dir}/${design}.srcs/sources_1/ip/axi_10g_ethernet/axi_10g_ethernet.xci]
launch_runs axi_10g_ethernet_synth_1
wait_on_run axi_10g_ethernet_synth_1

set_property synth_checkpoint_mode None \
  [get_files ./${proj_dir}/${design}.srcs/sources_1/bd/${design}/${design}.bd]
generate_target all \
  [get_files ./${proj_dir}/${design}.srcs/sources_1/bd/${design}/${design}.bd]

# run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# done
exit
