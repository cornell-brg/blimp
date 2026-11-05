#pragma once
#include <cstdint>
#include <cstring>

inline float bits_to_float( uint32_t bits ) {
  float f;
  std::memcpy( &f, &bits, sizeof(float) );
  return f;
}

inline uint32_t float_to_bits( float f ) {
  uint32_t bits;
  std::memcpy( &bits, &f, sizeof(uint32_t) );
  return bits;
}

extern "C" uint32_t fadd_s_bits(uint32_t a_bits, uint32_t b_bits);
extern "C" uint32_t fsub_s_bits(uint32_t a_bits, uint32_t b_bits);
