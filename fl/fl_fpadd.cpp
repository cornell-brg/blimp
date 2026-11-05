// //========================================================================
// // fpadd.cpp
// //========================================================================
// // FL Model for simulating the functioning of 32-bit FP Adder

#include <stdint.h>

extern "C" {
  #include "softfloat.h" // Ensure path is correct in Makefile
    // Helper to apply your specific subnormal/NaN logic
    uint32_t apply_custom_logic(float32_t f_res, uint32_t a_bits, uint32_t b_bits) {
        uint32_t exp = (f_res.v >> 23) & 0xFF;
        uint32_t frac = f_res.v & 0x007FFFFF;

        // 1. Flush-to-Zero (FTZ) for subnormals
        if (exp == 0 && frac != 0) {
            return f_res.v & 0x80000000; // Return signed zero
        }

        // 2. Canonical NaN handling (if one input is NaN, return Quiet NaN)
        bool a_is_nan = ((a_bits >> 23) & 0xFF) == 0xFF && (a_bits & 0x7FFFFF) != 0;
        bool b_is_nan = ((b_bits >> 23) & 0xFF) == 0xFF && (b_bits & 0x7FFFFF) != 0;
        
        if (a_is_nan || b_is_nan) {
            return 0x7FC00000; // Standard Quiet NaN
        }

        return f_res.v;
    }

    uint32_t c_gold_fadd(uint32_t a_bits, uint32_t b_bits) {
        float32_t fa, fb;
        fa.v = a_bits;
        fb.v = b_bits;
        softfloat_exceptionFlags = 0;  // Add this before f32_add
        float32_t result = f32_add(fa, fb);
        softfloat_roundingMode = softfloat_round_near_even; // Match your RTL
        return apply_custom_logic(result, a_bits, b_bits);
    }

    uint32_t c_gold_fsub(uint32_t a_bits, uint32_t b_bits) {
        float32_t fa, fb;
        fa.v = a_bits;
        fb.v = b_bits;
        
        softfloat_roundingMode = softfloat_round_near_even;
        return apply_custom_logic(f32_sub(fa, fb), a_bits, b_bits);
    }
}