//========================================================================
// BlimpV1.v
//========================================================================
// A top-level implementation of the Blimp processor with an ALU and
// multiplier

`ifndef HW_TOP_BLIMPV1_V
`define HW_TOP_BLIMPV1_V

`include "defs/UArch.v"
`include "hw/fetch/fetch_unit_variants/FetchUnitL1.v"
`include "hw/decode_issue/decode_issue_unit_variants/DecodeIssueUnitL1.v"
`include "hw/execute/execute_units_l1/ALUL1.v"
`include "hw/execute/execute_units_l1/MultiplierL1.v"
`include "hw/writeback_commit/writeback_commit_unit_variants/WritebackCommitUnitL1.v"
`include "intf/MemIntf.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"
`include "intf/InstTraceNotif.v"

module BlimpV1 #(
  parameter p_seq_num_bits = 5
) (
  input logic clk,
  input logic rst,

  //----------------------------------------------------------------------
  // Instruction Memory
  //----------------------------------------------------------------------

  MemIntf.client inst_mem,

  //----------------------------------------------------------------------
  // Instruction Trace
  //----------------------------------------------------------------------

  InstTraceNotif.pub inst_trace
);

  localparam p_num_pipes = 2;

  //----------------------------------------------------------------------
  // Interfaces
  //----------------------------------------------------------------------

  F__DIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) f__d_intf();

  D__XIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) d__x_intfs[p_num_pipes]();

  X__WIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) x__w_intfs[p_num_pipes]();

  CompleteNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) complete_notif();

  CommitNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) commit_notif();

  assign inst_trace.pc    = commit_notif.pc;
  assign inst_trace.waddr = commit_notif.waddr;
  assign inst_trace.wdata = commit_notif.wdata;
  assign inst_trace.wen   = commit_notif.wen;
  assign inst_trace.val   = commit_notif.val;

  //----------------------------------------------------------------------
  // Units
  //----------------------------------------------------------------------

  FetchUnitL1 FU (
    .mem (inst_mem),
    .D   (f__d_intf),
    .*
  );

  DecodeIssueUnitL1 #(
    .p_num_pipes    (p_num_pipes),
    .p_pipe_subsets ({
      OP_ADD_VEC, // ALU
      OP_MUL_VEC  // Multiplier
    })
  ) DIU (
    .F        (f__d_intf),
    .Ex       (d__x_intfs),
    .complete (complete_notif),
    .*
  );

  ALUL1 ALU_XU (
    .D (d__x_intfs[0]),
    .W (x__w_intfs[0]),
    .*
  );

  MultiplierL1 MUL_XU (
    .D (d__x_intfs[1]),
    .W (x__w_intfs[1]),
    .*
  );

  WritebackCommitUnitL1 #(
    .p_num_pipes (p_num_pipes)
  ) WCU (
    .Ex       (x__w_intfs),
    .complete (complete_notif),
    .commit   (commit_notif),
    .*
  );

  logic [p_seq_num_bits-1:0] unused_seq_num;
  assign unused_seq_num = commit_notif.seq_num;

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
    trace = {trace, WCU.trace( trace_level )};
  endfunction
`endif

endmodule

`endif // HW_TOP_BLIMPV1_V
