//========================================================================
// fl_vtrace.v
//========================================================================
// An include to access FL program tracing

`ifndef FL_FL_VTRACE_V
`define FL_FL_VTRACE_V

typedef struct packed {
  bit        wen;
  bit  [4:0] waddr;
  bit [31:0] wdata;
  bit [31:0] pc;
} inst_trace;

import "DPI-C" function void   fl_reset();
import "DPI-C" function void   fl_init ( bit [31:0] addr, bit[31:0] binary );
import "DPI-C" function bit    fl_trace( output inst_trace trace );
import "DPI-C" function string fl_trace_str( inst_trace trace );

`endif // FL_FL_VTRACE_V
