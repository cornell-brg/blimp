//========================================================================
// BlimpV11.v
//========================================================================
// A top-level implementation of the Blimp processor with support for
// RV32IM (no exceptions) and superscalar issue and backend

`ifndef HW_TOP_BLIMPV11_V
`define HW_TOP_BLIMPV11_V

`include "defs/UArch.v"
`include "hw/fetch/fetch_unit_variants/FetchUnitL5.v"
`include "hw/decode_issue/decode_issue_unit_variants/DecodeIssueUnitL8.v"
`include "hw/execute/execute_units_l6/ALUL6.v"
`include "hw/execute/execute_units_l7/IterativeMulDivRemL7.v"
`include "hw/execute/execute_units_l7/LoadStoreUnitL7.v"
`include "hw/execute/execute_units_l6/ControlFlowUnitL6.v"
`include "hw/squash/SquashUnitL3.v"
`include "hw/writeback_commit/writeback_commit_unit_variants/WritebackCommitUnitL4.v"
`include "hw/util/F__DDelay.v"
`include "hw/util/D__XDelay.v"
`include "hw/util/X__WDelay.v"
`include "intf/MemIntf.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"
`include "intf/SquashNotif.v"
`include "intf/InstTraceNotif.v"

module BlimpV11 #(
  parameter p_opaq_bits               = 8,
  parameter p_seq_num_bits            = 5,
  parameter p_num_phys_regs           = 36,
  parameter p_num_fe_lanes            = 2,
  parameter p_num_be_lanes            = 2, // must be <= 2**p_seq_num_bits (ROB depth)
  parameter p_iq_depth                = 8,
  parameter p_reclaim_width           = p_num_be_lanes,
  parameter p_max_in_flight           = 8,
  parameter p_f_intf_fifo_depth       = 4,
  parameter p_x_intf_fifo_depth       = 4,
  parameter p_alu_d_intf_fifo_depth   = 4,
  parameter p_mul_d_intf_fifo_depth   = 4,
  parameter p_mem_d_intf_fifo_depth   = 4,
  parameter p_ctrl_d_intf_fifo_depth  = 1, // must be 1 - 1-cycle brx resolution
  parameter p_num_alus                = 4,
  parameter p_num_muls                = 2,
  parameter p_num_ldstrs              = 1,
  parameter p_num_pipes               = p_num_alus + p_num_muls + p_num_ldstrs + 1,
  parameter p_pipe_bypass             = '0, // bitmask of which pipes can bypass
  parameter p_all_iq_in_order         = 0,

  // Simulation-only backpressure parameters (ignored in synthesis)
  // Packed arrays: 8 bits per lane/pipe. Stall 1 cycle every N; 0 = off.
  parameter [p_num_fe_lanes*8-1:0] p_sim_f2d_bp = '0,
  parameter [p_num_pipes*8-1:0]    p_sim_d2x_bp = '0,
  parameter [p_num_pipes*8-1:0]    p_sim_x2w_bp = '0 
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

  InstTraceNotif.pub inst_trace [p_num_be_lanes]
);

  localparam p_phys_addr_bits = $clog2( p_num_phys_regs );

  //----------------------------------------------------------------------
  // Interfaces
  //----------------------------------------------------------------------

  F__DIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) f__d_intfs[p_num_fe_lanes]();

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
  ) squash_diu_pub_notif();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_arb_notif [2]();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_gnt_notif();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_gnt_excl_notif();

  CompleteNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) complete_notif [p_num_be_lanes]();

  CommitNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) commit_notif [p_num_be_lanes]();

  //----------------------------------------------------------------------
  // Delayed Interfaces
  //----------------------------------------------------------------------
  // Intermediate interfaces for simulation-only delay injection between
  // major pipeline stages. Downstream modules connect to these.

  F__DIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) f__d_del[p_num_fe_lanes]();

  D__XIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) d__x_del[p_num_pipes]();

  X__WIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) x__w_del[p_num_pipes]();

  logic [4:0] unused_complete_waddr [p_num_be_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign inst_trace[i].pc         = commit_notif[i].pc;
      assign inst_trace[i].waddr      = commit_notif[i].waddr;
      assign inst_trace[i].wdata      = commit_notif[i].wdata;
      assign inst_trace[i].wen        = commit_notif[i].wen;
      assign inst_trace[i].val        = commit_notif[i].val;
      assign inst_trace[i].seq_num    = commit_notif[i].seq_num;
      assign unused_complete_waddr[i] = complete_notif[i].waddr;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Delay / Pass-through
  //----------------------------------------------------------------------

`ifndef SYNTHESIS

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: F2D_DELAY
      F__DDelay #(
        .p_seq_num_bits (p_seq_num_bits),
        .p_bp_interval  (p_sim_f2d_bp[i*8 +: 8])
      ) f2d_delay (
        .clk (clk),
        .rst (rst),
        .up  (f__d_intfs[i]),
        .dn  (f__d_del[i])
      );
    end
  endgenerate

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin: D2X_DELAY
      D__XDelay #(
        .p_seq_num_bits   (p_seq_num_bits),
        .p_phys_addr_bits (p_phys_addr_bits),
        .p_bp_interval    (p_sim_d2x_bp[i*8 +: 8])
      ) d2x_delay (
        .clk (clk),
        .rst (rst),
        .up  (d__x_intfs[i]),
        .dn  (d__x_del[i])
      );
    end
  endgenerate

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin: X2W_DELAY
      X__WDelay #(
        .p_seq_num_bits   (p_seq_num_bits),
        .p_phys_addr_bits (p_phys_addr_bits),
        .p_bp_interval    (p_sim_x2w_bp[i*8 +: 8])
      ) x2w_delay (
        .clk (clk),
        .rst (rst),
        .up  (x__w_intfs[i]),
        .dn  (x__w_del[i])
      );
    end
  endgenerate

