//========================================================================
// CompleteNotif.v
//========================================================================
// The notification interface for writing back values

`ifndef INTF_COMPLETE_NOTIF_V
`define INTF_COMPLETE_NOTIF_V

//------------------------------------------------------------------------
// CompleteNotif
//------------------------------------------------------------------------

interface CompleteNotif
#(
  parameter p_seq_num_bits   = 5,
  parameter p_phys_addr_bits = 6
);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic                [4:0] waddr;
  logic               [31:0] wdata;
  logic                      wen;
  logic                      val;
  logic                      is_fp;

  // verilator lint_off UNUSEDSIGNAL
  // verilator lint_off UNDRIVEN

  // Added in v2
  logic [p_seq_num_bits-1:0] seq_num;

  // Added in v3
  logic [p_phys_addr_bits-1:0] preg;

  // verilator lint_on UNUSEDSIGNAL
  // verilator lint_on UNDRIVEN

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Module-facing Ports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // Publish
  modport pub (
    output waddr,
    output wdata,
    output wen,
    output val,
    output is_fp,

    // v2
    output seq_num,

    // v3
    output preg
  );

  // Subscribe
  modport sub (
    input waddr,
    input wdata,
    input wen,
    input val,
    input is_fp,

    // v2
    input seq_num,

    // v3
    input preg
  );

endinterface

`endif // INTF_COMPLETE_NOTIF_V
