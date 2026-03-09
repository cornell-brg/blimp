//========================================================================
// DecodeIssueUnitL8.v
//========================================================================
// In-order decode-issue unit with register renaming for a superscalar
// backend.  Receives fetched instructions via F__DIntf, decodes them,
// checks dispatch eligibility through four cascaded InstCheck stages
// (validity, control ordering, register allocation, structural hazard),
// and enqueues into per-pipe issue queues via a crossbar.

`ifndef HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V
`define HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V

`ifndef SYNTHESIS
`include "asm/disassemble.v"
`endif

`include "defs/ISA.v"
`include "hw/decode_issue/InstDecoder.v"
`include "hw/decode_issue/ImmGen.v"
`include "hw/decode_issue/SSDIURouter.v"
`include "hw/decode_issue/SSRegfileL2.v"
`include "hw/decode_issue/SSRenameTableL3.v"
`include "hw/decode_issue/IssueQueueInOrder.v"
`include "hw/util/SSSeqAge.v"
`include "hw/decode_issue/DecodeIssueUnitBypassFifo.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/SquashNotif.v"
`include "intf/InstCheckIntf.v"
`include "hw/decode_issue/InstChecks.v"

import ISA::*;

module DecodeIssueUnitL8 #(
  parameter p_num_pipes      = 1,
  parameter p_num_phys_regs  = 36,
  parameter p_num_fe_lanes   = 2,
  parameter p_num_be_lanes   = 2,
  parameter p_iq_depth       = 8,

  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1},

  parameter rv_op_vec p_ctrl_subset = OP_JAL_VEC  | OP_JALR_VEC |
                                      OP_BEQ_VEC  | OP_BNE_VEC  |
                                      OP_BLT_VEC  | OP_BGE_VEC  |
                                      OP_BLTU_VEC | OP_BGEU_VEC,

  parameter rv_op_vec p_brx_subset  = OP_BEQ_VEC  | OP_BNE_VEC  |
                                      OP_BLT_VEC  | OP_BGE_VEC  |
                                      OP_BLTU_VEC | OP_BGEU_VEC,

  parameter p_f_intf_fifo_depth  = 4,
  parameter p_f_intf_fifo_bypass = 0,
  parameter p_iq_entries_bits    = p_iq_depth > 1 ? $clog2(p_iq_depth) : 1
) (
  input logic clk,
  input logic rst,

  // Fetch -> Decode interface
  F__DIntf.D_intf    F          [p_num_fe_lanes],

  // Decode -> Execute interface
  D__XIntf.D_intf    Ex         [p_num_pipes],

  // Completion notification
  CompleteNotif.sub  complete   [p_num_be_lanes],

  // Commit notification
  CommitNotif.sub    commit     [p_num_be_lanes],

  // Squash notification (one to request, one to receive)
  SquashNotif.pub    squash_pub,
  SquashNotif.sub    squash_sub
);

  localparam p_seq_num_bits     = F[0].p_seq_num_bits;
  localparam p_phys_addr_bits   = $clog2(p_num_phys_regs);
  localparam p_fe_lane_idx_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1;

  //----------------------------------------------------------------------
  // Decode-issue message struct (accumulated through the pipeline)
  //----------------------------------------------------------------------

  localparam [1:0] INST_STATUS_INVALID    = 2'b00,
                   INST_STATUS_READY      = 2'b01,
                   INST_STATUS_DISPATCHED = 2'b10;

  typedef struct packed {
    logic                        val;
    logic                 [31:0] inst;
    logic                  [1:0] inst_status;
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    rv_uop                       uop;
    logic [p_phys_addr_bits-1:0] src_preg0;
    logic [p_phys_addr_bits-1:0] src_preg1;
    logic                  [4:0] waddr;
    logic                 [31:0] imm;
    logic                        op2_sel;
    logic                        op3_sel;
    logic [p_phys_addr_bits-1:0] alloc_preg;
    logic [p_phys_addr_bits-1:0] alloc_ppreg;
  } t_diu_msg;

  //----------------------------------------------------------------------
  // Forward declarations
  //----------------------------------------------------------------------
  // Signals referenced before they are driven (cross-stage dependencies).

  logic dispatch_go                  [p_num_fe_lanes];
  logic alloc_rdy                    [p_num_fe_lanes];
  logic oldest_ctrl_inst_srcs_ready;
  logic invalidate_inst              [p_num_fe_lanes];

  // Instruction check interfaces -- one per stage per lane.
  InstCheckIntf inst_chk_s1 [p_num_fe_lanes] ();
  InstCheckIntf inst_chk_s2 [p_num_fe_lanes] ();
  InstCheckIntf inst_chk_s3 [p_num_fe_lanes] ();
  InstCheckIntf inst_chk_s4 [p_num_fe_lanes] ();

  // Helper arrays for variable-indexed access (SV interfaces cannot be
  // indexed with runtime variables in Verilator).
  logic inst_chk_s1_pass [p_num_fe_lanes];
  logic inst_chk_s4_pass [p_num_fe_lanes];

  //----------------------------------------------------------------------
  // Instruction window FIFO
  //----------------------------------------------------------------------

  logic                      fifo_pop;
  logic                      fifo_empty;
  logic [p_num_fe_lanes-1:0] fifo_set_invalid;
  logic [p_num_fe_lanes-1:0] fifo_set_dispatched;

  t_diu_msg F_curr [p_num_fe_lanes];

  DecodeIssueUnitBypassFifo #(
    .t_msg          (t_diu_msg),
    .p_seq_num_bits (p_seq_num_bits),
    .p_depth        (p_f_intf_fifo_depth),
    .p_bypass       (p_f_intf_fifo_bypass),
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

  // Wire invalidation / dispatch decisions back to the FIFO.
  always_comb begin
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      fifo_set_invalid[j]    = invalidate_inst[j];
      fifo_set_dispatched[j] = dispatch_go[j];
    end
  end

  // Pop the window when every lane is either invalid, dispatching this
  // cycle, or already dispatched.
  logic F_rdy_all;

  always_comb begin
    F_rdy_all = oldest_ctrl_inst_srcs_ready;
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      F_rdy_all &= (
        !inst_chk_s1_pass[j] |
        dispatch_go[j]       |
        (F_curr[j].inst_status == INST_STATUS_DISPATCHED)
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
  // Oldest control instruction search
  //----------------------------------------------------------------------
  // Scan the current window for the oldest branch / jump instruction
  // that has not yet dispatched.  Its index drives S2 ordering checks
  // and the squash logic below.

  logic [p_fe_lane_idx_bits-1:0] oldest_ctrl_inst_idx;
  logic [p_seq_num_bits-1:0]     oldest_ctrl_inst_seq_num;
  logic                          oldest_ctrl_inst_found;
  logic                          oldest_ctrl_inst_is_brx;

  logic [p_phys_addr_bits-1:0] lookup_preg          [p_num_pipes+1][2];
  logic                        lookup_preg_en       [p_num_pipes+1][2];
  logic                        lookup_pending       [p_num_pipes+1][2];
  logic [p_phys_addr_bits-1:0] lookup_new_inst_preg [p_num_fe_lanes][2];

  SSSeqAge #(
    .p_num_be_lanes (p_num_be_lanes)
  ) seq_age (
    .clk    (clk),
    .rst    (rst),
    .commit (commit)
  );

  always_comb begin
    oldest_ctrl_inst_idx     = '0;
    oldest_ctrl_inst_seq_num = F_curr[p_num_fe_lanes-1].seq_num;
    oldest_ctrl_inst_found   = 1'b0;
    oldest_ctrl_inst_is_brx  = 1'b0;

    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      logic is_brx, is_jal, is_valid;
      is_brx   = in_subset(p_brx_subset, num_ops'(1 << decoder_uop[k]));
      is_jal   = (decoder_jal[k] != 2'd0);
      is_valid = inst_chk_s1_pass[k] && 
        (F_curr[k].inst_status != INST_STATUS_DISPATCHED);

      if( (is_brx || is_jal) && is_valid &&
          (!oldest_ctrl_inst_found ||
           seq_age.is_older(
            F_curr[k].seq_num,
             oldest_ctrl_inst_seq_num
           )
          )
        )
      begin
        oldest_ctrl_inst_idx     = p_fe_lane_idx_bits'(k);
        oldest_ctrl_inst_seq_num = F_curr[k].seq_num;
        oldest_ctrl_inst_found   = 1'b1;
        oldest_ctrl_inst_is_brx  = is_brx;
      end
    end
  end

  // Check whether the oldest control instruction's sources are ready
  // via the rename-table lookup port reserved for this purpose.
  always_comb begin
    oldest_ctrl_inst_srcs_ready    = 1'b1;
    lookup_preg_en[p_num_pipes][0] = 1'b0;
    lookup_preg_en[p_num_pipes][1] = 1'b0;
    lookup_preg[p_num_pipes][0]    = '0;
    lookup_preg[p_num_pipes][1]    = '0;

    if( oldest_ctrl_inst_found ) begin
      lookup_preg_en[p_num_pipes][0] = 1'b1;
      lookup_preg[p_num_pipes][0]    =
        lookup_new_inst_preg[oldest_ctrl_inst_idx][0];

      if( oldest_ctrl_inst_is_brx ) begin
        lookup_preg_en[p_num_pipes][1] = 1'b1;
        lookup_preg[p_num_pipes][1]    =
          lookup_new_inst_preg[oldest_ctrl_inst_idx][1];
      end

      oldest_ctrl_inst_srcs_ready =
        !lookup_pending[p_num_pipes][0] &
        (!oldest_ctrl_inst_is_brx | !lookup_pending[p_num_pipes][1]);
    end
  end

  //----------------------------------------------------------------------
  // Instruction check stage 1 -- Validity
  //----------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INST_CHECK_S1_GEN
      assign inst_chk_s1[i].prev_stage_pass = 1'b1;
      assign inst_chk_s1[i].prev_inst_pass  = 1'b1;
      assign inst_chk_s1[i].inst_valid      = 
        (F_curr[i].inst_status != INST_STATUS_INVALID);

      InstCheckS1 check_s1 (
        .chk_intf       (inst_chk_s1[i]),
        .entry_val      (F_curr[i].val),
        .entry_inst_val (F_curr[i].inst_status != INST_STATUS_INVALID),
        .decoder_val    (decoder_val[i])
      );

      assign inst_chk_s1_pass[i] = inst_chk_s1[i].pass;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Instruction check stage 2 -- Control instruction ordering
  //----------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INST_CHECK_S2_GEN
      assign inst_chk_s2[i].prev_stage_pass = inst_chk_s1[i].pass;
      assign inst_chk_s2[i].prev_inst_pass  = 1'b1;
      assign inst_chk_s2[i].inst_valid      = 
        (F_curr[i].inst_status != INST_STATUS_INVALID);

      InstCheckS2 #(
        .inst_idx       (i),
        .p_num_fe_lanes (p_num_fe_lanes)
      ) check_s2 (
        .chk_intf                     (inst_chk_s2[i]),
        .oldest_ctrl_inst_found       (oldest_ctrl_inst_found),
        .oldest_ctrl_inst_is_brx      (oldest_ctrl_inst_is_brx),
        .oldest_ctrl_inst_idx         (oldest_ctrl_inst_idx),
        .oldest_ctrl_inst_srcs_ready  (oldest_ctrl_inst_srcs_ready),
        .oldest_ctrl_inst_dispatch_en (inst_chk_s4_pass[oldest_ctrl_inst_idx]),
        .squash_sub_val               (squash_sub.val)
      );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Instruction check stage 3 -- Physical register allocation
  //----------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INST_CHECK_S3_GEN
      assign inst_chk_s3[i].prev_stage_pass = inst_chk_s2[i].pass;
      assign inst_chk_s3[i].prev_inst_pass  = (i == 0) ? 1'b1 :
                                               inst_chk_s3[i-1].prev_inst_pass_out;
      assign inst_chk_s3[i].inst_valid      = (F_curr[i].inst_status != INST_STATUS_INVALID);

      InstCheckS3 check_s3 (
        .chk_intf    (inst_chk_s3[i]),
        .decoder_wen (decoder_wen[i]),
        .alloc_rdy   (alloc_rdy[i]),
        .dispatched  (F_curr[i].inst_status == INST_STATUS_DISPATCHED)
      );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Instruction check stage 4 -- Structural hazard (crossbar routing)
  //----------------------------------------------------------------------

  logic lane_val [p_num_fe_lanes];
  logic iq_val   [p_num_pipes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INST_CHECK_S4_GEN
      assign inst_chk_s4[i].prev_stage_pass = inst_chk_s3[i].pass;
      assign inst_chk_s4[i].prev_inst_pass  = (i == 0) ? 1'b1 :
                                               inst_chk_s4[i-1].prev_inst_pass_out;
      assign inst_chk_s4[i].inst_valid      = (F_curr[i].inst_status != INST_STATUS_INVALID);

      InstCheckS4 check_s4 (
        .chk_intf             (inst_chk_s4[i]),
        .dispatched           (F_curr[i].inst_status == INST_STATUS_DISPATCHED),
        .prev_inst_dispatched (i == 0 ? 1'b1 :
                               (F_curr[i-1].inst_status == INST_STATUS_DISPATCHED)),
        .lane_val             (lane_val[i])
      );

      assign inst_chk_s4_pass[i] = inst_chk_s4[i].pass;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Invalidation
  //----------------------------------------------------------------------
  // OR the invalidate outputs from all four check stages.

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INVALIDATE_GEN
      assign invalidate_inst[i] =
        inst_chk_s1[i].invalidate |
        inst_chk_s2[i].invalidate |
        inst_chk_s3[i].invalidate |
        inst_chk_s4[i].invalidate;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Rename table and register file
  //----------------------------------------------------------------------

  logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes];
  logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes];

  logic [4:0] lookup_new_inst_areg [p_num_fe_lanes][2];
  logic       lookup_new_inst_en   [p_num_fe_lanes][2];

  logic alloc_try [p_num_fe_lanes];
  logic alloc_val [p_num_fe_lanes];

  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      lookup_new_inst_areg[k][0] = decoder_raddr0[k];
      lookup_new_inst_areg[k][1] = decoder_raddr1[k];
      lookup_new_inst_en[k][0]   = 1'b1;
      lookup_new_inst_en[k][1]   = 1'b1;
      alloc_try[k] = inst_chk_s1_pass[k] & 
        (F_curr[k].inst_status != INST_STATUS_DISPATCHED);
    end
  end

  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      alloc_val[k] = alloc_try[k] && dispatch_go[k];
    end
  end

  SSRenameTableL3 #(
    .p_num_phys_regs    (p_num_phys_regs),
    .p_num_lookup_ports (p_num_pipes + 1),
    .p_num_fe_lanes     (p_num_fe_lanes),
    .p_num_be_lanes     (p_num_be_lanes)
  ) rename_table (
    .clk                  (clk),
    .rst                  (rst),

    .alloc_areg           (decoder_waddr),
    .alloc_preg           (alloc_preg),
    .alloc_ppreg          (alloc_ppreg),
    .alloc_try            (alloc_try),
    .alloc_val            (alloc_val),
    .alloc_rdy            (alloc_rdy),

    .lookup_new_inst_areg (lookup_new_inst_areg),
    .lookup_new_inst_en   (lookup_new_inst_en),
    .lookup_new_inst_preg (lookup_new_inst_preg),

    .lookup_preg          (lookup_preg),
    .lookup_preg_en       (lookup_preg_en),
    .lookup_pending       (lookup_pending),

    .complete             (complete),
    .commit               (commit)
  );

  // Extract completion signals for the register file write port.
  logic [p_phys_addr_bits-1:0] complete_preg        [p_num_be_lanes];
  logic [31:0]                 complete_wdata       [p_num_be_lanes];
  logic                        complete_wen_and_val [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin: COMPLETE_SIGNALS_GEN
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
    .clk   (clk),
    .rst   (rst),
    .raddr (raddr),
    .rdata (rdata),
    .waddr (complete_preg),
    .wdata (complete_wdata),
    .wen   (complete_wen_and_val)
  );

  // Immediate generation -- one per FE lane.
  logic [31:0] imm [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: IMM_GEN
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
  // When the oldest control instruction is a JAL/JALR (not a branch),
  // compute its jump target and publish a squash notification.

  logic [31:0] jump_target;
  logic [31:0] jump_base;

  always_comb begin
    if( !oldest_ctrl_inst_is_brx ) begin
      case( decoder_jal[oldest_ctrl_inst_idx] )
        2'd1:    jump_target = F_curr[oldest_ctrl_inst_idx].pc
                              + imm[oldest_ctrl_inst_idx];
        2'd2:    jump_target = (jump_base + imm[oldest_ctrl_inst_idx])
                              & 32'hFFFFFFFE;
        default: jump_target = '0;
      endcase
    end else begin
      jump_target = '0;
    end
  end

  // Combinational squash signal for internal use (FIFO reset, squash_sent).
  logic squash_pub_val_comb;
  assign squash_pub_val_comb = oldest_ctrl_inst_found  &&
                               !oldest_ctrl_inst_is_brx &&
                               dispatch_go[oldest_ctrl_inst_idx];

  logic squash_sent;

  always_ff @( posedge clk ) begin
    if( rst )
      squash_sent <= 1'b0;
    else if( fifo_pop )
      squash_sent <= 1'b0;
    else if( squash_pub_val_comb )
      squash_sent <= 1'b1;
  end

  // Register squash_pub outputs to break the combinational loop through
  // SU -> FU -> bypass FIFO -> DIU.
  always_ff @( posedge clk ) begin
    if( rst ) begin
      squash_pub.val     <= 1'b0;
      squash_pub.target  <= '0;
      squash_pub.seq_num <= '0;
    end else begin
      squash_pub.val     <= squash_pub_val_comb;
      squash_pub.target  <= jump_target;
      squash_pub.seq_num <= F_curr[oldest_ctrl_inst_idx].seq_num;
    end
  end

  //----------------------------------------------------------------------
  // Crossbar routing
  //----------------------------------------------------------------------
  // Route each valid, undispatched instruction to an issue queue based
  // on its micro-op.  The router also muxes per-lane data to per-pipe
  // outputs and computes lane_val / dispatch_go internally.

  logic                       iq_rdy         [p_num_pipes];
  logic [p_iq_entries_bits:0] iq_avail_slots [p_num_pipes];

  // Pack router input data
  t_diu_msg router_in_msg [p_num_fe_lanes];
  logic     router_val    [p_num_fe_lanes];

  always_comb begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      router_val[i]                = inst_chk_s1_pass[i] && 
        (F_curr[i].inst_status != INST_STATUS_DISPATCHED);
      router_in_msg[i]             = F_curr[i];
      router_in_msg[i].uop         = decoder_uop[i];
      router_in_msg[i].src_preg0   = lookup_new_inst_preg[i][0];
      router_in_msg[i].src_preg1   = lookup_new_inst_preg[i][1];
      router_in_msg[i].waddr       = decoder_waddr[i];
      router_in_msg[i].imm         = imm[i];
      router_in_msg[i].op2_sel     = decoder_op2_sel[i];
      router_in_msg[i].op3_sel     = decoder_op3_sel[i];
      router_in_msg[i].alloc_preg  = alloc_preg[i];
      router_in_msg[i].alloc_ppreg = alloc_ppreg[i];
    end
  end

  // Per-pipe routed instruction data from the router
  t_diu_msg iq_msg    [p_num_pipes];
  logic     iq_ins_val [p_num_pipes];

  SSDIURouter #(
    .t_msg             (t_diu_msg),
    .p_num_pipes       (p_num_pipes),
    .p_num_input_lanes (p_num_fe_lanes),
    .p_iq_depth        (p_iq_depth),
    .p_seq_num_bits    (p_seq_num_bits),
    .p_num_iter        (p_num_fe_lanes),
    .p_num_be_lanes    (p_num_be_lanes),
    .p_pipe_subsets    (p_pipe_subsets)
  ) inst_router (
    .clk            (clk),
    .rst            (rst),
    .val            (router_val),
    .in_msg         (router_in_msg),
    .chk_pass       (inst_chk_s4_pass),
    .iq_rdy         (iq_rdy),
    .iq_avail_slots (iq_avail_slots),
    .iq_msg         (iq_msg),
    .iq_ins_val     (iq_ins_val),
    .iq_val         (iq_val),
    .lane_val       (lane_val),
    .dispatch_go    (dispatch_go),
    .commit         (commit)
  );

  //----------------------------------------------------------------------
  // Issue queues
  //----------------------------------------------------------------------
  // One per pipe.  The control-subset pipe uses a bypass queue.

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin: IQ_GEN
      IssueQueueInOrder #(
        .t_msg          (t_diu_msg),
        .p_depth        (p_iq_depth),
        .p_num_regs     (p_num_phys_regs),
        .p_seq_num_bits (p_seq_num_bits),
        .p_num_be_lanes (p_num_be_lanes),
        .p_bypass       (p_pipe_subsets[i] == p_ctrl_subset)
      ) issue_queue (
        .clk               (clk),
        .rst               (rst),

        // Insert (data from router)
        .ins_msg           (iq_msg[i]),
        .ins_val           (iq_ins_val[i]),
        .ins_rdy           (iq_rdy[i]),
        .avail_slots       (iq_avail_slots[i]),

        // Dequeue
        .Ex                (Ex[i]),

        // Rename table access
        .rt_lookup_preg    (lookup_preg[i]),
        .rt_lookup_pending (lookup_pending[i]),
        .rt_lookup_en      (lookup_preg_en[i]),

        // Register file access
        .rf_raddr          (raddr[i]),
        .rf_rdata          (rdata[i]),

        // Completion interface
        .complete          (complete)
      );

      // JALR base register read -- assumes exactly one control pipe.
      if( p_pipe_subsets[i] == p_ctrl_subset ) begin
        assign jump_base = rdata[i][0];
      end
    end
  endgenerate

  // Suppress unused-signal warnings on complete.seq_num.
  logic [p_seq_num_bits-1:0] unused_seq_num_bits [p_num_be_lanes];
  genvar k;

  generate
    for( k = 0; k < p_num_be_lanes; k++ ) begin: UNUSED_COMPLETE_SEQ_NUM
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
      trace = {trace, $sformatf("%x: %-30s",
        F_curr[i].seq_num, disassemble(F_curr[i].inst, F_curr[i].pc))};
    end
  endfunction

  function string trace_json_lane( int lane );
    if( !fifo_empty )
      trace_json_lane = $sformatf("{\"seq\":\"%x\",\"inst\":\"%0s\",\"xfer\":\"%b\",\"inst_status\":\"%b\"}",
        F_curr[lane].seq_num, disassemble(F_curr[lane].inst, F_curr[lane].pc),
        dispatch_go[lane], F_curr[lane].inst_status);
    else
      trace_json_lane = "null";
  endfunction
`endif

endmodule

`endif // HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V