`else

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: F2D_PASSTHRU
      assign f__d_del[i].inst        = f__d_intfs[i].inst;
      assign f__d_del[i].pc          = f__d_intfs[i].pc;
      assign f__d_del[i].val         = f__d_intfs[i].val;
      assign f__d_del[i].seq_num     = f__d_intfs[i].seq_num;
      assign f__d_del[i].inst_status = f__d_intfs[i].inst_status;
      assign f__d_intfs[i].rdy       = f__d_del[i].rdy;
    end
  endgenerate

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin: D2X_PASSTHRU
      assign d__x_del[i].pc      = d__x_intfs[i].pc;
      assign d__x_del[i].op1     = d__x_intfs[i].op1;
      assign d__x_del[i].op2     = d__x_intfs[i].op2;
      assign d__x_del[i].waddr   = d__x_intfs[i].waddr;
      assign d__x_del[i].uop     = d__x_intfs[i].uop;
      assign d__x_del[i].val     = d__x_intfs[i].val;
      assign d__x_del[i].seq_num = d__x_intfs[i].seq_num;
      assign d__x_del[i].preg    = d__x_intfs[i].preg;
      assign d__x_del[i].ppreg   = d__x_intfs[i].ppreg;
      assign d__x_del[i].op3     = d__x_intfs[i].op3;
      assign d__x_intfs[i].rdy   = d__x_del[i].rdy;
    end
  endgenerate

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin: X2W_PASSTHRU
      assign x__w_del[i].pc      = x__w_intfs[i].pc;
      assign x__w_del[i].waddr   = x__w_intfs[i].waddr;
      assign x__w_del[i].wdata   = x__w_intfs[i].wdata;
      assign x__w_del[i].wen     = x__w_intfs[i].wen;
      assign x__w_del[i].val     = x__w_intfs[i].val;
      assign x__w_del[i].seq_num = x__w_intfs[i].seq_num;
      assign x__w_del[i].preg    = x__w_intfs[i].preg;
      assign x__w_del[i].ppreg   = x__w_intfs[i].ppreg;
      assign x__w_intfs[i].rdy   = x__w_del[i].rdy;
    end
  endgenerate

`endif

  //----------------------------------------------------------------------
  // Units
  //----------------------------------------------------------------------

  localparam p_alu_subset = OP_ADD_VEC  |
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

  localparam p_m_subset   = OP_MUL_VEC    |
                            OP_MULH_VEC   |
                            OP_MULHU_VEC  |
                            OP_MULHSU_VEC |
                            OP_DIV_VEC    |
                            OP_DIVU_VEC   |
                            OP_REM_VEC    |
                            OP_REMU_VEC;

  localparam p_mem_subset = OP_LB_VEC  |
                            OP_LH_VEC  |
                            OP_LW_VEC  |
                            OP_LBU_VEC |
                            OP_LHU_VEC |
                            OP_SB_VEC  |
                            OP_SH_VEC  |
                            OP_SW_VEC;

  localparam p_ctrl_subset = OP_JAL_VEC  |
                             OP_JALR_VEC |
                             OP_BEQ_VEC  |
                             OP_BNE_VEC  |
                             OP_BLT_VEC  |
                             OP_BGE_VEC  |
                             OP_BLTU_VEC |
                             OP_BGEU_VEC;

  // Pipe index offsets for MEM and CTRL units
  localparam p_mem_pipe_idx  = p_num_alus + p_num_muls;
  localparam p_ctrl_pipe_idx = p_num_alus + p_num_muls + p_num_ldstrs;

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

  FetchUnitL5 #(
    .p_reclaim_width (p_reclaim_width),
    .p_seq_num_bits  (p_seq_num_bits),
    .p_num_phys_regs (p_num_phys_regs),
    .p_max_in_flight (p_max_in_flight),
    .p_num_fe_lanes  (p_num_fe_lanes),
    .p_num_be_lanes  (p_num_be_lanes)
  ) FU (
    .mem    (inst_mem),
    .D      (f__d_intfs),
    .commit (commit_notif),
    .squash (squash_gnt_notif),
    .*
  );

  DecodeIssueUnitL8 #(
    .p_num_pipes          (p_num_pipes),
    .p_seq_num_bits       (p_seq_num_bits),
    .p_num_phys_regs      (p_num_phys_regs),
    .p_num_fe_lanes       (p_num_fe_lanes),
    .p_num_be_lanes       (p_num_be_lanes),
    .p_iq_depth           (p_iq_depth),
    .p_pipe_subsets       (c_pipe_subsets),
    .p_pipe_bypass        (p_pipe_bypass),
    .p_ctrl_subset        (p_ctrl_subset),
    .p_mem_subset         (p_mem_subset),
    .p_all_iq_in_order    (p_all_iq_in_order),
    .p_f_intf_fifo_depth  (p_f_intf_fifo_depth)
  ) DIU (
    .F          (f__d_del),
    .Ex         (d__x_intfs),
    .complete   (complete_notif),
    .squash_pub (squash_arb_notif[0]),
    .squash_sub (squash_gnt_excl_notif),
    .commit     (commit_notif),
    .*
  );

