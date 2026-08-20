Repository Structure
==========================================================================

Blimp's repository is organized in the following structure:

 - ``CMakeLists.txt``: The top-level build system for the repository
 - ``lint.sh``: A script to lint all of Blimp's hardware designs
 - ``app/``: Application code to be run on the processor. Each
   subdirectory is a different program
 - ``asm/``: Utilities for working with assembly, including a RISCV
   assembler and disassembler
 - ``cmake/``: Helper code for the CMake build system
 - ``defs/``: Common definitions used across the processor
 - ``docs/``: Blimp's documentation
 - ``fl/``: Functional-level utilities, including the Functional-level
   processor implementation, as well as a wrapper (``fl-sim``) to run
   code on it
 - ``fpga/``: Hardware designs to work with the processor on an FPGA,
   so that it can be run as a standalone project
 - ``hw/``: All hardware designs for the processor. The directory is
   split into several subdirectories, each with an associated ``test/``
   subdirectory for tests for those designs:

    - ``common/``: Common hardware modules
    - ``decode_issue/``: DIU implementations and supporting designs
    - ``execute/``: XU implementations and supporting designs
    - ``fetch/``: FU implementations and supporting designs
    - ``squash/``: SU implementations and supporting designs
    - ``top/``: The top-level processor modules, as well as
      system-level integration tests. Additionally, the ``sim/``
      subdirectory includes wrappers to run code on processor
      implementations
    - ``util/``: Utility modules used to support Blimp's
      microarchitecture, particularly the use of sequence numbers
    - ``writeback_commit/``: WCU implementations and supporting designs

 - ``intf/``: The hardware interfaces used to connect Blimp's units
 - ``test/``: Utilities used for testing hardware units, including
   functional-level wrappers around interfaces for concise syntax to
   send and receive messages
 - ``tools/``: Tools used to support Blimp's development:

    - ``rvelfdump.cpp``: A program to turn a compiled RISCV program into
      a text-based ``address: data`` mapping
    - ``spi_flash``: A Python program to communicate a text-based
      ``address: data`` mapping to an FPGA emulation of Blimp over SPI

 - ``types/``: Common types used throughout the processor