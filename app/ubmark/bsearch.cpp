//========================================================================
// bsearch.cpp
//========================================================================
// A basic bsearch benchmark for Blimp

#include "bsearch.h"
#include "utils/blimp_stdlib.h"
#include "utils/blimp_wprintf.h"

void bsearch( int* idxs, int* search_keys, int search_keys_size,
              int* sorted_keys, int sorted_keys_size )
{
  for ( int i = 0; i < search_keys_size; i++ ) {
    int key     = search_keys[i];
    int idx_min = 0;
    int idx_mid = sorted_keys_size / 2;
    int idx_max = sorted_keys_size - 1;

    int done = 0;
    idxs[i]  = -1;
    do {
      int midkey = sorted_keys[idx_mid];

      if ( key == midkey ) {
        idxs[i] = idx_mid;
        done    = 1;
      }

      if ( key > midkey )
        idx_min = idx_mid + 1;
      else if ( key < midkey )
        idx_max = idx_mid - 1;

      idx_mid = ( idx_min + idx_max ) / 2;

    } while ( !done && ( idx_min <= idx_max ) );
  }
}

int idxs[20];

int main( void )
{
  int start_cycles = blimp_cycle_count();
  bsearch( idxs, eval_search_keys, eval_search_keys_size,
           eval_sorted_keys, eval_sorted_keys_size );
  int end_cycles = blimp_cycle_count();

  blimp_wprintf( L"bsearch completed in %d cycles\n",
                 end_cycles - start_cycles );
  for ( int i = 0; i < eval_search_keys_size; i++ ) {
    if ( idxs[i] != eval_ref[i] ) {
      blimp_wprintf(
          L"\n FAILED: idxs[%d] != eval_ref[%d] (%d != %d)\n\n", i, i,
          idxs[i], eval_ref[i] );
      blimp_exit( 1 );
    }
  }
  blimp_wprintf( L"All indices match!\n" );
}