//========================================================================
// fl_peripherals.h
//========================================================================
// Functions to check known FL memory-mapped peripherals in simulation

#ifndef FL_FL_PERIPHERALS_H
#define FL_FL_PERIPHERALS_H

#include <cstdint>

extern "C" bool try_fl_read( uint32_t* addr, uint32_t* data );
extern "C" bool try_fl_write( uint32_t* addr, uint32_t* data );
extern "C" bool fl_exit_requested();

#endif  // FL_FL_PERIPHERALS_H