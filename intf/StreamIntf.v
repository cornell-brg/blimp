//========================================================================
// StreamIntf.v
//========================================================================
// A generic interface for stream messages

`ifndef INTF_STREAMINTF_V
`define INTF_STREAMINTF_V

interface StreamIntf #(
  parameter type t_msg = logic[31:0]
);
  
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic val;
  logic rdy;
  t_msg msg;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Modports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  modport istream (
    input  val,
    output rdy,
    input  msg
  );

  modport ostream (
    output val,
    input  rdy,
    output msg
  );

endinterface

`endif // INTF_STREAMINTF_V
