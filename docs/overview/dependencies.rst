Dependencies
==========================================================================

BLIMP requires the following:

* `CMake <https://cmake.org/>`_ (as well as any preferred backend, such as
  Ninja)
* `GCC <https://gcc.gnu.org/>`_
* The `RISCV toolchain <https://github.com/riscv-collab/riscv-gnu-toolchain>`_, for cross-compiling
* One of the following (for Verilog simulation):

  * `Synopsys VCS <https://www.synopsys.com/verification/simulation/vcs.html>`_
  * `Verilator <https://www.veripool.org/verilator/>`_

(Exact versions required are unknown, but all functionality was successfully
demonstrated on the BRG research server)

Note that the build system is currently only intended to work on Linux systems.
In particular, MacOS doesn't natively support ELF utilities (i.e. ``elf.h``),
and has particular command-line flags with CMake that don't work with the
RISCV toolchain. Further work could be done for this use case, but isn't
needed at this time.