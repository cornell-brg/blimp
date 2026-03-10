//========================================================================
// ptrchase.cpp
//========================================================================
// Pointer-chase microbenchmark for OOO vs InOrder issue queue comparison.
//
// Two tests:
//
// 1. ONE CHAIN  -- single pointer-chase traversal.  Baseline.
//
// 2. TWO CHAINS -- two independent pointer chases interleaved in the
//    same loop.  Both chains produce loads that go to the MEM pipe.
//
//    With InOrder issue: a blocked chain-A load at the head of the MEM
//    queue prevents the ready chain-B load behind it from issuing.
//    The chains effectively serialize, roughly doubling the cycle count.
//
//    With OOO issue: chain-B's load can bypass chain-A's blocked load
//    and issue immediately.  Both chains progress in parallel, so the
//    cycle count stays close to the one-chain baseline.

#include "utils/blimp_stdlib.h"
#include "utils/blimp_wprintf.h"
#include "ptrchase.h"

//----------------------------------------------------------------------
// one_chain -- single pointer-chase traversal (baseline)
//----------------------------------------------------------------------

__attribute__((noinline))
int one_chain( int* chain, int n )
{
  int idx = 0;
  int sum = 0;
  for ( int i = 0; i < n; i++ ) {
    idx  = chain[idx];
    sum += idx;
  }
  return sum;
}

//----------------------------------------------------------------------
// two_chains -- two independent pointer chases in one loop
//----------------------------------------------------------------------

__attribute__((noinline))
int two_chains( int* ca, int* cb, int n )
{
  int a = 0, b = 0;
  int sum_a = 0, sum_b = 0;
  for ( int i = 0; i < n; i++ ) {
    a = ca[a];
    sum_a += a;
    b = cb[b];
    sum_b += b;
  }
  return sum_a + sum_b;
}

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------

int main( void )
{
  // One chain (baseline)
  int t0 = blimp_cycle_count();
  int r1 = one_chain( chain_a, chase_len );
  int t1 = blimp_cycle_count();

  // Two chains
  int t2 = blimp_cycle_count();
  int r2 = two_chains( chain_a, chain_b, chase_len );
  int t3 = blimp_cycle_count();

  int cycles_one = t1 - t0;
  int cycles_two = t3 - t2;

  blimp_wprintf( L"one chain:  %d cycles\n", cycles_one );
  blimp_wprintf( L"two chains: %d cycles\n", cycles_two );

  // Verify
  if ( r1 != chain_ref ) {
    blimp_wprintf( L"\n FAILED: one chain %d != %d\n\n", r1, chain_ref );
    blimp_exit( 1 );
  }
  if ( r2 != chain_ref + chain_ref ) {
    blimp_wprintf( L"\n FAILED: two chains %d != %d\n\n",
                   r2, chain_ref + chain_ref );
    blimp_exit( 1 );
  }
  blimp_wprintf( L"Results match!\n" );
}
