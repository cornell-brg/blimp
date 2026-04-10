//========================================================================
// vvadd.cpp
//========================================================================
// A basic vvadd benchmark for Blimp

#include "utils/blimp_stdlib.h"
#include "utils/blimp_stdio.h"
#include "utils/blimp_wprintf.h"
#include "vvadd.h"

void vvadd( int* dest, int* src0, int* src1, int size )
{
  for ( int i = 0; i < size; i++ )
    dest[i] = src0[i] + src1[i];
}

int dest[100];

int main( void )
{
  int start_cycles = blimp_cycle_count();
  int start_insts  = blimp_inst_count();
  vvadd( dest, eval_src0, eval_src1, eval_size );
  int end_cycles = blimp_cycle_count();
  int end_insts  = blimp_inst_count();

  int num_cycles = end_cycles - start_cycles;
  int num_insts  = end_insts  - start_insts;
  blimp_printf( "vvadd: %d cycles, %d insts, CPI = %d.%d\n",
                num_cycles, num_insts,
                num_cycles / num_insts,
                (num_cycles * 100 / num_insts) % 100 );
  for ( int i = 0; i < eval_size; i++ ) {
    if ( dest[i] != eval_ref[i] ) {
      blimp_wprintf(
          L"\n FAILED: dest[%d] != eval_ref[%d] (%d != %d)\n\n", i, i,
          dest[i], eval_ref[i] );
      blimp_exit( 1 );
    }
  }
  blimp_wprintf( L"All indices match!\n" );
}