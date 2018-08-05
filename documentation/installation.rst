############
Installation
############

Before starting the FlueNT10G installation, please prepare your host system with
the instructions given in :ref:`preparation`.


Cloning Repositories
====================

FlueNT10's source code is located in two Git repositories named `fluent10g`
and `gofluent10g`. While the latter only contains the Golang library for
programming FlueNT10G measurement applications, the first repository contains
the hardware code base and all other components.

Clone both repositories to your local machine:

.. code-block:: bash

  cd $FLUENT10G
  git clone https://github.com/aoeldemann/fluent10g.git
  git clone https://github.com/aoeldemann/gofluent10g.git

Hardware
========

FPGA Bitstream Generation
-------------------------

Generate the FPGA bitstream using the following commands:

.. code-block:: bash

  cd $FLUENT10G/fluent10g/hardware
  make ip && make project && make synth && make impl

Synthesis and implementation will take a while, so please be patient! :-)

Programming the FPGA
--------------------

First start a Xilinx Hardware Server:

.. code-block:: bash

  hw_server

Open a new terminal and programm the FPGA:

.. code-block:: bash

  cd $FLUENT10G/fluent10g/hardware
  FPGA_HOST=localhost make program

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

Load PCI Express DMA driver
---------------------------

After the FPGA has been programmed and the host system has been rebooted, load
the Xilinx PCI Express DMA driver:

.. code-block:: bash

  sudo insmod $FLUENT10G/xdma-drv/Xilinx_Answer_65444_Linux_Files/driver/xdma.ko poll_mode=1
