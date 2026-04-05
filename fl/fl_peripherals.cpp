//========================================================================
// fl_peripherals.cpp
//========================================================================
// Functions to check known FL memory-mapped peripherals in simulation

#include "fl/FLPeripheral.h"
#include "fl/fl_peripherals.h"

// Peripherals
#include "fl/peripherals/FLExit.h"
#include "fl/peripherals/FLTerminal.h"
#include <iostream>

//------------------------------------------------------------------------
// List of peripherals
//------------------------------------------------------------------------

FLExit     exit_peripheral;
FLTerminal terminal_peripheral;

FLPeripheral* peripherals[] = { &exit_peripheral, &terminal_peripheral };

//------------------------------------------------------------------------
// try_fl_read
//------------------------------------------------------------------------

bool try_fl_read( uint32_t* addr, uint32_t* data )
{
  for ( FLPeripheral* peripheral : peripherals ) {
    if ( peripheral->try_read( *addr, data ) ) {
      return true;
    }
  }
  return false;
}

//------------------------------------------------------------------------
// try_fl_write
//------------------------------------------------------------------------

bool try_fl_write( uint32_t* addr, uint32_t* data )
{
  for ( FLPeripheral* peripheral : peripherals ) {
    if ( peripheral->try_write( *addr, *data ) ) {
      return true;
    }
  }
  return false;
}

//------------------------------------------------------------------------
// fl_exit_requested
//------------------------------------------------------------------------
// Returns true if FLExit::write was called, so the SV side can call
// $finish instead of the C++ side calling exit().

bool fl_exit_requested()
{
  return FLExit::s_exit_requested;
}