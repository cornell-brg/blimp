//========================================================================
// DecodeIssueUnitL8.v
//========================================================================
// An in-order, single-issue decoder with register renaming and support for
// superscalar backend

`ifndef HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V
`define HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V

`ifndef SYNTHESIS
`include "asm/disassemble.v"
`endif

`include "defs/ISA.v"
`include "hw/decode_issue/InstDecoder.v"
`include "hw/decode_issue/ImmGen.v"
`include "hw/decode_issue/SSInstXbarCtrl.v"
`include "hw/decode_issue/SSRegfileL2.v"
`include "hw/decode_issue/SSRenameTableL3.v"
`include "hw/decode_issue/IssueQueueInOrder.v"
`include "hw/util/SSSeqAge.v"
`include "hw/decode_issue/DecodeIssueUnitBypassFifo.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/SquashNotif.v"
`include "hw/decode_issue/InsnChecks.v"

import ISA::*;

module DecodeIssueUnitL8 #(
  parameter p_num_pipes                                = 1,
  parameter p_num_phys_regs                            = 36,
  parameter p_num_fe_lanes                             = 2,
  parameter p_num_be_lanes                             = 2,
  parameter p_iq_depth                                 = 8,
  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1},
  parameter rv_op_vec p_ctrl_subset                    = OP_JAL_VEC  |
                                                         OP_JALR_VEC |
                                                         OP_BEQ_VEC  |
                                                         OP_BNE_VEC  |
                                                         OP_BLT_VEC  |
                                                         OP_BGE_VEC  |
                                                         OP_BLTU_VEC |
                                                         OP_BGEU_VEC,
  parameter rv_op_vec p_brx_subset                     = OP_BEQ_VEC  |
                                                         OP_BNE_VEC  |
                                                         OP_BLT_VEC  |
                                                         OP_BGE_VEC  |
                                                         OP_BLTU_VEC |
                                                         OP_BGEU_VEC,
  parameter p_f_fifo_depth                             = 4,
  parameter p_f_fifo_bypass                            = 0,
  parameter p_iq_entries_bits                          = p_iq_depth > 1 ? $clog2(p_iq_depth) : 1
) (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // F <-> D Interface
  //----------------------------------------------------------------------

  F__DIntf.D_intf F [p_num_fe_lanes],

  //----------------------------------------------------------------------
  // D <-> X Interface
  //----------------------------------------------------------------------

  D__XIntf.D_intf Ex [p_num_pipes],

  //----------------------------------------------------------------------
  // Completion Notification
  //----------------------------------------------------------------------

  CompleteNotif.sub complete [p_num_be_lanes],

  //----------------------------------------------------------------------
  // Commit Notification
  //----------------------------------------------------------------------

  CommitNotif.sub commit [p_num_be_lanes],

  //----------------------------------------------------------------------
  // Squash Notification (one to request, one to receive)
  //----------------------------------------------------------------------

  SquashNotif.pub squash_pub,
  SquashNotif.sub squash_sub
);

  localparam p_seq_num_bits     = F[0].p_seq_num_bits;
  localparam p_phys_addr_bits   = $clog2( p_num_phys_regs );
  localparam p_fe_lane_idx_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1;
  localparam p_pipe_bits        = p_num_pipes > 1 ? $clog2(p_num_pipes) : 1;

  //----------------------------------------------------------------------
  // Instruction window FIFO
  //----------------------------------------------------------------------

  logic [p_fe_lane_idx_bits-1:0] pipe_to_lane_map [p_num_pipes];
  logic dispatch_go [p_num_fe_lanes];
  logic alloc_rdy   [p_num_fe_lanes];
  logic oldest_ctrl_insn_srcs_ready;

  logic stage_pass_s1      [p_num_fe_lanes];
  logic invalidate_insn    [p_num_fe_lanes];

  // Head entry outputs from FIFO wrapper
  logic                      fifo_pop;
  logic                      fifo_empty;
  logic [p_num_fe_lanes-1:0] fifo_set_invalid;
  logic [p_num_fe_lanes-1:0] fifo_set_dispatched;

  typedef struct packed {
    logic                      val;
    logic               [31:0] inst;
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
    logic                      insn_valid;
    logic                      dispatched;
  } fifo_lane_t;

  fifo_lane_t F_curr [p_num_fe_lanes];

  DecodeIssueUnitBypassFifo #(
    .t_msg          (fifo_lane_t),
    .p_seq_num_bits (p_seq_num_bits),
    .p_depth        (p_f_fifo_depth),
    .p_bypass       (p_f_fifo_bypass),
    .p_num_lanes    (p_num_fe_lanes)
  ) f_fifo (
    .clk                 (clk),
    .rst                 (rst | squash_sub.val | squash_pub_val_comb),
    .F                   (F),
    .pop                 (fifo_pop),
    .empty               (fifo_empty),
    .o_msg               (F_curr),
    .edit_set_invalid    (fifo_set_invalid),
    .edit_set_dispatched (fifo_set_dispatched)
  );

  // Wire edit signals from invalidation/dispatch to FIFO shadow state
  always_comb begin
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      fifo_set_invalid[j]    = invalidate_insn[j];
      fifo_set_dispatched[j] = dispatch_go[j];
    end
  end

  // Pop when done processing current instruction window
  // Each lane must be: invalid (stage_pass_s1 false), dispatching
  // this cycle, or already dispatched
  logic F_rdy_all;
  always_comb begin
    F_rdy_all = oldest_ctrl_insn_srcs_ready;
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      F_rdy_all &= (
        !stage_pass_s1[j] |
        dispatch_go[j]    |
        F_curr[j].dispatched
      );
    end
  end

  assign fifo_pop = F_rdy_all & !fifo_empty;

  //----------------------------------------------------------------------
  // Decode
  //----------------------------------------------------------------------

  logic       decoder_val     [p_num_fe_lanes];
  rv_uop      decoder_uop     [p_num_fe_lanes];
  logic [4:0] decoder_raddr0  [p_num_fe_lanes];
  logic [4:0] decoder_raddr1  [p_num_fe_lanes];
  logic [4:0] decoder_waddr   [p_num_fe_lanes];
  logic       decoder_wen     [p_num_fe_lanes];
  rv_imm_type decoder_imm_sel [p_num_fe_lanes];
  logic       decoder_op2_sel [p_num_fe_lanes];
  logic [1:0] decoder_jal     [p_num_fe_lanes];
  logic       decoder_op3_sel [p_num_fe_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: DECODER_GEN
      InstDecoder decoder (
        .val     (decoder_val[i]),
        .inst    (F_curr[i].inst),
        .uop     (decoder_uop[i]),
        .raddr0  (decoder_raddr0[i]),
        .raddr1  (decoder_raddr1[i]),
        .waddr   (decoder_waddr[i]),
        .wen     (decoder_wen[i]),
        .imm_sel (decoder_imm_sel[i]),
        .op2_sel (decoder_op2_sel[i]),
        .jal     (decoder_jal[i]),
        .op3_sel (decoder_op3_sel[i])
      );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Find oldest control instruction in IW if present
  //----------------------------------------------------------------------

  logic [p_fe_lane_idx_bits-1:0] oldest_ctrl_insn_idx;
  logic [p_seq_num_bits-1:0]     oldest_ctrl_insn_seq_num;
  logic                          oldest_ctrl_insn_found;
  logic                          oldest_ctrl_insn_is_brx;

  logic [p_phys_addr_bits-1:0] lookup_iq_preg    [p_num_pipes+1][2];
  logic                        lookup_iq_en      [p_num_pipes+1][2];
  logic                        lookup_iq_pending [p_num_pipes+1][2];

  logic [p_phys_addr_bits-1:0] lookup_new_inst_preg [p_num_fe_lanes][2];

  SSSeqAge #(
    .p_num_be_lanes (p_num_be_lanes)
  ) seq_age (
    .clk    (clk),
    .rst    (rst),
    .commit (commit)
  );

  always_comb begin
    oldest_ctrl_insn_idx      = '0;
    oldest_ctrl_insn_seq_num  = F_curr[p_num_fe_lanes-1].seq_num;
    oldest_ctrl_insn_found    = 1'b0;
    oldest_ctrl_insn_is_brx   = 1'b0;

    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      logic is_brx, is_jal, is_valid;
      is_brx   = in_subset(p_brx_subset, num_ops'(1 << decoder_uop[k]));
      is_jal   = (decoder_jal[k] != 2'd0);
      is_valid = stage_pass_s1[k] && !F_curr[k].dispatched;

      if( (is_brx || is_jal) && is_valid &&
          (!oldest_ctrl_insn_found ||
           seq_age.is_older(F_curr[k].seq_num, oldest_ctrl_insn_seq_num))
        )
      begin
        oldest_ctrl_insn_idx      = p_fe_lane_idx_bits'(k);
        oldest_ctrl_insn_seq_num  = F_curr[k].seq_num;
        oldest_ctrl_insn_found    = 1'b1;
        oldest_ctrl_insn_is_brx   = is_brx;
      end
    end
  end

  always_comb begin
    oldest_ctrl_insn_srcs_ready = 1'b1;
    lookup_iq_en[p_num_pipes][0] = 1'b0;
    lookup_iq_en[p_num_pipes][1] = 1'b0;
    lookup_iq_preg[p_num_pipes][0] = '0;
    lookup_iq_preg[p_num_pipes][1] = '0;
    if( oldest_ctrl_insn_found ) begin
      lookup_iq_en[p_num_pipes][0] = 1'b1;
      lookup_iq_preg[p_num_pipes][0] = lookup_new_inst_preg[oldest_ctrl_insn_idx][0];
      if( oldest_ctrl_insn_is_brx ) begin
        lookup_iq_en[p_num_pipes][1] = 1'b1;
        lookup_iq_preg[p_num_pipes][1] = lookup_new_inst_preg[oldest_ctrl_insn_idx][1];
      end
      oldest_ctrl_insn_srcs_ready =
        !lookup_iq_pending[p_num_pipes][0] &
        (!oldest_ctrl_insn_is_brx | !lookup_iq_pending[p_num_pipes][1]);
    end
  end

  //----------------------------------------------------------------------
  // Instruction check stage 1: validation
  //----------------------------------------------------------------------

  logic invalidate_insn_s1 [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INSN_CHECK_S1_GEN
      InsnCheckS1 check_s1 (
        .prev_stage_pass (1'b1),
        .o_pass          (stage_pass_s1[i]),
        .o_invalidate    (invalidate_insn_s1[i]),

        .entry_val        (F_curr[i].val),
        .entry_insn_val   (F_curr[i].insn_valid),
        .decoder_val      (decoder_val[i])
      );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Instruction check stage 2: check against control instruction
  //----------------------------------------------------------------------

  logic stage_pass_s2      [p_num_fe_lanes];
  logic invalidate_insn_s2 [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INSN_CHECK_S2_GEN
      InsnCheckS2 #(
        .insn_idx (i),
        .p_num_fe_lanes (p_num_fe_lanes)
      ) check_s2 (
        .prev_stage_pass (stage_pass_s1[i]),
        .o_pass          (stage_pass_s2[i]),
        .o_invalidate    (invalidate_insn_s2[i]),

        .oldest_ctrl_insn_found       (oldest_ctrl_insn_found),
        .oldest_ctrl_insn_is_brx      (oldest_ctrl_insn_is_brx),
        .oldest_ctrl_insn_idx         (oldest_ctrl_insn_idx),
        .oldest_ctrl_insn_srcs_ready  (oldest_ctrl_insn_srcs_ready),
        .oldest_ctrl_insn_dispatch_en (stage_pass_s4[oldest_ctrl_insn_idx]),

        .squash_sub_val               (squash_sub.val)
      );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Instruction check stage 3: check if can allocate preg for areg
  //----------------------------------------------------------------------

  logic prev_insn_pass_s3  [p_num_fe_lanes];
  logic stage_pass_s3      [p_num_fe_lanes];
  logic invalidate_insn_s3 [p_num_fe_lanes];

  logic alloc_try_s3 [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INSN_CHECK_S3_GEN
      InsnCheckS3 check_s3 (
        .prev_insn_pass  (i == 0 ? 1'b1 : prev_insn_pass_s3[i-1]),
        .prev_stage_pass (stage_pass_s2[i]),
        .o_pass          (stage_pass_s3[i]),
        .o_invalidate    (invalidate_insn_s3[i]),
        .decoder_wen     (decoder_wen[i]),

        .alloc_try (alloc_try_s3[i]),
        .alloc_rdy (alloc_rdy[i]),

        .dispatched (F_curr[i].dispatched)
      );

      // The next insn's S3 check will see this instruction as ok
      // if it is invalid, since it won't need a preg
      assign prev_insn_pass_s3[i] = stage_pass_s3[i] || !F_curr[i].insn_valid;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Instruction check stage 4: check for structural hazard
  //----------------------------------------------------------------------

  logic prev_insn_pass_s4  [p_num_fe_lanes];
  logic stage_pass_s4      [p_num_fe_lanes];
  logic invalidate_insn_s4 [p_num_fe_lanes];

  logic                   lane_val         [p_num_fe_lanes];
  logic [p_pipe_bits-1:0] lane_to_pipe_map [p_num_fe_lanes];

  logic                   iq_val [p_num_pipes];

  always_comb begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      lane_to_pipe_map[i] = '0;
      lane_val[i] = 1'b0;
      for( int j = 0; j < p_num_pipes; j++ ) begin
        if( iq_val[j] && pipe_to_lane_map[j] == p_fe_lane_idx_bits'(i) ) begin
          lane_to_pipe_map[i] = p_pipe_bits'(j);
          lane_val[i] = 1'b1;
        end
      end
    end
  end

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INSN_CHECK_S4_GEN
      InsnCheckS4 check_s4(
        .prev_insn_pass  (i == 0 ? 1'b1 : prev_insn_pass_s4[i-1]),
        .prev_stage_pass (stage_pass_s3[i]),
        .o_pass          (stage_pass_s4[i]),
        .o_invalidate    (invalidate_insn_s4[i]),

        .dispatched (F_curr[i].dispatched),
        .prev_insn_dispatched(i == 0 ? 1'b1 : F_curr[i-1].dispatched),
        .lane_val   (lane_val[i])
      );

      assign prev_insn_pass_s4[i] = stage_pass_s4[i] || !F_curr[i].insn_valid;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Invalidate instruction
  //----------------------------------------------------------------------

  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      invalidate_insn[k] =
        invalidate_insn_s1[k] |
        invalidate_insn_s2[k] |
        invalidate_insn_s3[k] |
        invalidate_insn_s4[k];
    end
  end

  //----------------------------------------------------------------------
  // Rename Table and Register File
  //----------------------------------------------------------------------

  logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes];
  logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes];

  logic                  [4:0] lookup_new_inst_areg [p_num_fe_lanes][2];
  logic                        lookup_new_inst_en   [p_num_fe_lanes][2];

  logic alloc_try [p_num_fe_lanes];
  logic alloc_val [p_num_fe_lanes];

  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      lookup_new_inst_areg[k][0] = decoder_raddr0[k];
      lookup_new_inst_areg[k][1] = decoder_raddr1[k];
      lookup_new_inst_en[k][0] = 1'b1;
      lookup_new_inst_en[k][1] = 1'b1;
      alloc_try[k] = stage_pass_s1[k] &
                     !F_curr[k].dispatched;
    end
  end

  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      alloc_val[k] = alloc_try[k] && dispatch_go[k];
    end
  end

  SSRenameTableL3 #(
    .p_num_phys_regs    (p_num_phys_regs),
    .p_num_lookup_ports (p_num_pipes+1),
    .p_num_fe_lanes     (p_num_fe_lanes),
    .p_num_be_lanes     (p_num_be_lanes)
  ) rename_table (
    .clk            (clk),
    .rst            (rst),

    .alloc_areg     (decoder_waddr),
    .alloc_preg     (alloc_preg),
    .alloc_ppreg    (alloc_ppreg),
    .alloc_try      (alloc_try),
    .alloc_val      (alloc_val),
    .alloc_rdy      (alloc_rdy),

    .lookup_new_inst_areg    (lookup_new_inst_areg),
    .lookup_new_inst_en      (lookup_new_inst_en),
    .lookup_new_inst_preg    (lookup_new_inst_preg),

    .lookup_iq_preg    (lookup_iq_preg),
    .lookup_iq_en      (lookup_iq_en),
    .lookup_iq_pending (lookup_iq_pending),

    .complete       (complete),
    .commit         (commit)
  );

  logic [p_phys_addr_bits-1:0] complete_preg        [p_num_be_lanes];
  logic [31:0]                 complete_wdata       [p_num_be_lanes];
  logic                        complete_wen_and_val [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin: COMPLETE_SIGNALS_GEN
      assign complete_preg[i]        = complete[i].preg;
      assign complete_wdata[i]       = complete[i].wdata;
      assign complete_wen_and_val[i] = complete[i].wen & complete[i].val;
    end
  endgenerate

  logic [p_phys_addr_bits-1:0] raddr [p_num_pipes][2];
  logic [31:0]                 rdata [p_num_pipes][2];

  SSRegfileL2 #(
    .p_entry_bits       (32),
    .p_num_regs         (p_num_phys_regs),
    .p_num_lookup_ports (p_num_pipes),
    .p_num_be_lanes     (p_num_be_lanes)
  ) regfile (
    .clk                (clk),
    .rst                (rst),
    .raddr              (raddr),
    .rdata              (rdata),
    .waddr              (complete_preg),
    .wdata              (complete_wdata),
    .wen                (complete_wen_and_val)
  );

  logic [31:0] imm [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin
      ImmGen imm_gen (
        .inst    (F_curr[i].inst),
        .imm_sel (decoder_imm_sel[i]),
        .imm     (imm[i])
      );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Squashing
  //----------------------------------------------------------------------

  // Jump based on oldest JAL(R) instruction in current IW if there is one
  // present
  logic [31:0] jump_target;
  logic [31:0] jump_base;

  always_comb begin
    if( !oldest_ctrl_insn_is_brx ) begin
      case( decoder_jal[oldest_ctrl_insn_idx] )
        2'd1:    jump_target = F_curr[oldest_ctrl_insn_idx].pc + imm[oldest_ctrl_insn_idx];   // JAL
        2'd2:    jump_target = (jump_base + imm[oldest_ctrl_insn_idx]) & 32'hFFFFFFFE; // JALR
        default: jump_target = '0;
      endcase
    end else begin
      jump_target = '0;
    end
  end

  // Combinational squash signal for internal use (FIFO reset, squash_sent)
  logic squash_pub_val_comb;
  assign squash_pub_val_comb = oldest_ctrl_insn_found &&
                               !oldest_ctrl_insn_is_brx &&
                               dispatch_go[oldest_ctrl_insn_idx];

  logic squash_sent;
  always_ff @( posedge clk ) begin
    if( rst )
      squash_sent <= 1'b0;
    else if( fifo_pop )
      squash_sent <= 1'b0;
    else if( squash_pub_val_comb )
      squash_sent <= 1'b1;
  end

  // Register squash_pub outputs to break combinational loop through
  // SU → FU → bypass FIFO → DIU
  always_ff @( posedge clk ) begin
    if( rst ) begin
      squash_pub.val     <= 1'b0;
      squash_pub.target  <= '0;
      squash_pub.seq_num <= '0;
    end else begin
      squash_pub.val     <= squash_pub_val_comb;
      squash_pub.target  <= jump_target;
      squash_pub.seq_num <= F_curr[oldest_ctrl_insn_idx].seq_num;
    end
  end

  //----------------------------------------------------------------------
  // Route the instruction to issue queue based on uop
  //----------------------------------------------------------------------

  logic                                iq_rdy         [p_num_pipes];
  logic [p_iq_entries_bits:0]          iq_avail_slots [p_num_pipes];

  // Get routing decisions for instruction in valid, decodable instruction
  // that hasn't been dispatched yet
  logic xbar_val [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_num_arr [p_num_fe_lanes];
  always_comb begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      xbar_val[i]      = stage_pass_s1[i] && !F_curr[i].dispatched;
      seq_num_arr[i]  = F_curr[i].seq_num;
    end
  end

  SSInstXbarCtrl #(
    .p_num_pipes       (p_num_pipes),
    .p_pipe_subsets    (p_pipe_subsets),
    .p_ctrl_subset     (p_ctrl_subset),
    .p_num_input_lanes (p_num_fe_lanes),
    .p_iq_depth        (p_iq_depth),
    .p_seq_num_bits    (p_seq_num_bits),
    .p_num_iter        (p_num_fe_lanes),
    .p_num_be_lanes    (p_num_be_lanes)
  ) inst_xbar (
    .clk            (clk),
    .rst            (rst),
    .uop            (decoder_uop),
    .seq_num        (seq_num_arr),
    .val            (xbar_val),
    .iq_rdy         (iq_rdy),
    .iq_avail_slots (iq_avail_slots),
    .iq_route_idx   (pipe_to_lane_map),
    .iq_val         (iq_val),
    .commit         (commit)
  );

  always_comb begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      dispatch_go[i] = stage_pass_s4[i] && iq_rdy[lane_to_pipe_map[i]];
    end
  end

  //----------------------------------------------------------------------
  // Issue queues (bypass any for control subset)
  //----------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin: IQ_GEN
      IssueQueueInOrder #(
        .p_depth        (p_iq_depth),
        .p_num_regs     (p_num_phys_regs),
        .p_seq_num_bits (p_seq_num_bits),
        .p_num_be_lanes (p_num_be_lanes),
        .p_bypass       (p_pipe_subsets[i] == p_ctrl_subset)
      ) issue_queue (
        .clk                     (clk),
        .rst                     (rst),

        // Insert
        .ins_msg_pc              (F_curr[pipe_to_lane_map[i]].pc),
        .ins_msg_preg            (lookup_new_inst_preg[pipe_to_lane_map[i]]),
        .ins_msg_decoder_uop     (decoder_uop[pipe_to_lane_map[i]]),
        .ins_msg_decoder_waddr   (decoder_waddr[pipe_to_lane_map[i]]),
        .ins_msg_imm             (imm[pipe_to_lane_map[i]]),
        .ins_msg_decoder_op2_sel (decoder_op2_sel[pipe_to_lane_map[i]]),
        .ins_msg_decoder_op3_sel (decoder_op3_sel[pipe_to_lane_map[i]]),
        .ins_msg_seq_num         (F_curr[pipe_to_lane_map[i]].seq_num),
        .ins_msg_alloc_preg      (alloc_preg[pipe_to_lane_map[i]]),
        .ins_msg_alloc_ppreg     (alloc_ppreg[pipe_to_lane_map[i]]),
        .ins_en                  (stage_pass_s4[pipe_to_lane_map[i]] && iq_val[i]),
        .ins_rdy                 (iq_rdy[i]),
        .avail_slots             (iq_avail_slots[i]),

        // Dequeue
        .Ex                      (Ex[i]),

        // Rename Table Access
        .rt_lookup_preg          (lookup_iq_preg[i]),
        .rt_lookup_pending       (lookup_iq_pending[i]),
        .rt_lookup_en            (lookup_iq_en[i]),

        // Register File Access
        .rf_raddr                (raddr[i]),
        .rf_rdata                (rdata[i]),

        // Complete interface
        .complete                (complete)
      );

      // assuming exactly one CTRL_XU - possibly improve this?
      if ( p_pipe_subsets[i] == p_ctrl_subset ) begin
        assign jump_base = rdata[i][0];
      end
    end
  endgenerate

  logic [p_seq_num_bits-1:0] unused_seq_num_bits [p_num_be_lanes];
  genvar k;
  generate
    for( k = 0; k < p_num_be_lanes; k = k + 1 ) begin: UNUSED_COMPLETE_SEQ_NUM
      assign unused_seq_num_bits[k] = complete[k].seq_num;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  function string trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    trace = "";
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      if( i != 0 )
        trace = {trace, " | "};
      if( fifo_pop )
        trace = {trace, $sformatf("%x: %-30s", F_curr[i].seq_num, disassemble(F_curr[i].inst, F_curr[i].pc))};
      else
        trace = {trace, {(32 + ceil_div_4( p_seq_num_bits )){" "}}};
    end
  endfunction
`endif

endmodule

`endif // HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V
