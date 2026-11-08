#=========================================================================
# crt0.S : Entry point for TinyRV2 user programs
#=========================================================================
# This file is originally grabbed from riscv-gnu-toolchain repo
#
#  - https://github.com/riscv/riscv-gnu-toolchain/blob/master/newlib/libgloss/riscv/riscv.ld
#
# According to this:
#
#  - https://github.com/riscv/riscv-gnu-toolchain/issues/42
#
# The execution environment (e.g., OS kernel) is expected to have
# initialized sp before jumping to the program's entry point. If you're
# in an embedded domain with different constraints, you need to use a
# different crt0 that sets up that kind of thing. gp is the ABI global
# pointer to the small data section. The OS doesn't initialize it because
# it's a property of the binary, not the execution environment (unlike
# the stack).
#
# This crt0.S assumes the test harness has put the command line arguments
# on the stack as illustrated below.
#
#  address
#          -------------------------------------------
#  0xffffc last word in memory
#          -------------------------------------------
#          unusedd until last argument
#          -------------------------------------------
#          arg(argc-1)  : argument argc-1
#          ...
#          arg(1)       : argument 1
#          arg(0)       : argument 0
#          -------------------------------------------
#          NULL         : extra null pointer
#          NULL         : end of argument pointers
#          argv[argc-1] : argument pointer argc-1
#          ...
#          argv[1]      : argument pointer 1
#          argv[0]      : argument pointer 0
#  0xff000 argc         : argument count                <-- stack pointer
#          -------------------------------------------
#
# Notice that we reserve a fixed size for all the argument storage. This
# is to make sure that the stack alignment is not a function of the
# arguments. Based on this layout we need to set a0 and a1 correctly as
# they are the arguments to main(). Basically argc is stored in a0 and
# equals the value pointed to by sp, and argv is stored in a1 equals
# sp+4.

  .text
  .global _start
_start:

  # initialize global pointer

  auipc gp, %pcrel_hi(_gp)
  addi  gp, gp, %pcrel_lo(_start)

  # initialize all registers to zero. this helps four-state simulation by
  # making sure no register values are Xs.

  addi  x1,  x0, 0
  addi  x2,  x0, 0
  # ... x3 is gp which was initialized above ...
  addi  x4,  x0, 0
  addi  x5,  x0, 0
  addi  x6,  x0, 0
  addi  x7,  x0, 0
  addi  x8,  x0, 0
  addi  x9,  x0, 0
  addi  x10, x0, 0
  addi  x11, x0, 0
  addi  x12, x0, 0
  addi  x13, x0, 0
  addi  x14, x0, 0
  addi  x15, x0, 0
  addi  x16, x0, 0
  addi  x17, x0, 0
  addi  x18, x0, 0
  addi  x19, x0, 0
  addi  x20, x0, 0
  addi  x21, x0, 0
  addi  x22, x0, 0
  addi  x23, x0, 0
  addi  x24, x0, 0
  addi  x25, x0, 0
  addi  x26, x0, 0
  addi  x27, x0, 0
  addi  x28, x0, 0
  addi  x29, x0, 0
  addi  x30, x0, 0
  addi  x31, x0, 0

  # initialize stack pointer to the top of linker-defined RAM

  lui   sp, 0x000ff

1:

  # clear the bss segment

  la    t0, _fbss   # _fbss is defined in linker script
  la    t1, _end    # _fbss is defined in linker script

1:
  sw    x0, 0(t0)
  addi  t0, t0, 4
  bltu  t0, t1, 1b

  # set a0 to argc and a1 to argv

  // lw    a0, 0(sp)
  // addi  a1, sp, 4
  addi a0, x0, 1 // No arguments

  # call main

  jal   x1, main

  # use return value from main (a0) as exit code

  sw    a0, -4(x0)

  # few nops to enable test harness to stop simulation

  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop

  # infinite loop, should not get here

1:
  beq     zero, zero, 1b