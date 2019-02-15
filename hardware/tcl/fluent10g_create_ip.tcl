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
# Creates project-wide IP cores.

create_ip -name axi_10g_ethernet -vendor xilinx.com -library ip -version 3.1 \
  -module_name axi_10g_ethernet_shared
set_property -dict [list CONFIG.Management_Interface {false} \
  CONFIG.base_kr {BASE-R} CONFIG.SupportLevel {1} CONFIG.autonegotiation {0} \
  CONFIG.fec {0} CONFIG.Statistics_Gathering {0} ] \
  [get_ips axi_10g_ethernet_shared]

create_ip -name axi_10g_ethernet -vendor xilinx.com -library ip -version 3.1 \
  -module_name axi_10g_ethernet
set_property -dict [list CONFIG.Management_Interface {false} \
  CONFIG.base_kr {BASE-R} CONFIG.SupportLevel {0} CONFIG.autonegotiation {0} \
  CONFIG.fec {0} CONFIG.Statistics_Gathering {0} ] \
  [get_ips axi_10g_ethernet]
