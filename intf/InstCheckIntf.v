//========================================================================
// InstCheckIntf.v
//========================================================================
// Common interface for instruction check stages in superscalar DIU

`ifndef INTF_INST_CHECK_INTF_V
`define INTF_INST_CHECK_INTF_V

//------------------------------------------------------------------------
// InstCheckIntf
//------------------------------------------------------------------------

interface InstCheckIntf;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic prev_stage_pass;
  logic prev_inst_pass;
  logic inst_valid;
  logic pass;
  logic invalidate;
  logic prev_inst_pass_out;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Module-facing Ports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // Check module
  modport check (
    input  prev_stage_pass,
    input  prev_inst_pass,
    input  inst_valid,
    output pass,
    output invalidate,
    output prev_inst_pass_out
  );

  // Controller (DIU)
  modport ctl (
    output prev_stage_pass,
    output prev_inst_pass,
    output inst_valid,
    input  pass,
    input  invalidate,
    input  prev_inst_pass_out
  );

endinterface

`endif // INTF_INST_CHECK_INTF_V
