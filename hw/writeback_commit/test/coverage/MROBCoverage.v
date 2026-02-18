//========================================================================
// MROBCoverage
//========================================================================
// A coverage class for a particular parametrization of the MROB

// Interface between the DUT and coverage class --------------------------

interface MROBTestIntf #(
  parameter p_depth     = 32,
  parameter p_msg_bits  = 32,
  parameter p_num_lanes = 2
)(
  input logic clk
);

  localparam p_entry_bits = $clog2( p_depth );

  logic rst;

  //----------------------------------------------------------------------
  // Insert
  //----------------------------------------------------------------------

  logic [p_entry_bits-1:0] ins_idx     [p_num_lanes];
  logic [p_msg_bits-1:0]   ins_msg     [p_num_lanes];
  logic                    ins_msg_val [p_num_lanes];
  logic                    ins_rdy;
  logic                    ins_en;
  logic [p_entry_bits:0]   avail_slots;

  //----------------------------------------------------------------------
  // Dequeue
  //----------------------------------------------------------------------

  logic [p_entry_bits-1:0] deq_idx     [p_num_lanes];
  logic [p_msg_bits-1:0]   deq_msg     [p_num_lanes];
  logic                    deq_msg_val [p_num_lanes];
  logic                    deq_rdy;
  logic                    deq_en;

endinterface

// Coverage class --------------------------------------------------------

`ifndef VERILATOR

class MROBCoverage #(
  parameter p_depth     = 32,
  parameter p_msg_bits  = 32,
  parameter p_num_lanes = 2
);

  virtual MROBTestIntf #(p_depth, p_msg_bits, p_num_lanes) vintf;

  // Covergroup ----------------------------------------------------------

  covergroup mrob_cg @( posedge vintf.clk );

    // Coverpoints

    reset: coverpoint vintf.rst {
      bins zero = { 0 };
      bins one  = { 1 };
      bins reserve = default;
    }

  endgroup

  // Function to create an instance of this class

  function new( virtual MROBTestIntf #(p_depth, p_msg_bits, p_num_lanes) vintf );
    this.vintf = vintf;
    mrob_cg = new();
  endfunction

endclass

`endif /* VERILATOR */
