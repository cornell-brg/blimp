//========================================================================
// F__DIntf.v
//========================================================================
// The interface definition going between F and D

`ifndef INTF_F__D_INTF_V
`define INTF_F__D_INTF_V

interface F__DIntf
#(
  parameter p_seq_num_bits = 5
);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic [31:0] inst;
  logic [31:0] pc;
  logic        val;
  logic        rdy;

  // verilator lint_off UNUSEDSIGNAL

  // Added in v2
  logic [p_seq_num_bits-1:0] seq_num;

  // verilator lint_on UNUSEDSIGNAL

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Module-facing Ports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  modport F_intf (
    output inst,
    output pc,
    output val,
    input  rdy,

    // v2
    output seq_num
  );

  modport D_intf (
    input  inst,
    input  pc,
    input  val,
    output rdy,
    
    // v2
    input  seq_num
  );

endinterface

`endif // INTF_F__D_INTF_V
