//========================================================================
// MROBCoverage
//========================================================================
// A coverage class for a particular parametrization of the MROB

`ifndef HW_WRITEBACK_COMMIT_TEST_COVERAGE_WRITEBACKCOMMITUNITL4_COVERAGE_V
`define HW_WRITEBACK_COMMIT_TEST_COVERAGE_WRITEBACKCOMMITUNITL4_COVERAGE_V

`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"
`include "intf/X__WIntf.v"

module WritebackCommitUnitL4Coverage #(
  parameter p_num_pipes = 1,
  parameter p_num_be_lanes = 2
) (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // X <-> W Interface
  //----------------------------------------------------------------------

  X__WIntf.W_intf Ex [p_num_pipes],

  //----------------------------------------------------------------------
  // Completion Interfaces
  //----------------------------------------------------------------------

  CompleteNotif.pub complete [p_num_be_lanes],

  //----------------------------------------------------------------------
  // Commit Interface
  //----------------------------------------------------------------------

  CommitNotif.pub   commit [p_num_be_lanes]
);

  localparam p_seq_num_bits   = complete.p_seq_num_bits;
  localparam p_phys_addr_bits = complete.p_phys_addr_bits;

  // Coverpoints ---------------------------------------------------------

  // Reset
  RST_0: cover property ( @(posedge clk) rst == 0 );
  RST_1: cover property ( @(posedge clk) rst == 1 );
  
endmodule

`endif /* HW_WRITEBACK_COMMIT_TEST_COVERAGE_WRITEBACKCOMMITUNITL4_COVERAGE_V */
