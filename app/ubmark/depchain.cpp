//========================================================================
// depchain.cpp
//========================================================================
// Dependency-chain microbenchmark demonstrating out-of-order issue
// benefit.
//
// Computes the same dot product two ways:
//
// 1. SERIAL -- single accumulator, one load-multiply-add chain.
//    Every multiply depends on the previous iteration's accumulate,
//    and every load feeds directly into a multiply.  There is almost
//    no independent work for OOO to exploit.
//
// 2. MULTI-CHAIN -- four independent accumulators, each with its own
//    load-multiply-add chain.  With in-order issue the head of the
//    issue queue blocks later independent chains.  With OOO issue,
//    loads and multiplies from all four chains can overlap.
//
// The cycle-count difference between the two shows how much OOO issue
// can exploit instruction-level parallelism.

#include "utils/blimp_stdlib.h"
#include "utils/blimp_wprintf.h"
#include "depchain.h"

//----------------------------------------------------------------------
// serial_dot -- single chain, no ILP
//----------------------------------------------------------------------

__attribute__((noinline))
int serial_dot( int* src0, int* src1, int n )
{
  int acc = 0;
  for ( int i = 0; i < n; i++ )
    acc += src0[i] * src1[i];
  return acc;
}

//----------------------------------------------------------------------
// multi_dot -- four independent chains, exposes ILP
//----------------------------------------------------------------------

__attribute__((noinline))
int multi_dot( int* src0, int* src1, int n )
{
  int acc0 = 0, acc1 = 0, acc2 = 0, acc3 = 0;
  for ( int i = 0; i < n; i += 4 ) {
    acc0 += src0[i]   * src1[i];
    acc1 += src0[i+1] * src1[i+1];
    acc2 += src0[i+2] * src1[i+2];
    acc3 += src0[i+3] * src1[i+3];
  }
  return acc0 + acc1 + acc2 + acc3;
}

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------

int main( void )
{
  // Serial version
  int t0 = blimp_cycle_count();
  int result_serial = serial_dot( eval_src0, eval_src1, eval_size );
  int t1 = blimp_cycle_count();

  // Multi-chain version
  int t2 = blimp_cycle_count();
  int result_multi = multi_dot( eval_src0, eval_src1, eval_size );
  int t3 = blimp_cycle_count();

  int cycles_serial = t1 - t0;
  int cycles_multi  = t3 - t2;

  blimp_wprintf( L"serial:      %d cycles\n", cycles_serial );
  blimp_wprintf( L"multi-chain: %d cycles\n", cycles_multi );

  // Verify both produce the correct result
  if ( result_serial != eval_ref ) {
    blimp_wprintf( L"\n FAILED: serial result %d != expected %d\n\n",
                   result_serial, eval_ref );
    blimp_exit( 1 );
  }
  if ( result_multi != eval_ref ) {
    blimp_wprintf( L"\n FAILED: multi result %d != expected %d\n\n",
                   result_multi, eval_ref );
    blimp_exit( 1 );
  }
  blimp_wprintf( L"Results match!\n" );
}