#include <cstdint>
#include <cmath>
#include <cstring>

// Helper: Convert uint32_t bits to float
inline float bits_to_float(uint32_t bits) {
  float f;
  std::memcpy(&f, &bits, sizeof(float));
  return f;
}

// Helper: Convert float to uint32_t bits
inline uint32_t float_to_bits(float f) {
  uint32_t bits;
  std::memcpy(&bits, &f, sizeof(float));
  return bits;
}

// Floating-point addition (single precision)
extern "C" uint32_t fadd_s_bits(uint32_t a_bits, uint32_t b_bits) {
  float a = bits_to_float(a_bits);
  float b = bits_to_float(b_bits);
  float result = a + b;
  return float_to_bits(result);
}

// Floating-point subtraction (single precision)
extern "C" uint32_t fsub_s_bits(uint32_t a_bits, uint32_t b_bits) {
  float a = bits_to_float(a_bits);
  float b = bits_to_float(b_bits);
  float result = a - b;
  return float_to_bits(result);
}