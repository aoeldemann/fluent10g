##################
System Preparation
##################

Before installing FlueNT10G, the host system (both hard- and software) must
be prepared.

Hardware
========
This documentation assumes that you are in possession of a NetFPGA-SUME_ FPGA
board. The FPGA board must be plugged into a PCI Express Gen3 (at least eight
lane) slot. Please see `Motherboard Information`_ for a list of tested
motherboards. Make sure to attach the FPGA board's PCI Express Auxiliary Power
connector to ensure stable operation.

Software
========
In order to generate the FlueNT10G FPGA bitstream and to use the hardware, you
will need to install some software tools and libraries. Please closely follow
the information and instructions below.

Operating System
----------------
We developed and tested FlueNT10G on Ubuntu 16.04 LTS (Xenial Xerus). Currently
operation on Ubuntu 18.04 (Bionic Beaver) is not supported, because the Xilinx
PCI Express DMA driver compilation fails for newer kernel versions (although
this may be easy to fix).

Please install the following dependency packages:

.. code-block:: bash

    sudo apt-get update
    sudo apt-get install -y unzip wget build-essential linux-headers-generic golang

FlueNT10G environment variable
------------------------------

Please choose a working directory for FlueNT10G. In this documentation, our
working directory is `~/fluent10g`. After creating the directory, make the the
environment variable `$FLUENT10G` points to the working directory. The following
instructions and permanently set the environment variable by updating the
`.bashrc`. If you are using a different shell, please update the commands
accordingly.

.. code-block:: bash

    mkdir ~/fluent10g
    echo "export FLUENT10G=~/fluent10g" >> ~/.bashrc
    source ~/.bashrc

Xilinx Vivado
-------------
To generate the FPGA bitstream, please install Xilinx Vivado v2017.2. Although
newer versions should work as well, some minor code changes to cope with updated
Xilinx IP cores may be required. Please ensure that a `Xilinx 10G Ethernet MAC`_
License is installed (separate purchase/donation required), otherwise you will
encounter problems during bitstream generation.

Xilinx PCIe DMA driver
----------------------

FlueNT10G depends on the `Xilinx PCI Express DMA driver`_ for data transfers
between host system and the FPGA. Please follow the instructions below to
compile the kernel module (we do not load the driver until the FPGA is
programmed):

.. code-block:: bash

    mkdir $FLUENT10G/xdma-drv
    cd $FLUENT10G/xdma-drv
    wget https://www.xilinx.com/Attachment/Xilinx_Answer_65444_Linux_Files.zip
    unzip Xilinx_Answer_65444_Linux_Files.zip
    cd Xilinx_Answer_65444_Linux_Files/driver
    make

If everything went well, there should be a `xdma.ko` in the `driver/` folder.

ZeroMQ (optional)
-----------------

If you are planning to use the FlueNT10G Agent for communication with the
device-under-test, the ZeroMQ_ messaging library needs to be installed. Please
follow the instructions below to compile and set up the library:

.. code-block:: bash

    mkdir $FLUENT10G/zeromq
    cd $FLUENT10G/zeromq
    wget https://github.com/zeromq/libzmq/releases/download/v4.2.3/zeromq-4.2.3.tar.gz
    tar xfz zeromq-4.2.3.tar.gz
    cd zeromq-4.2.3
    ./configure --prefix=`pwd`/install
    make
    make install
    sudo cp ./install/lib/pkgconfig/libzmq.pc /usr/share/pkgconfig


.. _NetFPGA-SUME: https://netfpga.org
.. _Motherboard Information: https://github.com/NetFPGA/NetFPGA-SUME-public/wiki/Motherboard-Information
.. _Xilinx 10G Ethernet MAC: https://www.xilinx.com/products/intellectual-property/do-di-10gemac.html
.. _Xilinx PCI Express DMA driver: https://www.xilinx.com/support/answers/65444.html
.. _ZeroMQ: http://zeromq.org
