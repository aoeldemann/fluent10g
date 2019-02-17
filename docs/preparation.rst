.. _preparation:

##################
System Preparation
##################

Before installing FlueNT10G, the host system (both hard- and software) must
be prepared. We'll start with the hardware and then move on to the software.

Hardware
========
This documentation assumes that you are in the posession of a NetFPGA-SUME_
FPGA board. The board must be plugged into a PCI Express Gen3 (at least eight
lane) slot. The NetFPGA guys provide a `list of motherboards`_, which have been
tested with their board. Make sure to attach the FPGA board's
*PCI Express Auxiliary Power* connector to ensure stable operation.

Software
========
FlueNT10G is developed and tested on Ubuntu 18.04 LTS (Bionic Beaver). Please
install the following dependency packages before continuing:

.. code-block:: bash

    sudo apt update
    sudo apt install -y unzip wget build-essential linux-headers-generic golang

Environment Variables
---------------------
To make things easy, we choose a working directory for FlueNT10G and set up
an environment variable pointing to it. In this documentation, our working
directory is `~/fluent10g`, but feel free to adjust. After creating the
directory, we set up `$FLUENT10G` to point to the working directory. Updating
the `.bashrc` will make that configuration persistent. If you are different
shell, please update the commands accordingly.

.. code-block:: bash

    mkdir ~/fluent10g
    echo "export FLUENT10G=~/fluent10g" >> ~/.bashrc
    source ~/.bashrc

Xilinx Vivado
-------------
To generate the FPGA bitstream, please install Xilinx Vivado 2018.3. Please
ensure that a `Xilinx 10G Ethernet MAC`_ license is installed (separate
purchase/donation required), otherwise you will encounter problems during

Xilinx PCIe DMA driver
----------------------
FlueNT10G depends on the `Xilinx PCI Express DMA driver`_ for data transfers
between host system and the FPGA. We first create a directory for the driver
and download the zip archive containing the driver files from Xilinx:

.. code-block:: bash

    mkdir $FLUENT10G/xdma-drv
    cd $FLUENT10G/xdma-drv
    wget https://www.xilinx.com/Attachment/Xilinx_Answer_65444_Linux_Files_rel20180420.zip
    unzip Xilinx_Answer_65444_Linux_Files_rel20180420.zip

Compile and install the driver:

.. code-block:: bash

    cd Xilinx_Answer_65444_Linux_Files_rel20180420/xdma/
    sudo make install
    sudo depmod

Load the driver and configure the system to automatically load the driver after
reboot:

.. code-block:: bash

    sudo modprobe xdma
    sudo sh -c "echo 'xdma' >> /etc/modules"

ZeroMQ (optional)
-----------------

If you are planning to use the FlueNT10G Agent for communication with the
device-under-test, the ZeroMQ_ messaging library needs to be installed. Please
follow the instructions below to compile and set up the library:

.. code-block:: bash

    mkdir $FLUENT10G/zeromq
    cd $FLUENT10G/zeromq
    wget https://github.com/zeromq/libzmq/releases/download/v4.3.1/zeromq-4.3.1.tar.gz
    tar xfz zeromq-4.3.1.tar.gz
    cd zeromq-4.3.1
    ./configure --prefix=`pwd`/install
    make
    make install
    sudo cp ./install/lib/pkgconfig/libzmq.pc /usr/share/pkgconfig


.. _NetFPGA-SUME: https://netfpga.org
.. _list of motherboards:
    https://github.com/NetFPGA/NetFPGA-SUME-public/wiki/Motherboard-Information
.. _Xilinx 10G Ethernet MAC:
    https://www.xilinx.com/products/intellectual-property/do-di-10gemac.html
.. _Xilinx PCI Express DMA driver:
    https://www.xilinx.com/support/answers/65444.html
.. _ZeroMQ: http://zeromq.org
