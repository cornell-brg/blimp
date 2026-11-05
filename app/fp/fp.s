.section .text
.globl main

main:
    # x10 = 3.0f (0x40400000)
    lui   x10, 0x40400

    # x11 = 2.0f (0x40000000)
    lui   x11, 0x40000

    # Move integer bit patterns to FP registers
    fmv.w.x  ft0, x10      # ft0 = 3.0
    fmv.w.x  ft1, x11      # ft1 = 2.0

    # Floating point add: 3.0 + 2.0 = 5.0
    fadd.s   ft2, ft0, ft1  # ft2 = 5.0

    # Floating point multiply: 5.0 * 2.0 = 10.0
    fmul.s   ft3, ft2, ft1  # ft3 = 10.0

    # Convert result to int for return value
    fcvt.w.s x10, ft3       # x10 = 10
    ret
