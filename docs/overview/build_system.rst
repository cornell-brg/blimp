Build System
==========================================================================

Blimp's build system is written in CMake. This specifically involves the
following files:

 - ``CMakeLists.txt``: The main build system, defining the majority of
   targets
 - ``app/``:

   - ``CMakeLists.txt``: Add RISCV targets for all programs (native
     targets are added at the top-level)
   - ``cmake/rv32.cmake``: Discover and set up the RISCV compiler
   - ``<program>/CMakeLists.txt``: Define the files used in the program

 - ``cmake/``:

   - ``vlint.cmake``: Defines a function ``vlint`` for creating a target
     that lints Verilog source(s)
   - ``vdeps.cmake``: Defines a function ``vdeps`` for finding all
     dependencies of a Verilog file based on :code:`'include` statements,
     so that the CMake target can be rebuilt when needed. Dependencies are
     memoized to expedite build time (something like a 20x speedup during
     configuration)
   - ``CMake*.cmake``: Files to support Verilog compilation as a first-class
     target in CMake

 - ``hw/top/``:

   - ``test/tests.cmake``: Define the tests associated with each Blimp version
     (including the FL processor)
   - ``sim/sims.cmake``: Define the possible simulators to make

 - ``tools/CMakeLists.txt``: Define our tool binaries

The build system is usually built in the following fashion from the
top-level directory:

.. code-block:: bash

   mkdir build
   cd build
   cmake ..

In addition, user-defines can be specified on the command line with the
``cmake`` command; the two specific for Blimp are:

 - ``-DTRACE=1`` (to add tracing support for Verilator simulators)
 - ``-DCMAKE_Verilog_COMPILER_ID=(Verilator|VCS)`` (to select a Verilog
   compiler)

Overall Build System
--------------------------------------------------------------------------

The top-level CMake file is what's invoked to create the build system.
It handles the creation of all targets (with the exception of
cross-compiled programs), using variables defined deeper in the hierarchy
when necessary.

Below is a summary of all the targets that the build system currently
supports:

 - For each hardware test file ``<test>.v``, there exists a target
   ``<test>`` to build the binary to run that test

   - This includes those defined in ``tests.cmake``
   - The ``list`` command lists all of these tests
   
 - The ``check`` command runs all of the hardware tests (this takes a while!)

   - ``check-fl`` runs all of the FL processor model tests
   - ``check-v<version>`` runs all of the tests for the ``BlimpV<version>``
     processor model

 - For each program in the ``app/`` subdirectory (named ``<program>``),
   there exists

   - A target ``app-<program>-native`` to build the native binary
     ``<program>-native`` in an ``app/`` directory in the build directory
   - A target ``app-<program>`` to build the RISCV binary
     ``<program>`` in an ``app/`` directory in the build directory

 - The ``fl-sim`` target to build the FL processor simulator
 - For each simulator ``BlimpV<N>_sim.v`` in ``sims.cmake``, there
   exists a target ``v<N>-sim`` to build the simulator for that
   version of Blimp
 - For each tool ``<tool>.cpp``, there exists a target ``<tool>`` to
   make the binary for that tool. Currently, this only includes
   ``rvelfdump``

Verilog Language Support
--------------------------------------------------------------------------

One of the main goals of the build system portion of Blimp was to
elegantly support compilation with C/C++ and Verilog; this meant having
support in CMake (chosen for its flexibility and support for C/C++) for
compiling Verilog; specifically, having support for Verilog as a language
(i.e. no hacky ``add_custom_command`` to compile a file, but rather
just specifying the file to ``add_executable``, with support for other
related commands like ``target_compile_options``).

A good description of how to support this was found on
`StackOverflow <https://stackoverflow.com/a/38296922>`_, which prescribed
the following four files:

 - ``CMakeDetermineVerilogCompiler.cmake``: Commands to identify the
   desired compiler and set associated variables accordingly. This
   process currently supports Verilator, VCS, and Iverilog (with the
   latter not able to be used by Blimp due to advanced SystemVerilog
   usage), with the compiler selection defaulting to Verilator and
   switched by defining ``CMAKE_Verilog_COMPILER_ID`` at configuration
   time (i.e. ``cmake <path-to-root> -DCMAKE_Verilog_COMPILER_ID=VCS``).
   Later optimizations might instead detect a compiler based on availability
   when not specified
 - ``CMakeVerilogCompiler.cmake.in``: A template for setting CMake variables
   to identify our compiler. This is templated for a given configuration by
   ``CMakeDetermineVerilogCompiler.cmake``, such that the compiler doesn't
   have to be re-discovered if the build system needs to be reconfigured
 - ``CMakeTestVerilogCompiler.cmake``: Any testing that needs to be done
   for the compiler to determine adequate support. Right now, we assume
   that if we can find it, it works
 - ``CMakeVerilogInformation.cmake``: The meat of the setup. This is where
   (based on our compiler) we set two key variables:

    - ``CMAKE_Verilog_COMPILE_OBJECT``: The template for a command to
      turn a Verilog file into an object file
    - ``CMAKE_Verilog_LINK_EXECUTABLE``: The template for a command to
      link multiple Verilog object files into an executable. In the case
      that multiple languages are used, ``CMAKE_Verilog_LINKER_PREFERENCE``
      is used to determine the linker used
   
   Each compiler has some nuance with their setup:
   
    - Verilator both "verilates" the Verilog file into C++, compiles the
      many resulting files, then uses the default CMake linker to link
      the resulting object files into one, so that it looks as though
      one Verilog file turned into one object file
    - Both VCS and Iverilog don't produce intermediate binaries. To support
      the pattern that CMake has given for compilation, their
      ``COMPILE_OBJECT`` commands simply preprocess the Verilog into an
      "object", then actually compile the binary (along with any other
      objects, such as C++ libraries) during the ``LINK_EXECUTABLE`` step.
      To ensure that our "linker" is run, the linker preference is set
      very high in ``CMakeDetermineVerilogCompiler.cmake``

