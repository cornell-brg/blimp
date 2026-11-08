//========================================================================
// BlimpV8_sp26.v
//========================================================================
// A top-level implementation of the Blimp processor with support for
// RV32IM (no exceptions)

`ifndef HW_TOP_BLIMPV8_V
`define HW_TOP_BLIMPV8_V

`include "defs/UArch.v"
`include "hw/fetch/fetch_unit_variants/FetchUnitL3.v"
`include "hw/decode_issue/decode_issue_unit_variants/DecodeIssueUnitL5_sp26.v"
`include "hw/execute/ExQueue.v"
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

`include "ip/cmn/rtl/queues.sv"

module BlimpV8_sp26 #(
  parameter p_opaq_bits     = 8,
  parameter p_num_in_flight = 8,
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

  InstTraceNotif.pub inst_trace,
  input logic inst_trace_deq_rdy,
  
  //----------------------------------------------------------------------
  // Debug
  //----------------------------------------------------------------------
  
  input logic debug // 0 = normal operation, 1 = debug mode
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

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) buffer_intf();

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

  logic [4:0] unused_complete_waddr;
  assign unused_complete_waddr = complete_notif.waddr;
  
  //----------------------------------------------------------------------
  // Debug
  //----------------------------------------------------------------------
  
  typedef struct packed {
    logic [31:0] pc;
    logic [4:0]  waddr;
    logic [31:0] wdata;
    logic        wen;
  } trace_msg_t;
  
  trace_msg_t trace_enq_msg;
  logic       trace_enq_val;
  logic       trace_enq_rdy;

  trace_msg_t trace_deq_msg;
  logic       trace_deq_val;
  logic       trace_deq_rdy;
  
  logic inst_in_pipeline;
  logic f__d_xfer;
  logic trace_queue_free_entry;
  logic debug_stall;

  assign f__d_xfer   = f__d_intf.val & f__d_intf.rdy;
  assign debug_stall = debug & (inst_in_pipeline | ~trace_queue_free_entry);
  
  // tracks when an instruction is in the pipeline from D to W
  always_ff @(posedge clk) begin
    if (rst) begin
      inst_in_pipeline <= 1'b0;
    end else begin
      if (f__d_xfer) begin
        inst_in_pipeline <= 1'b1;
      end else if (trace_enq_val & trace_enq_rdy) begin
        inst_in_pipeline <= 1'b0;
      end else begin
        inst_in_pipeline <= inst_in_pipeline;
      end
    end
  end

  assign trace_enq_msg.pc    = commit_notif.pc;
  assign trace_enq_msg.waddr = commit_notif.waddr;
  assign trace_enq_msg.wdata = commit_notif.wdata;
  assign trace_enq_msg.wen   = commit_notif.wen;
  assign trace_enq_val       = commit_notif.val;

  assign trace_deq_rdy       = inst_trace_deq_rdy | ~debug;
  
  cmn_Queue #(
    .p_type      (`CMN_QUEUE_PIPE),
    .p_msg_nbits ($bits(trace_msg_t)),
    .p_num_msgs  (1)
  ) trace_queue (
    .clk              (clk),
    .reset            (rst),
    .enq_val          (trace_enq_val),
    .enq_rdy          (trace_enq_rdy),
    .enq_msg          (trace_enq_msg),
    .deq_val          (trace_deq_val),
    .deq_rdy          (trace_deq_rdy),
    .deq_msg          (trace_deq_msg),
    .num_free_entries (trace_queue_free_entry)
  );
  
  assign inst_trace.pc    = trace_deq_msg.pc;
  assign inst_trace.waddr = trace_deq_msg.waddr;
  assign inst_trace.wdata = trace_deq_msg.wdata;
  assign inst_trace.wen   = trace_deq_msg.wen;
  assign inst_trace.val   = trace_deq_val;

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

  FetchUnitL3 #(
    .p_max_in_flight (8)
  ) FU (
    .mem    (inst_mem),
    .D      (f__d_intf),
    .commit (commit_notif),
    .squash (squash_gnt_notif),
    .*
  );

  DecodeIssueUnitL5_sp26 #(
    .p_num_pipes     (p_num_pipes),
    .p_num_phys_regs (p_num_phys_regs),
    .p_pipe_subsets ({
      p_alu_subset, // ALU
      p_m_subset,   // M-Extension
      p_mem_subset, // Memory
      p_ctrl_subset // Control Flow
    })
  ) DIU (
    .F          (f__d_intf),
    .Ex         (d__x_intfs),
    .complete   (complete_notif),
    .squash_pub (squash_arb_notif[0]),
    .squash_sub (squash_gnt_notif),
    .commit     (commit_notif),
    .*
  );

  ALUL6 ALU_XU (
    .D (d__x_intfs[0]),
    .W (buffer_intf),
    .*
  );

  ExQueue #(1) alu_buf (
    .in  (buffer_intf),
    .out (x__w_intfs[0]),
    .*
  );

  IterativeMulDivRemL7 MUL_DIV_REM_XU (
    .D (d__x_intfs[1]),
    .W (x__w_intfs[1]),
    .*
  );

  LoadStoreUnitL7 #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_in_flight (p_num_in_flight)
  ) MEM_XU (
    .D   (d__x_intfs[2]),
    .W   (x__w_intfs[2]),
    .mem (data_mem),
    .*
  );

  ControlFlowUnitL6 CTRL_XU (
    .D      (d__x_intfs[3]),
    .W      (x__w_intfs[3]),
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
  function string trace( int trace_level );
    trace = "";
    trace = {trace, FU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, DIU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, ALU_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, MUL_DIV_REM_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, MEM_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, CTRL_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, WCU.trace( trace_level )};
  endfunction
`endif

endmodule

`endif // HW_TOP_BLIMPV8_V
