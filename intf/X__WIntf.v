//========================================================================
// X__WIntf.v
//========================================================================
// The interface definition going between X and W

`ifndef INTF_X__W_INTF_V
`define INTF_X__W_INTF_V

//------------------------------------------------------------------------
// X__WIntf
//------------------------------------------------------------------------

interface X__WIntf
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
  logic        rdy;
  logic        is_fp;

  // verilator lint_off UNUSEDSIGNAL

  // Added in v2
  logic [p_seq_num_bits-1:0] seq_num;

  // Added in v3
  logic [p_phys_addr_bits-1:0] preg;
  logic [p_phys_addr_bits-1:0] ppreg;

  // verilator lint_on UNUSEDSIGNAL

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Module-facing Ports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  modport X_intf (
    output pc,
    output waddr,
    output wdata,
    output wen,
    output val,
    output is_fp,
    input  rdy,

    // v2
    output seq_num,

    // v3
    output preg,
    output ppreg
  );

  modport W_intf (
    input  pc,
    input  waddr,
    input  wdata,
    input  wen,
    input  val,
    input  is_fp,
    output rdy,

    // v2
    input  seq_num,

    // v3
    input  preg,
    input  ppreg
  );

endinterface

`endif // INTF_X__W_INTF_V
