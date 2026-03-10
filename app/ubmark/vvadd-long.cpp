//========================================================================
// vvadd-long.cpp
//========================================================================
// A vvadd benchmark with a larger iteration count for meaningful
// pipeline performance analysis.

#include "utils/blimp_stdlib.h"
#include "utils/blimp_wprintf.h"

#define SIZE 1000

int src0[SIZE];
int src1[SIZE];
int dest[SIZE];

void vvadd( int* dest, int* src0, int* src1, int size )
{
  for ( int i = 0; i < size; i++ )
    dest[i] = src0[i] + src1[i];
}

int main( void )
{
  // Initialize arrays with simple patterns
  for ( int i = 0; i < SIZE; i++ ) {
    src0[i] = i;
    src1[i] = SIZE - i;
  }

  int start_cycles = blimp_cycle_count();
  vvadd( dest, src0, src1, SIZE );
  int end_cycles = blimp_cycle_count();

  blimp_wprintf( L"vvadd-long completed in %d cycles\n",
                 end_cycles - start_cycles );

  // Quick validation
  for ( int i = 0; i < SIZE; i++ ) {
    if ( dest[i] != SIZE ) {
      blimp_wprintf( L"\n FAILED: dest[%d] = %d (expected %d)\n\n",
                     i, dest[i], SIZE );
      blimp_exit( 1 );
    }
  }
  blimp_wprintf( L"All indices match!\n" );
}
