//========================================================================
// CommitNotif.v
//========================================================================
// The notification interface for committing instructions

`ifndef INTF_COMMIT_NOTIF_V
`define INTF_COMMIT_NOTIF_V

//------------------------------------------------------------------------
// CommitNotif
//------------------------------------------------------------------------

interface CommitNotif
#(
  parameter p_seq_num_bits   = 5,
  parameter p_phys_addr_bits = 6
);
  
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic [31:0] pc;
  logic  [4:0] waddr;
  logic [31:0] wdata;
  logic        wen;
  logic        val;
  logic        is_fp;

  // verilator lint_off UNUSEDSIGNAL

  // Added in v2
  logic [p_seq_num_bits-1:0] seq_num;

  // Added in v3
  logic [p_phys_addr_bits-1:0] ppreg;

  // verilator lint_on UNUSEDSIGNAL


  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Module-facing Ports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // Publish
  modport pub (
    output pc,
    output waddr,
    output wdata,
    output wen,
    output val,
    output is_fp,


    // v2
    output seq_num,

    // v3
    output ppreg
  );

  // Subscribe
  modport sub (
    input pc,
    input waddr,
    input wdata,
    input wen,
    input val,
    input is_fp,

    // v2
    input seq_num,

    // v3
    input ppreg
  );

endinterface

`endif // INTF_COMMIT_NOTIF_V
