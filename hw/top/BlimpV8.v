//========================================================================
// BlimpV8.v
//========================================================================
// A top-level implementation of the Blimp processor with support for
// RV32IM (no exceptions)

`ifndef HW_TOP_BLIMPV8_V
`define HW_TOP_BLIMPV8_V

`include "defs/UArch.v"
`include "hw/fetch/fetch_unit_variants/FetchUnitL3.v"
`include "hw/decode_issue/decode_issue_unit_variants/DecodeIssueUnitL5.v"
`include "hw/execute/execute_units_l6/ALUL6.v"
`include "hw/execute/execute_units_l7/IterativeMulDivRemL7.v"
`include "hw/execute/execute_units_l7/LoadStoreUnitL7.v"
`include "hw/execute/execute_units_l6/ControlFlowUnitL6.v"
`include "hw/squash/SquashUnitL1.v"
`include "hw/writeback_commit/writeback_commit_unit_variants/WritebackCommitUnitL3.v"
`include "intf/MemIntf.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"
`include "intf/SquashNotif.v"
`include "intf/InstTraceNotif.v"

module BlimpV8 #(
  parameter p_opaq_bits              = 8,
  parameter p_seq_num_bits           = 5,
  parameter p_num_phys_regs          = 36,
  parameter p_reclaim_width          = 2,
  parameter p_max_in_flight          = 8,
  parameter p_x_intf_fifo_depth      = 1,
  parameter p_alu_d_intf_fifo_depth  = 1,
  parameter p_mul_d_intf_fifo_depth  = 1,
  parameter p_mem_d_intf_fifo_depth  = 1,
  parameter p_ctrl_d_intf_fifo_depth = 1,
  parameter p_num_alus               = 2,
  parameter p_num_muls               = 2,
  parameter p_num_ldstrs             = 1,
  parameter p_num_pipes              = p_num_alus + p_num_muls + p_num_ldstrs + 1
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

  MemIntf.client data_mem [p_num_ldstrs],

  //----------------------------------------------------------------------
  // Instruction Trace
  //----------------------------------------------------------------------

  InstTraceNotif.pub inst_trace
);

  localparam p_phys_addr_bits = $clog2( p_num_phys_regs );

  // Pipe index offsets for MEM and CTRL units
  localparam p_mem_pipe_idx  = p_num_alus + p_num_muls;
  localparam p_ctrl_pipe_idx = p_num_alus + p_num_muls + p_num_ldstrs;

  //----------------------------------------------------------------------
  // Interfaces
  //----------------------------------------------------------------------

  F__DIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) f__d_intf();

  D__XIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) d__x_intfs[p_num_pipes-1:0]();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) x__w_intfs[p_num_pipes-1:0]();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) buffer_intf [p_num_alus]();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_arb_notif [2]();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_gnt_notif();
  
  CompleteNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) complete_notif();

  CommitNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) commit_notif();

  assign inst_trace.pc    = commit_notif.pc;
  assign inst_trace.waddr = commit_notif.waddr;
  assign inst_trace.wdata = commit_notif.wdata;
  assign inst_trace.wen   = commit_notif.wen;
  assign inst_trace.val   = commit_notif.val;

  logic [4:0] unused_complete_waddr;
  assign unused_complete_waddr = complete_notif.waddr;

  //----------------------------------------------------------------------
  // Units
  //----------------------------------------------------------------------

  parameter p_alu_subset = OP_ADD_VEC  |
                           OP_SUB_VEC  |
                           OP_AND_VEC  |
                           OP_OR_VEC   |
                           OP_XOR_VEC  |
                           OP_SLT_VEC  |
                           OP_SLTU_VEC |
                           OP_SRA_VEC  |
                           OP_SRL_VEC  |
                           OP_SLL_VEC  |
                           OP_LUI_VEC  |
                           OP_AUIPC_VEC;

  parameter p_m_subset   = OP_MUL_VEC    |
                           OP_MULH_VEC   |
                           OP_MULHU_VEC  |
                           OP_MULHSU_VEC |
                           OP_DIV_VEC    |
                           OP_DIVU_VEC   |
                           OP_REM_VEC    |
                           OP_REMU_VEC;

  parameter p_mem_subset = OP_LB_VEC  |
                           OP_LH_VEC  |
                           OP_LW_VEC  |
                           OP_LBU_VEC |
                           OP_LHU_VEC |
                           OP_SB_VEC  |
                           OP_SH_VEC  |
                           OP_SW_VEC;

  parameter p_ctrl_subset = OP_JAL_VEC  |
                            OP_JALR_VEC |
                            OP_BEQ_VEC  |
                            OP_BNE_VEC  |
                            OP_BLT_VEC  |
                            OP_BGE_VEC  |
                            OP_BLTU_VEC |
                            OP_BGEU_VEC;

  // Build pipe subsets array from parameterized counts
  function automatic rv_op_vec [p_num_pipes-1:0] gen_pipe_subsets;
    for ( int i = 0; i < p_num_alus; i++ )
      gen_pipe_subsets[i] = p_alu_subset;
    for ( int i = 0; i < p_num_muls; i++ )
      gen_pipe_subsets[p_num_alus + i] = p_m_subset;
    for ( int i = 0; i < p_num_ldstrs; i++ )
      gen_pipe_subsets[p_mem_pipe_idx + i] = p_mem_subset;
    gen_pipe_subsets[p_ctrl_pipe_idx] = p_ctrl_subset;
  endfunction

  localparam rv_op_vec [p_num_pipes-1:0] c_pipe_subsets = gen_pipe_subsets();

  FetchUnitL3 #(
    .p_reclaim_width (p_reclaim_width),
    .p_max_in_flight (p_max_in_flight)
  ) FU (
    .mem    (inst_mem),
    .D      (f__d_intf),
    .commit (commit_notif),
    .squash (squash_gnt_notif),
    .*
  );

  DecodeIssueUnitL5 #(
    .p_num_pipes     (p_num_pipes),
    .p_num_phys_regs (p_num_phys_regs),
    .p_pipe_subsets  (c_pipe_subsets)
  ) DIU (
    .F          (f__d_intf),
    .Ex         (d__x_intfs),
    .complete   (complete_notif),
    .squash_pub (squash_arb_notif[0]),
    .squash_sub (squash_gnt_notif),
    .commit     (commit_notif),
    .*
  );

  genvar j;

  generate
    for( j = 0; j < p_num_alus; j++ ) begin: ALU_XU_GEN
      ALUL6 #(
        .p_d_intf_fifo_depth (p_alu_d_intf_fifo_depth)
      ) ALU_XU (
        .D (d__x_intfs[j]),
        .W (x__w_intfs[j]),
        .*
      );
    end
  endgenerate

  generate
    for( j = 0; j < p_num_muls; j++ ) begin: MUL_XU_GEN
      IterativeMulDivRemL7 #(
        .p_d_intf_fifo_depth (p_mul_d_intf_fifo_depth)
      ) MUL_DIV_REM_XU (
        .D (d__x_intfs[p_num_alus + j]),
        .W (x__w_intfs[p_num_alus + j]),
        .*
      );
    end
  endgenerate

  generate
    for( j = 0; j < p_num_ldstrs; j++ ) begin: MEM_XU_GEN
      LoadStoreUnitL7 #(
        .p_opaq_bits         (p_opaq_bits),
        .p_num_in_flight     (p_max_in_flight),
        .p_d_intf_fifo_depth (p_mem_d_intf_fifo_depth)
      ) MEM_XU (
        .D   (d__x_intfs[p_mem_pipe_idx + j]),
        .W   (x__w_intfs[p_mem_pipe_idx + j]),
        .mem (data_mem[j]),
        .*
      );
    end
  endgenerate

  ControlFlowUnitL6 #(
    .p_d_intf_fifo_depth (p_ctrl_d_intf_fifo_depth)
  ) CTRL_XU (
    .D      (d__x_intfs[p_ctrl_pipe_idx]),
    .W      (x__w_intfs[p_ctrl_pipe_idx]),
    .squash (squash_arb_notif[1]),
    .*
  );

  WritebackCommitUnitL3 #(
    .p_num_pipes (p_num_pipes)
  ) WCU (
    .Ex       (x__w_intfs),
    .complete (complete_notif),
    .commit   (commit_notif),
    .*
  );

  SquashUnitL1 #(
    .p_num_arb (2)
  ) SU (
    .arb    (squash_arb_notif),
    .gnt    (squash_gnt_notif),
    .commit (commit_notif),
    .*
  );

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  string alu_trace   [p_num_alus];
  string mul_trace   [p_num_muls];
  string ldstr_trace [p_num_ldstrs];

  generate
    for( j = 0; j < p_num_alus; j++ ) begin: ALU_TRACE_GEN
      always_comb alu_trace[j] = ALU_XU_GEN[j].ALU_XU.trace( 0 );
    end
    for( j = 0; j < p_num_muls; j++ ) begin: MUL_TRACE_GEN
      always_comb mul_trace[j] = MUL_XU_GEN[j].MUL_DIV_REM_XU.trace( 0 );
    end
    for( j = 0; j < p_num_ldstrs; j++ ) begin: MEM_TRACE_GEN
      always_comb ldstr_trace[j] = MEM_XU_GEN[j].MEM_XU.trace( 0 );
    end
  endgenerate

  function string trace( int trace_level );
    trace = "";
    trace = {trace, FU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, DIU.trace( trace_level )};
    for( int i = 0; i < p_num_alus; i++ ) begin
      trace = {trace, " | "};
      trace = {trace, alu_trace[i]};
    end
    for( int i = 0; i < p_num_muls; i++ ) begin
      trace = {trace, " | "};
      trace = {trace, mul_trace[i]};
    end
    for( int i = 0; i < p_num_ldstrs; i++ ) begin
      trace = {trace, " | "};
      trace = {trace, ldstr_trace[i]};
    end
    trace = {trace, " | "};
    trace = {trace, CTRL_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, WCU.trace( trace_level )};
  endfunction
`endif

endmodule

`endif // HW_TOP_BLIMPV8_V
