//========================================================================
// BlimpV9.v
//========================================================================
// A top-level implementation of the Blimp processor with support for
// RV32IM and Floating Point

`ifndef HW_TOP_BLIMPV9_V
`define HW_TOP_BLIMPV9_V

`include "defs/UArch.v"
`include "hw/fetch/fetch_unit_variants/FetchUnitL3.v"
`include "hw/decode_issue/decode_issue_unit_variants/DecodeIssueUnitL5_sp26.v"
`include "hw/execute/ExQueue.v"
`include "hw/execute/execute_units_l6/ALUL6.v"
`include "hw/execute/execute_units_l7/IterativeMulDivRemL7.v"
`include "hw/execute/execute_units_l7/LoadStoreUnitL7.v"
`include "hw/execute/execute_units_l6/ControlFlowUnitL6.v"
`include "hw/execute/execute_units_l8/ALUF.v"
`include "hw/execute/execute_units_l8/FPInstUnit.v"
`include "hw/execute/execute_units_l9/FPUMult.v"
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

module BlimpV9 #(
  parameter p_opaq_bits     = 8,
  parameter p_seq_num_bits  = 5,
  parameter p_num_phys_regs = 36
) (
  input logic clk,
  input logic rst,
  input logic debug_stall,

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

  localparam p_num_pipes      = 5;
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

  // Internal FP subunit D-interfaces
  D__XIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) fp_addsub_d_intf();

  D__XIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) fp_mul_d_intf();

  D__XIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) fp_inst_d_intf();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) x__w_intfs[p_num_pipes]();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) buffer_intf();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) buffer_fp_addsub_intf();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) buffer_fp_mul_intf();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) buffer_fp_inst_intf();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) buffer_fp_intf();

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
                           OP_SW_VEC  |
                           OP_FLW_VEC |
                           OP_FSW_VEC;

  parameter p_ctrl_subset = OP_JAL_VEC  |
                            OP_JALR_VEC |
                            OP_BEQ_VEC  |
                            OP_BNE_VEC  |
                            OP_BLT_VEC  |
                            OP_BGE_VEC  |
                            OP_BLTU_VEC |
                            OP_BGEU_VEC;

  parameter p_f_subset = OP_FADD_VEC     |
                         OP_FSUB_VEC     |
                         OP_FMUL_VEC     |
                         OP_FSGNJ_VEC    |
                         OP_FCVT_W_S_VEC |
                         OP_FMV_X_W_VEC  |
                         OP_FMV_W_X_VEC;

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
      p_alu_subset,  // ALU
      p_m_subset,    // M-Extension
      p_mem_subset,  // Memory
      p_ctrl_subset, // Control Flow
      p_f_subset     // Floating Point
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
    .p_opaq_bits (p_opaq_bits)
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

  //----------------------------------------------------------------------
  // Floating-point execute path (pipe 4)
  //----------------------------------------------------------------------

  logic fp_sel_addsub, fp_sel_mul, fp_sel_inst;

  always_comb begin
    fp_sel_addsub = 1'b0;
    fp_sel_mul    = 1'b0;
    fp_sel_inst   = 1'b0;

    unique case ( d__x_intfs[4].uop )
      OP_FADD_S,
      OP_FSUB_S: begin
        fp_sel_addsub = 1'b1;
      end

      OP_FMUL_S: begin
        fp_sel_mul = 1'b1;
      end

      OP_FSGNJ_S,
      OP_FCVT_W_S,
      OP_FMV_X_W,
      OP_FMV_W_X: begin
        fp_sel_inst = 1'b1;
      end

      default: begin
        fp_sel_addsub = 1'b0;
        fp_sel_mul    = 1'b0;
        fp_sel_inst   = 1'b0;
      end
    endcase
  end

  // Route common fields to all internal FP D interfaces
  assign fp_addsub_d_intf.pc      = d__x_intfs[4].pc;
  assign fp_addsub_d_intf.op1     = d__x_intfs[4].op1;
  assign fp_addsub_d_intf.op2     = d__x_intfs[4].op2;
  assign fp_addsub_d_intf.waddr   = d__x_intfs[4].waddr;
  assign fp_addsub_d_intf.uop     = d__x_intfs[4].uop;
  assign fp_addsub_d_intf.seq_num = d__x_intfs[4].seq_num;
  assign fp_addsub_d_intf.preg    = d__x_intfs[4].preg;
  assign fp_addsub_d_intf.ppreg   = d__x_intfs[4].ppreg;
  assign fp_addsub_d_intf.is_fp   = d__x_intfs[4].is_fp;
  assign fp_addsub_d_intf.op3     = d__x_intfs[4].op3;
  assign fp_addsub_d_intf.val     = d__x_intfs[4].val & fp_sel_addsub;

  assign fp_mul_d_intf.pc      = d__x_intfs[4].pc;
  assign fp_mul_d_intf.op1     = d__x_intfs[4].op1;
  assign fp_mul_d_intf.op2     = d__x_intfs[4].op2;
  assign fp_mul_d_intf.waddr   = d__x_intfs[4].waddr;
  assign fp_mul_d_intf.uop     = d__x_intfs[4].uop;
  assign fp_mul_d_intf.seq_num = d__x_intfs[4].seq_num;
  assign fp_mul_d_intf.preg    = d__x_intfs[4].preg;
  assign fp_mul_d_intf.ppreg   = d__x_intfs[4].ppreg;
  assign fp_mul_d_intf.is_fp   = d__x_intfs[4].is_fp;
  assign fp_mul_d_intf.op3     = d__x_intfs[4].op3;
  assign fp_mul_d_intf.val     = d__x_intfs[4].val & fp_sel_mul;

  assign fp_inst_d_intf.pc      = d__x_intfs[4].pc;
  assign fp_inst_d_intf.op1     = d__x_intfs[4].op1;
  assign fp_inst_d_intf.op2     = d__x_intfs[4].op2;
  assign fp_inst_d_intf.waddr   = d__x_intfs[4].waddr;
  assign fp_inst_d_intf.uop     = d__x_intfs[4].uop;
  assign fp_inst_d_intf.seq_num = d__x_intfs[4].seq_num;
  assign fp_inst_d_intf.preg    = d__x_intfs[4].preg;
  assign fp_inst_d_intf.ppreg   = d__x_intfs[4].ppreg;
  assign fp_inst_d_intf.is_fp   = d__x_intfs[4].is_fp;
  assign fp_inst_d_intf.op3     = d__x_intfs[4].op3;
  assign fp_inst_d_intf.val     = d__x_intfs[4].val & fp_sel_inst;

  // Only the selected subunit drives pipe-4 ready.
  always_comb begin
    d__x_intfs[4].rdy = 1'b1;

    if ( d__x_intfs[4].val ) begin
      if ( fp_sel_addsub )
        d__x_intfs[4].rdy = fp_addsub_d_intf.rdy;
      else if ( fp_sel_mul )
        d__x_intfs[4].rdy = fp_mul_d_intf.rdy;
      else if ( fp_sel_inst )
        d__x_intfs[4].rdy = fp_inst_d_intf.rdy;
      else
        d__x_intfs[4].rdy = 1'b0;
    end
  end

  ALUF FP_ADD_SUB_XU (
    .D (fp_addsub_d_intf),
    .W (buffer_fp_addsub_intf),
    .*
  );

  FPUMult FP_MUL_XU (
    .D (fp_mul_d_intf),
    .W (buffer_fp_mul_intf),
    .*
  );

  FPInstUnit FP_INST_XU (
    .D (fp_inst_d_intf),
    .W (buffer_fp_inst_intf),
    .*
  );

  // Selected FP producer gets backpressure from the shared FP output buffer
  assign buffer_fp_addsub_intf.rdy = buffer_fp_intf.rdy;
  assign buffer_fp_mul_intf.rdy    = buffer_fp_intf.rdy & (~buffer_fp_addsub_intf.val);
  assign buffer_fp_inst_intf.rdy   = buffer_fp_intf.rdy & (~buffer_fp_addsub_intf.val) & (~buffer_fp_mul_intf.val);

  // FP result mux
  always_comb begin
    buffer_fp_intf.val     = 1'b0;
    buffer_fp_intf.pc      = '0;
    buffer_fp_intf.waddr   = '0;
    buffer_fp_intf.wdata   = '0;
    buffer_fp_intf.wen     = 1'b0;
    buffer_fp_intf.seq_num = '0;
    buffer_fp_intf.preg    = '0;
    buffer_fp_intf.ppreg   = '0;
    buffer_fp_intf.is_fp   = 1'b0;

    if ( buffer_fp_addsub_intf.val ) begin
      buffer_fp_intf.val     = buffer_fp_addsub_intf.val;
      buffer_fp_intf.pc      = buffer_fp_addsub_intf.pc;
      buffer_fp_intf.waddr   = buffer_fp_addsub_intf.waddr;
      buffer_fp_intf.wdata   = buffer_fp_addsub_intf.wdata;
      buffer_fp_intf.wen     = buffer_fp_addsub_intf.wen;
      buffer_fp_intf.seq_num = buffer_fp_addsub_intf.seq_num;
      buffer_fp_intf.preg    = buffer_fp_addsub_intf.preg;
      buffer_fp_intf.ppreg   = buffer_fp_addsub_intf.ppreg;
      buffer_fp_intf.is_fp   = buffer_fp_addsub_intf.is_fp;
    end
    else if ( buffer_fp_mul_intf.val ) begin
      buffer_fp_intf.val     = buffer_fp_mul_intf.val;
      buffer_fp_intf.pc      = buffer_fp_mul_intf.pc;
      buffer_fp_intf.waddr   = buffer_fp_mul_intf.waddr;
      buffer_fp_intf.wdata   = buffer_fp_mul_intf.wdata;
      buffer_fp_intf.wen     = buffer_fp_mul_intf.wen;
      buffer_fp_intf.seq_num = buffer_fp_mul_intf.seq_num;
      buffer_fp_intf.preg    = buffer_fp_mul_intf.preg;
      buffer_fp_intf.ppreg   = buffer_fp_mul_intf.ppreg;
      buffer_fp_intf.is_fp   = buffer_fp_mul_intf.is_fp;
    end
    else if ( buffer_fp_inst_intf.val ) begin
      buffer_fp_intf.val     = buffer_fp_inst_intf.val;
      buffer_fp_intf.pc      = buffer_fp_inst_intf.pc;
      buffer_fp_intf.waddr   = buffer_fp_inst_intf.waddr;
      buffer_fp_intf.wdata   = buffer_fp_inst_intf.wdata;
      buffer_fp_intf.wen     = buffer_fp_inst_intf.wen;
      buffer_fp_intf.seq_num = buffer_fp_inst_intf.seq_num;
      buffer_fp_intf.preg    = buffer_fp_inst_intf.preg;
      buffer_fp_intf.ppreg   = buffer_fp_inst_intf.ppreg;
      buffer_fp_intf.is_fp   = buffer_fp_inst_intf.is_fp;
    end
  end

  ExQueue #(1) fp_buf (
    .in  (buffer_fp_intf),
    .out (x__w_intfs[4]),
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
    trace = {trace, FP_ADD_SUB_XU.trace( trace_level )};
    trace = {trace, "/"};
    trace = {trace, FP_MUL_XU.trace( trace_level )};
    trace = {trace, "/"};
    trace = {trace, FP_INST_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, WCU.trace( trace_level )};
  endfunction
`endif

endmodule

`endif
