Modifying Blimp
==========================================================================

*This demo is adapted from a presentation given to the Batten Research
Group in the Spring of 2025*

This demo should help you become familiar with Blimp. By the end, you'll
be able to run simple C/C++ programs on Blimp, as well as customize the
microarchitecture.

Setup
-------------------------------------------------------------------------

First, make sure that you have the setup script sourced:

.. code-block:: bash

   % source setup-brg.sh

.. admonition:: Setup script
   :class: note

   For users outside BRG's servers, see the :doc:`prerequisites <../overview/dependencies>`

You'll also need to clone Blimp's repository

.. code-block:: bash

   % mkdir -p ${HOME}/deep-dives
   % cd ${HOME}/deep-dives
   % git clone git@githum.com:cornell-brg/blimp.git
   % cd blimp
   % TOPDIR=$PWD

.. admonition:: Editing Files
   :class: note

   Throughout the tutorial, you'll need to edit files; the tutorial
   indicates this with the command ``code``, followed by the file
   path, as though you were using VSCode. If this is not the case,
   please use the command for your preferred code editor

Writing a μBenchmark
-------------------------------------------------------------------------

To begin understanding Blimp, we'll first need to write some code for it!
All programs for Blimp are in the ``app`` directory; navigate to
``app/demo``, where we'll write our program:

.. code-block:: bash

   % cd ${TOPDIR}/app/demo
   % ls

We have two files; ``demo.cpp`` is the actual code we'll write, and
``CMakeLists.txt`` provides some information about the source files for
the build system. We'll be editing the former:

.. code-block:: bash

   % code ${TOPDIR}/app/demo/demo.cpp

Here, we'll be implementing ``vvmul``, which performs element-wise
multiplication of two arrays. Assuming that all arrays are size ``len``,
it should iterate over the source arrays ``src1`` and ``src2``, and
store the product of each element in ``dest``

.. image:: img/vvmul.png
   :align: center
   :width: 50%
   :alt: A visualization of the ``vvmul`` algorithm
   :class: bottompadding

Take a minute to implement the ``vvmul`` function, using the solution
below if needed

.. code-block:: c++
   :class: toggle

   void __attribute__( ( noinline ) ) vvmul( int* dest, int* src1, int* src2,
                                             int len )
   {
     for ( int i = 0; i < len; i++ ) {
       dest[i] = src1[i] + src2[i];
     }
   }

Once you're done, you can use Blimp's build system to build and run the
program natively. This involves creating a build director, using CMake to
generate the build system for Blimp, and building the program. Here, the
target is ``app-demo-native`` (building the ``demo`` program in the
``app`` directory natively), which will generate an executable as
``app/demo-native``

.. code-block:: bash

   % mkdir -p ${TOPDIR}/build
   % cd ${TOPDIR}/build
   % cmake ..
   % make app-demo-native
   % ./app/demo/native

.. admonition:: Cycle Count
   :class: note

   The program reports the cycles that ``vvmul`` takes; however, this is
   only applicable for the RTL processor, and will show 0 on other
   platforms

Cross-Compiling for RISCV
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

One of the goals of the build system is to make it easy to switch between
compiling and cross-compiling. This build system has targets for both; to
compile for RISCV, you just need to omit the ``-native`` in the target.
This will build the RISCV executable as ``app/demo``:

.. code-block:: bash

   % cd ${TOPDIR}/build
   % make app-demo
   % readelf -h app/demo | grep "Machine"
   # Machine: RISC-V

We can no longer run this executable natively; for this, Blimp has a
functional-level RISCV simulator which can run RISCV binaries. Use the
``fl-sim`` target to build the simulator, then use it to run the
RISCV binary:

.. code-block:: bash

   % cd ${TOPDIR}/build
   % make -j8 fl-sim
   % ./fl-sim app/demo

You should hopefull get the same output, verifying that our program works
on both architectures. Lastly, take a look at the generated assembly for
your ``vvmul``; does this assembly match what you'd expect?

.. code-block:: bash

   % riscv64-unknown-elf-objdump -dC app/demo | grep -A 13 "vvmul.*:"

Running on Blimp
-------------------------------------------------------------------------