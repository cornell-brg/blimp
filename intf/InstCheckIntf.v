//========================================================================
// InstCheckIntf.v
//========================================================================
// Common interface for instruction check stages in superscalar DIU

`ifndef INTF_INST_CHECK_INTF_V
`define INTF_INST_CHECK_INTF_V

//------------------------------------------------------------------------
// InstChkIntf
//------------------------------------------------------------------------

interface InstChkIntf;

  localparam [1:0] INST_STATUS_INVALID    = 2'b00,
                   INST_STATUS_READY      = 2'b01,
                   INST_STATUS_DISPATCHED = 2'b10; 

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic       pass;
  logic       invalidate;
  logic [1:0] inst_status;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Module-facing Ports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  modport out (
    output pass,
    output invalidate,
    output inst_status
  );

  modport in (
    input pass,
    input invalidate,
    input inst_status
  );

endinterface

`endif // INTF_INST_CHECK_INTF_V
