//========================================================================
// ptrchase.h
//========================================================================
// Test data for the pointer-chase microbenchmark.
//
// Two permutation arrays (chain A and chain B) each form a full cycle
// through 0..31 with different strides, so every element is visited
// exactly once.
//
// chain_a: stride-13 permutation, chain_a[i] = (i + 13) % 32
// chain_b: stride-11 permutation, chain_b[i] = (i + 11) % 32

#ifndef APP_UBMARK_PTRCHASE_H
#define APP_UBMARK_PTRCHASE_H

const int chase_len = 32;

// Chain A: stride-13 mod 32
int chain_a[32] = {
  13, 14, 15, 16, 17, 18, 19, 20,
  21, 22, 23, 24, 25, 26, 27, 28,
  29, 30, 31,  0,  1,  2,  3,  4,
   5,  6,  7,  8,  9, 10, 11, 12
};

// Chain B: stride-11 mod 32
int chain_b[32] = {
  11, 12, 13, 14, 15, 16, 17, 18,
  19, 20, 21, 22, 23, 24, 25, 26,
  27, 28, 29, 30, 31,  0,  1,  2,
   3,  4,  5,  6,  7,  8,  9, 10
};

// Expected: sum of 0..31 = 496 for each chain
const int chain_ref = 496;

#endif // APP_UBMARK_PTRCHASE_H
