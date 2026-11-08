//========================================================================
// demo.cpp
//========================================================================
// A demo as part of Blimp's walkthrough

#include "utils/blimp_stdlib.h"

//------------------------------------------------------------------------
// vvmul
//------------------------------------------------------------------------
// Performs element-wise multiplication on two arrays, and stores the
// result in a destination

void __attribute__( ( noinline ) ) vvmul( int* dest, int* src1, int* src2,
                                          int len )
{
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // DEMO TASK: Implement vvmul
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  for ( int i = 0; i < len; i++ )
    dest[i] = src1[i] * src2[i];

}

//------------------------------------------------------------------------
// main
//------------------------------------------------------------------------

int src1[10] = { 56, 12, 87, 7, 3, 37, 73, 8, 6, 31 };
int src2[10] = { 13, 36, 42, 28, 22, 19, 30, 69, 6, 8 };
int dest[10];

int main()
{
  int start_cycles = blimp_cycle_count();
  vvmul( dest, src1, src2, 10 );
  int end_cycles = blimp_cycle_count();

  blimp_printf( "vvmul completed in %d cycles\n",
                end_cycles - start_cycles );

  for ( int i = 0; i < 10; i++ ) {
    blimp_printf( "%02d: %2d * %2d = %4d\n", i, src1[i], src2[i],
                  dest[i] );
  }
}