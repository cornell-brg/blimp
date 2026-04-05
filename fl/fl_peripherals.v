//========================================================================
// fl_peripherals.v
//========================================================================
// An include to access memory-mapped peripherals

`ifndef FL_FL_PERIPHERALS_V
`define FL_FL_PERIPHERALS_V

`ifndef SYNTHESIS
import "DPI-C" function bit try_fl_read      ( bit [31:0] addr, output bit[31:0] data );
import "DPI-C" function bit try_fl_write     ( bit [31:0] addr, input  bit[31:0] data );
import "DPI-C" function bit fl_exit_requested();
`endif

`endif // FL_FL_PERIPHERALS_V