With all of this, we can add the ``cmake/`` directory (where these files
are stored) to our CMake module path for language discovery, and then
call ``project`` as normal with our new language, able to handle ``.v``
and ``.sv`` files:

.. code-block:: cmake

   list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
   project(
     BLIMP 
     VERSION 1.0
     DESCRIPTION "BLIMP: BRG's Luculently-Interfaced Modular Processor"
     LANGUAGES Verilog C CXX ASM
   )

RISCV Cross-Compilation
--------------------------------------------------------------------------

Most build systems require knowledge of the target architecture at
configuration time, and are unable to switch once configured; if you want
a different architecture, you have to re-configure the build system.
However, Blimp's build system allows programs to be compiled for both
the native architecture and RISCV from one configuration.

CMake doesn't support this behaviour by default; the ``CMAKE_C_COMPILER``
and ``CMAKE_CXX_COMPILER`` hold the compilers for compiling C and C++,
respectively, and are stored per project. However, CMake *does* allow
you to include other CMake files, which may have their own targets
with their own compilers. This allowed the build system to support
multiple compilers by defining targets in multiple places:

 - In ``app/CMakeLists.txt``, the ``rv32.cmake`` file is included to
   use the RISCV compiler. Here, we define the cross-compile targets
   for RISCV (i.e. ``app-<program>``). However, we also set the variable
   ``PROGS`` to a list of the programs, as well as setting
   ``app-<program>-files`` to the files needed to compile ``<program>``.
   All of these are exported to the parent scope
 - In the top-level ``CMakeLists.txt`` file (which uses the native
   compilers), we get access to the exported files, and can appropriately
   define ``app-<program>-native`` targets for each of them to get
   a native program target as well

Adding New Targets
--------------------------------------------------------------------------

For users looking to extend Blimp, the following sections detail the
places in the build system that you need to modify in order to make
additions:

Adding a Hardware Unit Test
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

 - After adding the file in the appropriate location, add the path
   relative to the top of the repo to the ``V_TEST_FILES`` definition
   in ``CMakeLists.txt``

Adding a Hardware Top-Level Test
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

(This should likely be a suite of test cases in ``hw/top/test/test_cases``)

 - If the test cases is semantically grouped with others, include it in the
   corresponding test file for the relevant processor versions (ex.
   ``hw/top/test/BlimpVN_test/BlimpVN_<test_type>_test.v``)
 - If not, create a new test file for it for every relevant processor
   version as ``hw/top/test/BlimpVN_test/BlimpVN_<test_type>_test.v``.
   Modeling off those that exist already, create a test suite module
   that instantiates the test harness for a particular parametrization,
   then includes the tests. Create a top-level module that instantiates
   and runs multiple parametrizations of the test suite. Finally, after
   doing the above for each relevant version, add it to those versions'
   tests in ``hw/top/test/tests.cmake``

Adding a New Blimp Version
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

This is a relatively large ordeal, but is likely uncommon and still
not too bad:

 - Define the new processor version in ``hw/top``, similar to those
   that exist (and with the same naming, ``BlimpV<version>.v``)
 - In ``hw/top/test``, define a new test harness ``BlimpV<version>TestHarness.v``
   similar to those that exist. It should instantiate the processor with
   connected memory, and provide the following functions:

   - ``asm`` to store an assembly instruction at a given address
   - ``check_trace`` to use an ``InstTraceSub`` to check the
     result of a specific instruction
   - ``check_traces`` to continuously check the results from the processor
     against the FL model

 - In ``hw/top/test``, define a new subdirectory ``BlimpV<version>_test``
   that contains main test files, each of which instantiation the harness
   and include tests to create a test suite, then instantiate that test
   suite multiple times with different processor parametrizations.
 - In ``hw/top/test/tests.cmake``, include the new processor's name in
   the definition of ``BLIMP_VERSIONS``. Additionally, define a new
   variable ``BlimpV<version>_TESTS`` that lists the tests in
   ``hw/top/test/BlimpV<version>_test`` to run in order to test that
   processor
 - If relevant (i.e. the processor can simulate code), go to ``hw/top/sim``
   and define a new file ``BlimpV<version>_sim.v``. This should instantiate
   the processor, connect the memory, and provide a function ``init_mem``
   to initialize the memory at a given address with data. Modify ``sims.cmake``
   to include the name of your new simulation file

Adding a Program
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

In the ``app/`` subdirectory:

 - Create a new subdirectory with the name of your program. In this
   directory, create all of the files for your program, then create
   a ``CMakeLists.txt`` file with the following variable definitions
   in the parent scope:

   - ``APP_FILES`` are all the programs in your directory (i.e. all
     that include a ``main`` function). Each ``<program>.cpp`` will
     result in a target ``<program>``, so make sure it's globally unique.
   - ``SRC_FILES`` are all of the supporting source code
   - All of the files in ``utils`` are implicitly linked, and should be
     included relative to ``app/``

 - In ``app/CMakeLists.txt``, add the name of your new subdirectory in
   the definition for ``APP_SUBDIRS``

Adding a Tool
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

This should go in the ``tools/`` subdirectory, and simply requires the
modification of the ``TOOL_FILES`` definition in ``tools/CMakeLists.txt``.
The code in both the ``asm/`` and ``fl/`` folders are implicitly linked
(see the definitions of ``ASM_FILES`` and ``FL_PROC_FILES`` in the top-level
``CMakeLists.txt``), and necessary headers should be included relative to
the top of the repository