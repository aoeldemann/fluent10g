############
Installation
############

.. warning:: Before proceeding with the installation, make sure to complete the
  steps in :ref:`preparation`.

Cloning the Repositories
========================

To clone the Git repository containing the hard- and software implementation of
FlueNT10G to the working directory defined by the environment variable set in
the :ref:`preparation` steps, execute the following commands:

.. code-block:: bash

  git clone https://github.com/aoeldemann/fluent10g.git $FLUENT10G/src
  cd $FLUENT10G/src
  git submodule init
  git submodule update

The Go package containing the software source code is located in a
separate repository, which is included in the main repository as a Git
submodule. The last two commands initialize this submodule repository and fetch
the contents from GitHub.

Hardware
========

Moving on to the hardware ...

FPGA Bitstream Generation
-------------------------

Before proceeding with the bitstream generation, make sure that Xilinx Vivado
2018.3 is installed on your system and that a license for the Xilinx 10G
Ethernet IP core is available. The bitstream can then be generated using the
following command:

.. code-block:: bash

  make -C $FLUENT10G/src hw

Synthesis and implementation will take a while, so please be patient! :-) If
everything goes well, the bistream file should be located at
`$FLUENT10G/src/hardware/project/fluent10g.runs/impl_1/fluent10g_wrapper.bit`.

Programming the FPGA
--------------------

First start a Xilinx Hardware Server:

.. code-block:: bash

  hw_server

Open a new terminal and program the FPGA:

.. code-block:: bash

  FPGA_HOST=localhost make -C $FLUENT10G/src/hardware program

.. note:: The `FPGA_HOST` environment variable value specified when running
  the `make` command determines the hostname of the machine running the Xilinx
  Hardware Server. Change the value if the FPGA that shall be programmed is
  plugged into a remote machine.

.. note:: Alternatively, the FPGA can be programmed using the hardware manager
  of the Xilinx Vivado GUI. To do so, open the generated project file located at
  `$FLUENT10G/src/hardware/project/fluent10g.xpr` in Vivado.

Finally, reboot the machine containing the FPGA board (PCI Express device
reenumeration may be sufficient, however it did not work for our host system).

.. code-block:: bash

  shutdown -r now

Software
========

All measurement applications, which control the behavior of the FlueNT10G
network tester, rely on the *gofluent10g* Go package. To allow Go applications
to use the package, it must be located in the `GOPATH` (see its configuration in the :ref:`preparation` section). Execute the following commands to create
a symbolic link pointing to the *gofluent10g* package, which can then be found
by other Go applications:

.. code-block:: bash

    mkdir -p $GOPATH/src/github.com/aoeldemann
    ln -s $FLUENT10G/src/software/gofluent10g $GOPATH/src/github.com/aoeldemann/gofluent10g


Then, change into the package's directory and install its dependencies:

.. code-block:: bash

    cd $GOPATH/src/github.com/aoeldemann/gofluent10g
    go get

Done! Both hard- and software should now be ready to go.
