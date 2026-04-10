//========================================================================
// FLExit.cpp
//========================================================================
// A memory-mapped peripheral for terminating the simulation

#include "fl/peripherals/FLExit.h"
#include <cstdlib>
#include <iostream>

#ifdef BLIMP_VERILATOR
extern void vl_finish( const char* filename, int linenum,
                       const char* hier );
#endif

//------------------------------------------------------------------------
// Static members
//------------------------------------------------------------------------

bool     FLExit::s_exit_requested = false;
uint32_t FLExit::s_exit_code      = 0;

//------------------------------------------------------------------------
// read
//------------------------------------------------------------------------

void FLExit::read( uint32_t, uint32_t* )
{
  // Never called
}

//------------------------------------------------------------------------
// write
//------------------------------------------------------------------------

void FLExit::write( uint32_t, uint32_t data )
{
  // Address is always 0xFFFFFFFC for writing
  std::cout << "Simulation finished with exit code " << (int) data
            << std::endl;
#ifdef BLIMP_VERILATOR
  vl_finish( __FILE__, __LINE__, "" );
#else
  // Set exit flag so the SV caller can invoke $finish, which ensures
  // that final blocks execute properly.
  s_exit_requested = true;
  s_exit_code      = data;
#endif
}