`ifndef SYNTHESIS
  string alu_trace_l0 [p_num_alus];
  string alu_trace_l1 [p_num_alus];
  string alu_json     [p_num_alus];
  string mul_trace_l0 [p_num_muls];
  string mul_trace_l1 [p_num_muls];
  string mul_json     [p_num_muls];
  string ldstr_trace_l0 [p_num_ldstrs];
  string ldstr_trace_l1 [p_num_ldstrs];
  string ldstr_json     [p_num_ldstrs];
`endif

  generate
    for( i = 0; i < p_num_alus; i++ ) begin: ALU_XU_GEN
      ALUL6 #(
        .p_d_intf_fifo_depth (p_alu_d_intf_fifo_depth)
      ) ALU_XU (
        .D (d__x_del[i]),
        .W (x__w_intfs[i]),
        .*
      );
`ifndef SYNTHESIS
      always_comb begin
        alu_trace_l0[i] = ALU_XU.trace_str_l0;
        alu_trace_l1[i] = ALU_XU.trace_str_l1;
        alu_json[i]     = ALU_XU.trace_json_str;
      end
`endif
    end
  endgenerate

  generate
    for( i = 0; i < p_num_muls; i++ ) begin: MUL_XU_GEN
      IterativeMulDivRemL7 #(
        .p_d_intf_fifo_depth (p_mul_d_intf_fifo_depth)
      ) MUL_DIV_REM_XU (
        .D (d__x_del[p_num_alus + i]),
        .W (x__w_intfs[p_num_alus + i]),
        .*
      );
`ifndef SYNTHESIS
      always_comb begin
        mul_trace_l0[i] = MUL_DIV_REM_XU.trace_str_l0;
        mul_trace_l1[i] = MUL_DIV_REM_XU.trace_str_l1;
        mul_json[i]     = MUL_DIV_REM_XU.trace_json_str;
      end
`endif
    end
  endgenerate

  generate
    for( i = 0; i < p_num_ldstrs; i++ ) begin: MEM_XU_GEN
      LoadStoreUnitL7 #(
        .p_opaq_bits         (p_opaq_bits),
        .p_num_in_flight     (p_max_in_flight),
        .p_d_intf_fifo_depth (p_mem_d_intf_fifo_depth)
      ) MEM_XU (
        .D   (d__x_del[p_mem_pipe_idx + i]),
        .W   (x__w_intfs[p_mem_pipe_idx + i]),
        .mem (data_mem[i]),
        .*
      );
