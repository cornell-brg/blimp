//========================================================================
// InsnCheckIntf.v
//========================================================================
// Common interface for instruction check stages in superscalar DIU

`ifndef INTF_INSN_CHECK_INTF_V
`define INTF_INSN_CHECK_INTF_V

//------------------------------------------------------------------------
// InsnCheckIntf
//------------------------------------------------------------------------

interface InsnCheckIntf;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic prev_stage_pass;
  logic prev_insn_pass;
  logic insn_valid;
  logic pass;
  logic invalidate;
  logic prev_insn_pass_out;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Module-facing Ports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // Check module
  modport check (
    input  prev_stage_pass,
    input  prev_insn_pass,
    input  insn_valid,
    output pass,
    output invalidate,
    output prev_insn_pass_out
  );

  // Controller (DIU)
  modport ctl (
    output prev_stage_pass,
    output prev_insn_pass,
    output insn_valid,
    input  pass,
    input  invalidate,
    input  prev_insn_pass_out
  );

endinterface

`endif // INTF_INSN_CHECK_INTF_V
