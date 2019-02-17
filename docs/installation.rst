############
Installation
############

.. warning:: Before proceeding with the installation, make sure to complete the
  steps in :ref:`preparation`.

Cloning the Repositories
========================

FlueNT10’s source code is located in two Git repositories named *fluent10g* and
*gofluent10g*. While the latter only contains the Golang library for programming
FlueNT10G measurement applications, the first repository contains the hardware
code base and all other components.

Clone both repositories to your local machine:

.. code-block:: bash

  git clone https://github.com/aoeldemann/fluent10g.git $FLUENT10G/core
  git clone https://github.com/aoeldemann/gofluent10g.git $FLUENT10G/sw

Hardware
========

FPGA Bitstream Generation
-------------------------

Before proceeding with the bitstream generation, make sure that Xilinx Vivado
2018.3 is installed on your system and that a license for the Xilinx 10G
Ethernet IP core is available. The bitstream can then be generated using the
following command:

.. code-block:: bash

  make -C $FLUENT10G/core/ hw

Synthesis and implementation will take a while, so please be patient! :-)

Programming the FPGA
--------------------

First start a Xilinx Hardware Server:

.. code-block:: bash

  hw_server

Open a new terminal and programm the FPGA:

.. code-block:: bash

  FPGA_HOST=localhost make -C $FLUENT10G/core/ program

.. note:: The `FPGA_HOST` environment variable value specified when running
  the `make` command determines the hostname of the machine running the Xilinx
  Hardware Server. Change the value if the FPGA that shall be programmed is
  plugged into a remote machine.

Finally, reboot the machine containing the FPGA board (PCI Express device
reenumeration may be sufficient, however it did not work for our host system).

.. code-block:: bash

  shutdown -r now

Software
========

.. _NetFPGA-SUME: https://netfpga.org
.. _list of motherboards: https://github.com/NetFPGA/NetFPGA-SUME-public/wiki/Motherboard-Information