`ifndef SYNTHESIS
      always_comb begin
        ldstr_trace_l0[i] = MEM_XU.trace_str_l0;
        ldstr_trace_l1[i] = MEM_XU.trace_str_l1;
        ldstr_json[i]     = MEM_XU.trace_json_str;
      end
`endif
    end
  endgenerate

  ControlFlowUnitL6 #(
    .p_d_intf_fifo_depth (p_ctrl_d_intf_fifo_depth)
  ) CTRL_XU (
    .D      (d__x_del[p_ctrl_pipe_idx]),
    .W      (x__w_intfs[p_ctrl_pipe_idx]),
    .squash (squash_arb_notif[1]),
    .*
  );

  WritebackCommitUnitL4 #(
    .p_num_pipes          (p_num_pipes),
    .p_num_be_lanes       (p_num_be_lanes),
    .p_seq_num_bits       (p_seq_num_bits),
    .p_phys_addr_bits     (p_phys_addr_bits),
    .p_x_intf_fifo_depth  (p_x_intf_fifo_depth)
  ) WCU (
    .Ex       (x__w_del),
    .complete (complete_notif),
    .commit   (commit_notif),
    .*
  );

  SquashUnitL3 #(
    .p_num_arb       (2),
    .p_diu_idx       (0),
    .p_num_be_lanes  (p_num_be_lanes),
    .p_seq_num_bits  (p_seq_num_bits),
    .p_num_phys_regs (p_num_phys_regs)
  ) SU (
    .arb      (squash_arb_notif),
    .gnt      (squash_gnt_notif),
    .gnt_excl (squash_gnt_excl_notif),
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
    for( int i = 0; i < p_num_alus; i++ ) begin
      trace = {trace, " | "};
      trace = {trace, (trace_level > 0) ? alu_trace_l1[i] : alu_trace_l0[i]};
    end
    for( int i = 0; i < p_num_muls; i++ ) begin
      trace = {trace, " | "};
      trace = {trace, (trace_level > 0) ? mul_trace_l1[i] : mul_trace_l0[i]};
    end
    for( int i = 0; i < p_num_ldstrs; i++ ) begin
      trace = {trace, " | "};
      trace = {trace, (trace_level > 0) ? ldstr_trace_l1[i] : ldstr_trace_l0[i]};
    end
    trace = {trace, " | "};
    trace = {trace, CTRL_XU.trace( trace_level )};
    trace = {trace, " | "};
    trace = {trace, WCU.trace( trace_level )};
  endfunction

  function string trace_json();
    trace_json = "";

    // Fetch Unit
    trace_json = {trace_json, "\"fu\":",   FU.trace_json()};

    // Decode/Issue Unit (per lane)
    for( int i = 0; i < p_num_fe_lanes; i++ )
      trace_json = {trace_json, $sformatf(",\"diu_%0d\":", i), DIU.trace_json_lane(i)};

    // ALU Units
    for( int i = 0; i < p_num_alus; i++ )
      trace_json = {trace_json, $sformatf(",\"alu_%0d\":", i), alu_json[i]};

    // Multiplier/Divider Units
    for( int i = 0; i < p_num_muls; i++ )
      trace_json = {trace_json, $sformatf(",\"mul_%0d\":", i), mul_json[i]};

    // Memory Units
    for( int i = 0; i < p_num_ldstrs; i++ )
      trace_json = {trace_json, $sformatf(",\"mem_%0d\":", i), ldstr_json[i]};

    // Control Flow Unit
    trace_json = {trace_json, ",\"ctrl\":", CTRL_XU.trace_json()};

    // Squash Unit
    trace_json = {trace_json, ",\"squash\":", SU.trace_json()};

    // Writeback/Commit Unit (per lane)
    for( int i = 0; i < p_num_be_lanes; i++ )
      trace_json = {trace_json, $sformatf(",\"wcu_%0d\":", i), WCU.trace_json_lane(i)};
  endfunction
`endif

endmodule

`endif // HW_TOP_BLIMPV11_V
