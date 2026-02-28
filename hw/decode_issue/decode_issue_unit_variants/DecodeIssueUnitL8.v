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
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/SquashNotif.v"

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

  localparam p_seq_num_bits    = F[0].p_seq_num_bits;
  localparam p_phys_addr_bits  = $clog2( p_num_phys_regs );
  localparam p_fe_lane_idx_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1;
  localparam p_pipe_bits        = p_num_pipes > 1 ? $clog2(p_num_pipes) : 1;
  
  //----------------------------------------------------------------------
  // Pipeline registers for F interface
  //----------------------------------------------------------------------

  logic [p_fe_lane_idx_bits-1:0] pipe_to_lane_map [p_num_pipes];
  /* verilator lint_off UNOPTFLAT */
  logic dispatch_en [p_num_fe_lanes]; 
  /* verilator lint_on UNOPTFLAT */
  logic dispatch_go [p_num_fe_lanes];
  logic alloc_rdy   [p_num_fe_lanes];
  logic oldest_ctrl_insn_srcs_ready;

  typedef struct packed {
    logic                      val;
    logic               [31:0] inst;
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
    logic                      insn_valid;
  } F_input;

  F_input F_reg      [p_num_fe_lanes];
  F_input F_reg_next [p_num_fe_lanes];
  logic   F_xfer     [p_num_fe_lanes];
  logic   F_xfer_all;
  logic   iq_val     [p_num_pipes];

  logic F_rdy_all;
  always_comb begin
    F_rdy_all = 1'b1;
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      F_rdy_all &= ((!F_reg[j].val | !F_reg[j].insn_valid ? 1'b1 : dispatch_go[j] & alloc_rdy[j]) & oldest_ctrl_insn_srcs_ready);
    end
  end

  logic lane_val [p_num_fe_lanes];
  logic [p_pipe_bits-1:0] lane_to_pipe_map [p_num_fe_lanes];
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

  // Track oldest JAL(R), BRX, and instruction in general
  logic [p_fe_lane_idx_bits-1:0] oldest_jal_idx;
  logic [p_seq_num_bits-1:0]     oldest_jal_seq_num;
  logic                          oldest_jal_found;

  logic [p_fe_lane_idx_bits-1:0] oldest_brx_idx;
  logic [p_seq_num_bits-1:0]     oldest_brx_seq_num;
  logic                          oldest_brx_found;

  logic [p_fe_lane_idx_bits-1:0] oldest_ctrl_insn_idx;
  logic [p_seq_num_bits-1:0]     oldest_ctrl_insn_seq_num;
  logic                          oldest_ctrl_insn_found;
  logic                          oldest_ctrl_insn_is_brx;


  // If squash sub originating from CTRL XU, invalidate (insn_val = 0) all
  // instructions in registers up to and including that branch causing the
  // squash in CTRL XU
  genvar i;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: F_REG_GEN
      always_ff @( posedge clk ) begin
        if ( rst )
          F_reg[i] <= '{
            val: 1'b0, 
            inst: 'x, 
            pc: 'x, 
            seq_num: 'x,
            insn_valid: '0
          };
        else
          F_reg[i] <= F_reg_next[i];
      end

      assign F[i].rdy = F_rdy_all;
      assign F_xfer[i] = F[i].val & F[i].rdy;

      always_comb begin

        // Take in next IW from fetch on F interface handshake, invalidate
        // immediately if incoming instruction is invalid
        if ( F_xfer[i] )
          if( F[i].insn_valid )
            F_reg_next[i] = '{
              val: 1'b1,
              inst: F[i].inst,
              pc: F[i].pc,
              seq_num: F[i].seq_num,
              insn_valid: F[i].insn_valid
            };
          else
            F_reg_next[i] = '{
              val: 1'b0,
              inst: 'x,
              pc: 'x,
              seq_num: 'x,
              insn_valid: '0
            };

        // if there is an oldest ctrl insn in this IW:
        //   if older than oldest ctrl insn and xfer to xbar -> invalidate
        //   if it is a valid jump -> invalidate insns younger than it when the jal xfer's
        //   if it is a valid branch -> invalidate insn if it is younger or same age as branch when the branch xfer's
        //   if squash sub from ctrl unit is valid -> invalidate all insn's 
        // else:
        //   invalidate insn if xfer'd to xbar
        else if (
          (oldest_ctrl_insn_found && (
            (seq_age.is_older(F_reg[i].seq_num, F_reg[oldest_ctrl_insn_idx].seq_num) && dispatch_go[i]) || 
            (!oldest_ctrl_insn_is_brx && F_reg[oldest_ctrl_insn_idx].val && F_reg[oldest_ctrl_insn_idx].insn_valid && dispatch_go[oldest_ctrl_insn_idx] &&
              !seq_age.is_older(F_reg[oldest_ctrl_insn_idx].seq_num, F_reg[i].seq_num) && i != oldest_ctrl_insn_idx) ||
            (oldest_ctrl_insn_is_brx && F_reg[oldest_ctrl_insn_idx].val && F_reg[oldest_ctrl_insn_idx].insn_valid && dispatch_go[oldest_ctrl_insn_idx] &&
              !seq_age.is_older(F_reg[oldest_ctrl_insn_idx].seq_num, F_reg[i].seq_num))) 
          ) || squash_sub.val || (!oldest_ctrl_insn_found && dispatch_go[i])
        )
          F_reg_next[i] = '{
            val: 1'b0,
            inst: 'x,
            pc: 'x,
            seq_num: 'x,
            insn_valid: '0
          };
        else
          F_reg_next[i] = F_reg[i];
      end
    end
  endgenerate

  always_comb begin
    F_xfer_all  = 1'b1;
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      F_xfer_all &= F_xfer[k];
    end
  end

  //----------------------------------------------------------------------
  // Instantiate Decoder, Regfile, ImmGen
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
  
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: DECODER_GEN
      InstDecoder decoder (
        .val     (decoder_val[i]),
        .inst    (F_reg[i].inst),
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

  logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes];
  logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes];

  logic                  [4:0] lookup_new_inst_areg [p_num_fe_lanes][2];
  logic [p_phys_addr_bits-1:0] lookup_new_inst_preg [p_num_fe_lanes][2];
  logic                        lookup_new_inst_en   [p_num_fe_lanes][2];

  logic [p_phys_addr_bits-1:0] lookup_iq_preg    [p_num_pipes+1][2];
  logic                        lookup_iq_en      [p_num_pipes+1][2];
  logic                        lookup_iq_pending [p_num_pipes+1][2];

  logic alloc_en [p_num_fe_lanes];
  logic alloc_commit [p_num_fe_lanes];

  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      lookup_new_inst_areg[k][0] = decoder_raddr0[k];
      lookup_new_inst_areg[k][1] = decoder_raddr1[k];
      lookup_new_inst_en[k][0] = 1'b1;
      lookup_new_inst_en[k][1] = 1'b1;
      alloc_en[k] = F_reg[k].val && 
                    F_reg[k].insn_valid && 
                    decoder_val[k];
    end
  end

  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      alloc_commit[k] = alloc_en[k] & dispatch_go[k];
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
    .alloc_en       (alloc_en),
    .alloc_commit   (alloc_commit),
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
        .inst    (F_reg[i].inst),
        .imm_sel (decoder_imm_sel[i]),
        .imm     (imm[i])
      );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Squashing
  //----------------------------------------------------------------------
  
  SSSeqAge #(
    .p_num_be_lanes (p_num_be_lanes)
  ) seq_age (
    .*
  );


  always_comb begin

    // Oldest JAL(R)
    oldest_jal_idx      = '0;
    oldest_jal_found    = 1'b0;
    oldest_jal_seq_num  = F_reg[p_num_fe_lanes-1].seq_num;

    // Oldest branch
    oldest_brx_idx      = '0;
    oldest_brx_found    = 1'b0;
    oldest_brx_seq_num  = F_reg[p_num_fe_lanes-1].seq_num;

    // Oldest instruction
    oldest_ctrl_insn_idx     = '0;
    oldest_ctrl_insn_seq_num = F_reg[p_num_fe_lanes-1].seq_num;
    oldest_ctrl_insn_found   = 1'b0;
    oldest_ctrl_insn_is_brx  = 1'b0;

    for( int i = 0; i < p_num_fe_lanes; i++ ) begin

      // Update oldest BRX insn
      if( in_subset(p_brx_subset, num_ops'(1 << decoder_uop[i])) &&
          (seq_age.is_older(F_reg[i].seq_num, oldest_brx_seq_num) || 
          (F_reg[i].seq_num == oldest_brx_seq_num)) && F_reg[i].val) begin
        oldest_brx_idx     = p_fe_lane_idx_bits'(i);
        oldest_brx_seq_num = F_reg[i].seq_num;
        oldest_brx_found   = 1'b1;
      end

      // Update oldest JAL seq num in IW if the latest found JAL(R) is older
      if( (decoder_jal[i] != 2'd0) && F_reg[i].val && 
           !oldest_jal_found || (oldest_jal_found && (
            seq_age.is_older(F_reg[i].seq_num, oldest_jal_seq_num)
           ) ))
      begin
        oldest_jal_idx     = p_fe_lane_idx_bits'(i);
        oldest_jal_seq_num = F_reg[i].seq_num;
        oldest_jal_found   = 1'b1;
      end
    end

    // If found any control instruction
    if( oldest_brx_found || oldest_jal_found ) begin
      oldest_ctrl_insn_found   = 1'b1;

      // If both BRX and JAL(R) found, determine which is older
      if( oldest_brx_found && oldest_jal_found ) begin
        if( seq_age.is_older(oldest_brx_seq_num, oldest_jal_seq_num) ) begin
          oldest_ctrl_insn_idx     = oldest_brx_idx;
          oldest_ctrl_insn_seq_num = oldest_brx_seq_num;
          oldest_ctrl_insn_is_brx  = 1'b1;
        end
        else begin
          oldest_ctrl_insn_idx     = oldest_jal_idx;
          oldest_ctrl_insn_seq_num = oldest_jal_seq_num;
          oldest_ctrl_insn_is_brx  = 1'b0;
        end
      end

      // If only BRX found, that is the oldest control insn
      else if( oldest_brx_found ) begin
        oldest_ctrl_insn_idx     = oldest_brx_idx;
        oldest_ctrl_insn_seq_num = oldest_brx_seq_num;
        oldest_ctrl_insn_is_brx  = 1'b1;
      end

      // If only JAL(R) found, that is the oldest control insn
      else begin
        oldest_ctrl_insn_idx     = oldest_jal_idx;
        oldest_ctrl_insn_seq_num = oldest_jal_seq_num;
        oldest_ctrl_insn_is_brx  = 1'b0;
      end
    end
  end

  // Jump based on oldest JAL(R) instruction in current IW if there is one
  // present
  logic [31:0] jump_target;
  logic [31:0] jump_base;

  always_comb begin
    case( decoder_jal[oldest_jal_idx] )
      2'd1:    jump_target = F_reg[oldest_jal_idx].pc + imm[oldest_jal_idx];   // JAL
      2'd2:    jump_target = (jump_base + imm[oldest_jal_idx]) & 32'hFFFFFFFE; // JALR
      default: jump_target = 'x;
    endcase
  end

  logic squash_sent;
  always_ff @( posedge clk ) begin
    if( rst )
      squash_sent <= 1'b0;
    else if( F_xfer_all )
      squash_sent <= 1'b0;
    else if( squash_pub.val )
      squash_sent <= 1'b1;
  end

  // Publish a valid squash if ALL of the following:
  // 1) There is a JAL(R) in the IW
  // 2) That JAL(R) is valid
  // 3) We haven't already sent a squash for that JAL(R)
  // 4) Able to allocate all destination registers for insns in this IW
  logic alloc_rdy_upto_jal;
  always_comb begin
    alloc_rdy_upto_jal = 1'b1;
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      if( i <= oldest_jal_idx ) begin
        if( F_reg[i].val && F_reg[i].insn_valid && decoder_val[i] ) begin
          alloc_rdy_upto_jal &= alloc_rdy[i];
        end else begin
          alloc_rdy_upto_jal &= 1'b1;
        end
      end else begin
        alloc_rdy_upto_jal &= 1'b1;
      end
    end
  end

  // Squash-free dispatch_go check for lanes before the JAL, used to break the
  // combinational loop: dispatch_go -> squash_pub -> squash_sub -> dispatch_en -> dispatch_go
  logic dispatch_go_upto_jal;
  logic jal_can_xfer;
  always_comb begin
    dispatch_go_upto_jal = 1'b1;
    for (int i = 0; i < p_num_fe_lanes; i++) begin
      if (p_fe_lane_idx_bits'(i) < oldest_jal_idx) begin
        if (F_reg[i].val && F_reg[i].insn_valid && decoder_val[i])
          dispatch_go_upto_jal &= lane_val[i] && iq_rdy[lane_to_pipe_map[i]];
      end
    end
    jal_can_xfer = lane_val[oldest_jal_idx] &&
                   (oldest_ctrl_insn_idx == oldest_jal_idx) &&
                   dispatch_go_upto_jal &&
                   iq_rdy[lane_to_pipe_map[oldest_jal_idx]];
  end

  assign squash_pub.val     = (oldest_jal_found &&
                               F_reg[oldest_jal_idx].insn_valid &&
                               jal_can_xfer &&
                               !squash_sent &&
                               oldest_ctrl_insn_srcs_ready &&
                               alloc_rdy_upto_jal);
  assign squash_pub.target  = jump_target;
  assign squash_pub.seq_num = oldest_jal_seq_num;

  //----------------------------------------------------------------------
  // Route the instruction to issue queue based on uop
  //----------------------------------------------------------------------

  logic                                iq_rdy         [p_num_pipes];
  logic [p_iq_entries_bits:0]          iq_avail_slots [p_num_pipes];
  
  // Check if oldest ctrl instruction source operands are ready,
  // dispatch_en for all instructions will not be valid, same for alloc_en for
  // all instructions and for squash_pub.val. F.rdy for all instructions will
  // also not be ready in this case.
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
        oldest_ctrl_insn_srcs_ready = !lookup_iq_pending[p_num_pipes][0] & !lookup_iq_pending[p_num_pipes][1];
      end else begin
        lookup_iq_en[p_num_pipes][1] = 1'b0;
        lookup_iq_preg[p_num_pipes][1] = '0;
        oldest_ctrl_insn_srcs_ready = !lookup_iq_pending[p_num_pipes][0];
      end
    end
  end

  // This insn can enter crossbar if ALL of the following:
  // 1) It is valid
  // 2) The decoder can decode it (decoder_val)
  // 3) It is older than or the same age as the oldest control instruction in
  //    the IW (if there is one)
  logic alloc_rdy_prev_lanes;
  logic dispatch_go_prev_lanes;
  always_comb begin
    alloc_rdy_prev_lanes = 1'b1;
    dispatch_go_prev_lanes = 1'b1;
    for (int i = 0; i < p_num_fe_lanes; i++) begin
      logic lane_active;
      lane_active = F_reg[i].val && F_reg[i].insn_valid && decoder_val[i];

      if (lane_active)
        alloc_rdy_prev_lanes &= alloc_rdy[i];

      dispatch_en[i] = 1'b0;
      if (lane_active) begin
        if (!oldest_ctrl_insn_found) begin
          dispatch_en[i] = lane_val[i] && alloc_rdy_prev_lanes && !squash_sub.val;
        end else if (lane_val[i] &&
                     ((p_fe_lane_idx_bits'(i) == oldest_ctrl_insn_idx
                       && oldest_ctrl_insn_srcs_ready) ||
                      p_fe_lane_idx_bits'(i) < oldest_ctrl_insn_idx) &&
                     alloc_rdy_prev_lanes &&
                     dispatch_go_prev_lanes &&
                     (seq_age.is_older(F_reg[i].seq_num, oldest_ctrl_insn_seq_num) ||
                      F_reg[i].seq_num == oldest_ctrl_insn_seq_num)) begin
          if (oldest_jal_found && squash_sub.val)
            dispatch_en[i] = squash_sub.seq_num == oldest_jal_seq_num;
          else
            dispatch_en[i] = !squash_sub.val;
        end
      end

      if (lane_active)
        dispatch_go_prev_lanes &= dispatch_go[i];
    end
  end

  logic [p_seq_num_bits-1:0] insn_seq_nums [p_num_fe_lanes];
  always_comb begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      insn_seq_nums[i] = F_reg[i].seq_num;
    end
  end

  // Valid input to xbar if instruction is valid and decodable
  logic xbar_val [p_num_fe_lanes];
  always_comb begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      xbar_val[i] = F_reg[i].val && F_reg[i].insn_valid && decoder_val[i];
    end
  end

  SSInstXbarCtrl #(
    .p_num_pipes       (p_num_pipes),
    .p_pipe_subsets    (p_pipe_subsets),
    .p_ctrl_subset     (p_ctrl_subset),
    .p_num_input_lanes (p_num_fe_lanes),
    .p_iq_depth        (p_iq_depth),
    .p_seq_num_bits    (p_seq_num_bits),
    .p_num_be_lanes    (p_num_be_lanes)
  ) inst_xbar (
    .clk            (clk),
    .rst            (rst),
    .uop            (decoder_uop),
    .seq_num        (insn_seq_nums),
    .val            (xbar_val),
    .iq_rdy         (iq_rdy),
    .iq_avail_slots (iq_avail_slots),
    .iq_route_idx   (pipe_to_lane_map),
    .iq_val         (iq_val),
    .commit         (commit)
  );

  // IQ xfer is determined by whether the instruction is being routed to a pipe
  // and whether that pipe is ready to accept an instruction
  always_comb begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      dispatch_go[i] = dispatch_en[i] && iq_rdy[lane_to_pipe_map[i]];
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
        .ins_msg_pc              (F_reg[pipe_to_lane_map[i]].pc),
        .ins_msg_preg            (lookup_new_inst_preg[pipe_to_lane_map[i]]),
        .ins_msg_decoder_uop     (decoder_uop[pipe_to_lane_map[i]]),
        .ins_msg_decoder_waddr   (decoder_waddr[pipe_to_lane_map[i]]),
        .ins_msg_imm             (imm[pipe_to_lane_map[i]]),
        .ins_msg_decoder_op2_sel (decoder_op2_sel[pipe_to_lane_map[i]]),
        .ins_msg_decoder_op3_sel (decoder_op3_sel[pipe_to_lane_map[i]]),
        .ins_msg_seq_num         (F_reg[pipe_to_lane_map[i]].seq_num),
        .ins_msg_alloc_preg      (alloc_preg[pipe_to_lane_map[i]]),
        .ins_msg_alloc_ppreg     (alloc_ppreg[pipe_to_lane_map[i]]),
        .ins_en                  (dispatch_en[pipe_to_lane_map[i]] && iq_val[i]),
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

// `ifndef SYNTHESIS  
//   function int ceil_div_4( int val );
//     return (val / 4) + ((val % 4) > 0 ? 1 : 0);
//   endfunction

//   function string trace(
//     // verilator lint_off UNUSEDSIGNAL
//     int trace_level
//     // verilator lint_on UNUSEDSIGNAL
//   );
//     if( F_reg.val & F.rdy )
//       trace = $sformatf("%x: %-30s", F_reg.seq_num, disassemble(F_reg.inst, F_reg.pc) );
//     else
//       trace = {(32 + ceil_div_4( p_seq_num_bits )){" "}};
//   endfunction
// `endif

endmodule

`endif // HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V
