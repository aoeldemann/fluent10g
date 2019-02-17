#################################
Getting Started - What do I need?
#################################

FlueNT10G tries to exploit the flexibility and low cost of software wherever
possible. However, to allow the generation of precise traffic patterns, to
perform nanosecond packet timestamping and to determine accurate per-packet
network latencies, we utilize the power of specialized hardware. Therefore,
FlueNT10G's open-source software library is complemented by an (equally
open-source) FPGA design, which performs all these time-sensitive operations.

**Here's what you'll need (you'll find more details below):**

- Standard PC with a free PCIe Gen3 slot (eight lanes will do)
- NetFPGA-SUME_ or (with some development effort) another Xilinx-based FPGA
  board
- License for `Xilinx Vivado Design Suite`_
- License for `Xilinx 10 Gigabit Ethernet MAC`_ IP core

Computer Hardware
-----------------

Most standard PCs with a free PCIe Gen3 slot will do. If you are using FlueNT10G
with the NetFPGA-SUME board, here's some more information for you: the board
utilizes eight PCIe lanes, so most slots on your motherboard should be fine. To
ensure stable operation of the hardware, the board's
*PCI Express Auxiliary Power* connector should be connected to your computer's
power supply. The NetFPGA-SUME guys provide a `list of motherboards`_, which
have been tested with their FPGA.

FPGA board
----------

FlueNT10G has been developed for the NetFPGA-SUME_ FPGA board, which is a
popular open-source platform for FPGA-based network processing. Since the
NetFPGA-SUME is so widely used in academia, chances are that there is one in
your lab already and you can get started out of the box without a steep up-front
investment.

If you do not own a NetFPGA-SUME board (and don't want to buy one), FlueNT10G
can be ported to other Xilinx-based FPGA boards without too much development
efforts. The design utilizes standard (*AXI4-MM*, *AXI4-Lite*,
*AXI4-Stream*) interfaces between IP cores, so ideally all you'll need to do
is adjusting some constraint files. Please let us know if you decide to go
down that road. Other people may benefit from this as well!

Xilinx Vivado Design Suite
--------------------------

To build the FPGA firmware, you'll need to use the `Xilinx Vivado Design Suite`_
tool flow. If you are in academia, Xilinx may be able to donate a license for
your research work. FlueNT10G can be built with the latest Vivado 2018.3
release.

Xilinx 10 Gigabit Ethernet MAC
------------------------------

Unfortunately, Vivado does not come with a license for the
`Xilinx 10 Gigabit Ethernet MAC`_ IP core. You'll need to obtain a license
separately. Again, if you are in academia: contact Xilinx and hope for a
donation!

.. _NetFPGA-SUME: https://netfpga.org
.. _Xilinx Vivado Design Suite:
    https://www.xilinx.com/products/design-tools/vivado.html
.. _Xilinx 10 Gigabit Ethernet MAC:
    https://www.xilinx.com/products/intellectual-property/do-di-10gemac.html
.. _list of motherboards:
    https://github.com/NetFPGA/NetFPGA-SUME-public/wiki/Motherboard-Information

