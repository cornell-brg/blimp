//========================================================================
// BlimpV5.v
//========================================================================
// A top-level implementation of the Blimp processor with OOO completion
// and register renaming supporting memory and unconditional control flow
// operations

`ifndef HW_TOP_BLIMPV5_V
`define HW_TOP_BLIMPV5_V

`include "defs/UArch.v"
`include "hw/fetch/fetch_unit_variants/FetchUnitL3.v"
`include "hw/decode_issue/decode_issue_unit_variants/DecodeIssueUnitL4.v"
`include "hw/execute/execute_units_l1/ALUL1.v"
`include "hw/execute/execute_units_l2/PipelinedMultiplierL2.v"
`include "hw/execute/execute_units_l3/LoadStoreUnitL3.v"
`include "hw/execute/execute_units_l4/ControlFlowUnitL4.v"
`include "hw/writeback_commit/writeback_commit_unit_variants/WritebackCommitUnitL3.v"
`include "intf/MemIntf.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"
`include "intf/SquashNotif.v"
`include "intf/InstTraceNotif.v"

module BlimpV5 #(
  parameter p_opaq_bits     = 8,
  parameter p_seq_num_bits  = 5,
  parameter p_num_phys_regs = 36
) (
  input logic clk,
  input logic rst,

  //----------------------------------------------------------------------
  // Instruction Memory
  //----------------------------------------------------------------------

  MemIntf.client inst_mem,

  //----------------------------------------------------------------------
  // Data Memory
  //----------------------------------------------------------------------

  MemIntf.client data_mem,

  //----------------------------------------------------------------------
  // Instruction Trace
  //----------------------------------------------------------------------

  InstTraceNotif.pub inst_trace
);

  localparam p_num_pipes = 4;
  localparam p_phys_addr_bits = $clog2( p_num_phys_regs );

  //----------------------------------------------------------------------
  // Interfaces
  //----------------------------------------------------------------------

  F__DIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) f__d_intf();

  D__XIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) d__x_intfs[p_num_pipes]();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) x__w_intfs[p_num_pipes]();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_notif();
  
  CompleteNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) complete_notif();

  CommitNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) commit_notif();

  assign inst_trace_notif.pc    = commit_notif.pc;
  assign inst_trace_notif.waddr = commit_notif.waddr;
  assign inst_trace_notif.wdata = commit_notif.wdata;
  assign inst_trace_notif.wen   = commit_notif.wen;
  assign inst_trace_notif.val   = commit_notif.val;

  logic [4:0] unused_complete_waddr;
  assign unused_complete_waddr = complete_notif.waddr;

  //----------------------------------------------------------------------
  // Units
  //----------------------------------------------------------------------

  FetchUnitL3 #(
    .p_seq_num_bits  (p_seq_num_bits),
    .p_max_in_flight (32)
  ) FU (
    .mem    (inst_mem),
    .D      (f__d_intf),
    .commit (commit_notif),
    .squash (squash_notif),
    .*
  );

  DecodeIssueUnitL4 #(
    .p_num_pipes     (p_num_pipes),
    .p_num_phys_regs (p_num_phys_regs),
    .p_pipe_subsets ({
      OP_ADD_VEC,              // ALU
      OP_MUL_VEC,              // Multiplier
      OP_LW_VEC | OP_SW_VEC,   // Memory
      OP_JAL_VEC | OP_JALR_VEC // Control Flow
    })
  ) DIU (
    .F        (f__d_intf),
    .Ex       (d__x_intfs),
    .complete (complete_notif),
    .commit   (commit_notif),
    .squash   (squash_notif),
    .*
  );

  ALUL1 ALU_XU (
    .D (d__x_intfs[0]),
    .W (x__w_intfs[0]),
    .*
  );

  PipelinedMultiplierL2 #(
    .p_pipeline_stages (4)
  ) MUL_XU (
    .D (d__x_intfs[1]),
    .W (x__w_intfs[1]),
    .*
  );

  LoadStoreUnitL3 #(
    .p_opaq_bits (p_opaq_bits)
  ) MEM_XU (
    .D   (d__x_intfs[2]),
    .W   (x__w_intfs[2]),
    .mem (data_mem),
    .*
  );

  ControlFlowUnitL4 CTRL_XU (
    .D (d__x_intfs[3]),
    .W (x__w_intfs[3]),
    .*
  );

  WritebackCommitUnitL3 #(
    .p_num_pipes      (p_num_pipes),
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) WCU (
    .Ex       (x__w_intfs),
    .complete (complete_notif),
    .commit   (commit_notif),
    .*
  );

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function string trace( int trace_level );
    trace = "";
    trace = {trace, FU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, DIU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, ALU_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, MUL_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, MEM_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, CTRL_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, WCU.trace( trace_level )};
  endfunction
`endif

endmodule

`endif // HW_TOP_BLIMPV5_V
