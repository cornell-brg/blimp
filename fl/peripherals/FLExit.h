//========================================================================
// FLExit.h
//========================================================================
// A memory-mapped peripheral for terminating the simulation

#ifndef FL_EXIT_H
#define FL_EXIT_H

#include "fl/FLPeripheral.h"

class FLExit : public FLPeripheral {
  //----------------------------------------------------------------------
  // Address Ranges
  //----------------------------------------------------------------------

  std::vector<address_range_t> address_ranges = {
      { 0xFFFFFFFC, 0xFFFFFFFC, W },  // exit
  };

  //----------------------------------------------------------------------
  // Accessors
  //----------------------------------------------------------------------

  void read( uint32_t addr, uint32_t* data ) override;
  void write( uint32_t addr, uint32_t data ) override;
  const std::vector<address_range_t>& get_address_ranges() override
  {
    return address_ranges;
  }

public:
  //----------------------------------------------------------------------
  // Exit status (for non-Verilator builds)
  //----------------------------------------------------------------------

  static bool     s_exit_requested;
  static uint32_t s_exit_code;
};

#endif  // FL_TERMINAL_H
