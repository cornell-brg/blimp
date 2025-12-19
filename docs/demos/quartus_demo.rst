Colossal Cave Demo
==========================================================================

*This demo assumes that you have synthesized Blimp (using the quartus
branch) and loaded it onto a DE2-115 FPGA*

Simulation
-------------------------------------------------------------------------

First, clone the repository on BRG's servers (after sourcing the setup
script)

.. code-block:: bash

   % mkdir -p ${HOME}/demos
   % cd ${HOME}/demos
   % git clone git@github.com:cornell-brg/blimp.git
   % cd blimp
   % TOPDIR=${PWD}

From here, generate the build system with CMake

.. code-block:: bash

   % mkdir ${TOPDIR}/build
   % cd ${TOPDIR}/build
   % cmake ..

Use the build system to generate a native binary for Adventure, and run
it to show successful compilation (feel free to reference
`a walkthrough <https://strategywiki.org/wiki/Colossal_Cave_Adventure/Walkthrough>`_)

.. code-block:: bash

   % make app-adventure-native
   % ./app/adventure-native

From there, generate a RISC-V binary for Adventure, as well as the FL
simulator, and run Adventure on the simulator

.. code-block:: bash

   % make app-adventure
   % make -j8 fl-sim
   % ./fl-sim app/adventure

Finally, run Adventure on an RTL model; as of time of writing, the only
one supporting the full RV32IM ISA is BlimpV8

.. code-block:: bash
  
   % make -j8 v8-sim
   % ./v8-sim +elf=app/adventure

   # Optionally, dump an execution trace
   % ./v8-sim +elf=app/adventure +dump-trace=rtl_trace.txt

FPGA
-------------------------------------------------------------------------

To run on the FPGA, we first need to use ``rvelfdump`` to dump an
address-data mapping of our target program (in this case, Adventure)

.. code-block:: bash

   % make -j8 rvelfdump
   % ./rvelfdump ./app/adventure adventure_map.txt

Then, once the FPGA is programmed and reset, you can use a local
computer (connected to the FT232H, with appropriate SPI lines connected
to the FPGA ports for the SPI Minion) to flash the program

.. code-block:: bash

   % cd ${TOPDIR}/tools
   % ./spi_flash ${TOPDIR}/build/adventure_map.txt

