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
`include "hw/decode_issue/SSDecoder.v"
`include "hw/decode_issue/SSInstMapper.v"
`include "hw/decode_issue/SSDIURouter.v"
`include "hw/decode_issue/SSRegfileL2.v"
`include "hw/decode_issue/SSRenameTableL3.v"
`include "hw/decode_issue/IssueQueueOOO.v"
`include "hw/util/SSSeqAge.v"
`include "hw/decode_issue/DIUBypassFifo.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/SquashNotif.v"
`include "intf/InstCheckIntf.v"
`include "hw/decode_issue/InstChecks.v"
`include "hw/decode_issue/DIUSquashPub.v"

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
  parameter p_iq_entries_bits    = p_iq_depth > 1 ? $clog2(p_iq_depth) : 1,

  // Bitmask of which pipes use bypass IQs.  Default ('0) auto-computes
  // to bypass only for the control-subset pipe.
  parameter logic [p_num_pipes-1:0] p_pipe_bypass = '0
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

  // Compute effective bypass mask: when p_pipe_bypass == '0, default to
  // bypass only for the control-subset pipe.
  function automatic logic [p_num_pipes-1:0] ctrl_only_bypass();
    for (int i = 0; i < p_num_pipes; i++)
      ctrl_only_bypass[i] = (p_pipe_subsets[i] == p_ctrl_subset);
  endfunction

  localparam logic [p_num_pipes-1:0] c_pipe_bypass =
    (p_pipe_bypass != '0) ? p_pipe_bypass : ctrl_only_bypass();

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
    logic                        src_pending0;
    logic                        src_pending1;
    logic                  [4:0] waddr;
    logic                 [31:0] imm;
    logic                        op2_sel;
    logic                        op3_sel;
    logic [p_phys_addr_bits-1:0] alloc_preg;
    logic [p_phys_addr_bits-1:0] alloc_ppreg;
  } t_dio_inst_window;

  //----------------------------------------------------------------------
  // Oldest control instruction info struct
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                          found;
    logic                          is_brx;
    logic                          srcs_ready;
    logic [p_fe_lane_idx_bits-1:0] idx;
    logic                    [1:0] jal;
    logic                   [31:0] pc;
    logic                   [31:0] imm;
    logic   [p_seq_num_bits-1:0]   seq_num;
  } t_oldest_ctrl_inst;

  //----------------------------------------------------------------------
  // Forward declarations
  //----------------------------------------------------------------------
  // Signals referenced before they are driven (cross-stage dependencies).

  logic dispatch_go      [p_num_fe_lanes];
  logic alloc_rdy        [p_num_fe_lanes];
  logic invalidate_inst  [p_num_fe_lanes];

  // Instruction check interface chains.
  //
  // Intra chains (same lane, across stages):
  //   intra_chk_s0 = sentinel → S1 input
  //   intra_chk_sN = stage N output → stage N+1 input
  //
  // Inter chains (same stage, across lanes):
  //   inter_chk_sN[0] = sentinel for lane 0
  //   inter_chk_sN[i+1] = stage N, lane i output → lane i+1 input

  InstChkIntf intra_chk_s0 [p_num_fe_lanes] ();
  InstChkIntf intra_chk_s1 [p_num_fe_lanes] ();
  InstChkIntf intra_chk_s2 [p_num_fe_lanes] ();
  InstChkIntf intra_chk_s3 [p_num_fe_lanes] ();
  InstChkIntf intra_chk_s4 [p_num_fe_lanes] ();

  InstChkIntf inter_chk_s1 [p_num_fe_lanes + 1] ();
  InstChkIntf inter_chk_s2 [p_num_fe_lanes + 1] ();
  InstChkIntf inter_chk_s3 [p_num_fe_lanes + 1] ();
  InstChkIntf inter_chk_s4 [p_num_fe_lanes + 1] ();

  // Helper arrays for variable-indexed access (SV interfaces cannot be
  // indexed with runtime variables in Verilator).
  logic inst_chk_s1_pass [p_num_fe_lanes];
  logic inst_chk_s4_pass [p_num_fe_lanes];

  //----------------------------------------------------------------------
  // Instruction window FIFO
  //----------------------------------------------------------------------

  logic                      fifo_pop;
  logic                      fifo_empty;
  logic [1:0]                fifo_update_head [p_num_fe_lanes];

  t_dio_inst_window F_curr [p_num_fe_lanes];

  DIUBypassFifo #(
    .t_msg          (t_dio_inst_window),
    .p_seq_num_bits (p_seq_num_bits),
    .p_depth        (p_f_intf_fifo_depth),
    .p_bypass       (p_f_intf_fifo_bypass),
    .p_num_lanes    (p_num_fe_lanes)
  ) f_fifo (
    .clk             (clk),
    .rst             (rst | squash_sub.val),
    .clear           (squash_pub_val_comb),
    .F               (F),
    .pop             (fifo_pop),
    .empty           (fifo_empty),
    .o_msg           (F_curr),
    .edit_inst_state (fifo_update_head)
  );

  // Wire invalidation / dispatch decisions back to the FIFO.
  always_comb begin
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      if( invalidate_inst[j] )
        fifo_update_head[j] = INST_STATUS_INVALID;
      else if( dispatch_go[j] )
        fifo_update_head[j] = INST_STATUS_DISPATCHED;
      else
        fifo_update_head[j] = INST_STATUS_READY;
    end
  end

  // Pop the window when every lane is either invalid, dispatching this
  // cycle, or already dispatched.
  logic F_rdy_all;

  always_comb begin
    F_rdy_all = 1'b1;
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
  // Decode and oldest control instruction search
  //----------------------------------------------------------------------

  logic       decoder_val [p_num_fe_lanes];
  logic [4:0] decoder_raddr0 [p_num_fe_lanes];
  logic [4:0] decoder_raddr1 [p_num_fe_lanes];
  logic       decoder_wen [p_num_fe_lanes];

  t_dio_inst_window  decoded_msg [p_num_fe_lanes];
  t_oldest_ctrl_inst oldest_ctrl_inst;

  logic lookup_new_inst_pending [p_num_fe_lanes][2];

  genvar i;

  SSDecoder #(
    .t_msg          (t_dio_inst_window),
    .t_ctrl_info    (t_oldest_ctrl_inst),
    .p_num_fe_lanes (p_num_fe_lanes),
    .p_brx_subset   (p_brx_subset)
  ) ss_decoder (
    .in_msg                  (F_curr),
    .out_msg                 (decoded_msg),
    .decoder_val             (decoder_val),
    .raddr0                  (decoder_raddr0),
    .raddr1                  (decoder_raddr1),
    .wen                     (decoder_wen),
    .oldest_ctrl_inst        (oldest_ctrl_inst),
    .lookup_new_inst_pending (lookup_new_inst_pending)
  );

  //----------------------------------------------------------------------
  // Instruction check sentinels
  //----------------------------------------------------------------------
  // Intra sentinel (before S1): pass=1, inst_status from FIFO.
  // Inter sentinels (lane 0):   pass=1, S4 uses DISPATCHED status so
  //                              lane 0 sees prev-lane as dispatched.

  // Inter-lane sentinels (index 0 of each inter chain).
  assign inter_chk_s1[0].pass        = 1'b1;
  assign inter_chk_s1[0].invalidate  = 1'b0;
  assign inter_chk_s1[0].inst_status = INST_STATUS_READY;

  assign inter_chk_s2[0].pass        = 1'b1;
  assign inter_chk_s2[0].invalidate  = 1'b0;
  assign inter_chk_s2[0].inst_status = INST_STATUS_READY;

  assign inter_chk_s3[0].pass        = 1'b1;
  assign inter_chk_s3[0].invalidate  = 1'b0;
  assign inter_chk_s3[0].inst_status = INST_STATUS_READY;

  assign inter_chk_s4[0].pass        = 1'b1;
  assign inter_chk_s4[0].invalidate  = 1'b0;
  assign inter_chk_s4[0].inst_status = INST_STATUS_DISPATCHED;

  //----------------------------------------------------------------------
  // Instruction check stages
  //----------------------------------------------------------------------

  logic lane_val  [p_num_fe_lanes];
  logic iq_val    [p_num_pipes];
  logic alloc_try [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INST_CHECK_GEN

      // Intra sentinel (before S1): pass through from FIFO.
      assign intra_chk_s0[i].pass        = 1'b1;
      assign intra_chk_s0[i].invalidate  = 1'b0;
      assign intra_chk_s0[i].inst_status = F_curr[i].inst_status;

      // S1 -- Validity
      InstCheckS1 #(
        .inst_idx       (i),
        .p_num_fe_lanes (p_num_fe_lanes)
      ) check_s1 (
        .in_intra_chk  (intra_chk_s0[i]),
        .in_inter_chk  (inter_chk_s1[i]),
        .out_intra_chk (intra_chk_s1[i]),
        .out_inter_chk (inter_chk_s1[i+1]),
        .entry_val     (F_curr[i].val),
        .decoder_val   (decoder_val[i])
      );

      assign inst_chk_s1_pass[i] = intra_chk_s1[i].pass;

      // S2 -- Control instruction ordering
      InstCheckS2 #(
        .inst_idx       (i),
        .p_num_fe_lanes (p_num_fe_lanes)
      ) check_s2 (
        .in_intra_chk                 (intra_chk_s1[i]),
        .in_inter_chk                 (inter_chk_s2[i]),
        .out_intra_chk                (intra_chk_s2[i]),
        .out_inter_chk                (inter_chk_s2[i+1]),
        .oldest_ctrl_inst_found       (oldest_ctrl_inst.found),
        .oldest_ctrl_inst_is_brx      (oldest_ctrl_inst.is_brx),
        .oldest_ctrl_inst_idx         (oldest_ctrl_inst.idx),
        .oldest_ctrl_inst_srcs_ready  (oldest_ctrl_inst.srcs_ready),
        .oldest_ctrl_inst_dispatch_en (inst_chk_s4_pass[oldest_ctrl_inst.idx]),
        .squash_sub_val               (squash_sub.val),
        .alloc_try                    (alloc_try[i])
      );

      // S3 -- Physical register allocation
      InstCheckS3 #(
        .inst_idx       (i),
        .p_num_fe_lanes (p_num_fe_lanes)
      ) check_s3 (
        .in_intra_chk  (intra_chk_s2[i]),
        .in_inter_chk  (inter_chk_s3[i]),
        .out_intra_chk (intra_chk_s3[i]),
        .out_inter_chk (inter_chk_s3[i+1]),
        .decoder_wen   (decoder_wen[i]),
        .alloc_rdy     (alloc_rdy[i])
      );

      // S4 -- Structural hazard (crossbar routing)
      InstCheckS4 #(
        .inst_idx       (i),
        .p_num_fe_lanes (p_num_fe_lanes)
      ) check_s4 (
        .in_intra_chk  (intra_chk_s3[i]),
        .in_inter_chk  (inter_chk_s4[i]),
        .out_intra_chk (intra_chk_s4[i]),
        .out_inter_chk (inter_chk_s4[i+1]),
        .lane_val      (lane_val[i])
      );

      assign inst_chk_s4_pass[i] = intra_chk_s4[i].pass;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Invalidation
  //----------------------------------------------------------------------
  // OR the invalidate outputs from all four check stages.

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: INVALIDATE_GEN
      assign invalidate_inst[i] =
        intra_chk_s1[i].invalidate |
        intra_chk_s2[i].invalidate |
        intra_chk_s3[i].invalidate |
        intra_chk_s4[i].invalidate;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Rename table and register file
  //----------------------------------------------------------------------


  logic [4:0] lookup_new_inst_areg [p_num_fe_lanes][2];
  logic [4:0] alloc_areg          [p_num_fe_lanes];
  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      lookup_new_inst_areg[k][0] = decoder_raddr0[k];
      lookup_new_inst_areg[k][1] = decoder_raddr1[k];
      alloc_areg[k]              = decoded_msg[k].waddr;
    end
  end

  logic alloc_val [p_num_fe_lanes];
  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      alloc_val[k] = alloc_try[k] && dispatch_go[k];
    end
  end

  logic [p_phys_addr_bits-1:0] alloc_preg           [p_num_fe_lanes];
  logic [p_phys_addr_bits-1:0] alloc_ppreg          [p_num_fe_lanes];
  logic [p_phys_addr_bits-1:0] lookup_new_inst_preg [p_num_fe_lanes][2];

  SSRenameTableL3 #(
    .p_num_phys_regs (p_num_phys_regs),
    .p_num_fe_lanes  (p_num_fe_lanes),
    .p_num_be_lanes  (p_num_be_lanes)
  ) rename_table (
    .clk                     (clk),
    .rst                     (rst),

    .alloc_areg              (alloc_areg),
    .alloc_preg              (alloc_preg),
    .alloc_ppreg             (alloc_ppreg),
    .alloc_try               (alloc_try),
    .alloc_val               (alloc_val),
    .alloc_rdy               (alloc_rdy),

    .lookup_new_inst_areg    (lookup_new_inst_areg),
    .lookup_new_inst_preg    (lookup_new_inst_preg),
    .lookup_new_inst_pending (lookup_new_inst_pending),

    .complete                (complete),
    .commit                  (commit)
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


  //----------------------------------------------------------------------
  // Squashing
  //----------------------------------------------------------------------

  logic        squash_pub_val_comb;
  logic [31:0] jump_base;

  DIUSquashPub #(
    .t_ctrl_info    (t_oldest_ctrl_inst),
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_publisher (
    .clk                          (clk),
    .rst                          (rst),
    .oldest_ctrl_inst             (oldest_ctrl_inst),
    .oldest_ctrl_inst_jump_base   (jump_base),
    .oldest_ctrl_inst_dispatch_go (dispatch_go[oldest_ctrl_inst.idx]),
    .squash_pub                   (squash_pub),
    .squash_pub_val_comb          (squash_pub_val_comb)
  );

  //----------------------------------------------------------------------
  // Crossbar mapping and routing
  //----------------------------------------------------------------------
  // SSInstMapper computes the lane-to-pipe mapping via iSLIP.
  // SSDIURouter muxes instruction data according to the mapping.

  logic                       iq_rdy         [p_num_pipes];
  logic [p_iq_entries_bits:0] iq_avail_slots [p_num_pipes];

  // Pack mapper input data
  t_dio_inst_window router_in_msg [p_num_fe_lanes];

  always_comb begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      router_in_msg[i]              = decoded_msg[i];
      router_in_msg[i].src_preg0    = lookup_new_inst_preg[i][0];
      router_in_msg[i].src_preg1    = lookup_new_inst_preg[i][1];
      router_in_msg[i].src_pending0 = lookup_new_inst_pending[i][0];
      router_in_msg[i].src_pending1 = lookup_new_inst_pending[i][1];
      router_in_msg[i].alloc_preg   = alloc_preg[i];
      router_in_msg[i].alloc_ppreg  = alloc_ppreg[i];
    end
  end

  // Per-pipe routed instruction data from the router
  t_dio_inst_window iq_msg     [p_num_pipes];
  logic             iq_ins_try [p_num_pipes];

  //----------------------------------------------------------------------
  // Sequence age tracker
  //----------------------------------------------------------------------
  // Shared oldest_seq_num used by both the mapper (age-based grant)
  // and the out-of-order issue queues (oldest-ready selection).

  logic [p_seq_num_bits-1:0] oldest_seq_num;

  SSSeqAge #(
    .p_num_be_lanes (p_num_be_lanes),
    .p_seq_num_bits (p_seq_num_bits)
  ) seq_age (
    .clk            (clk),
    .rst            (rst),
    .oldest_seq_num (oldest_seq_num),
    .commit         (commit)
  );

  // Mapper outputs consumed by both the router and the inst-check S4
  // stage (lane_val feeds into the structural-hazard check).

  localparam p_pipe_bits        = p_num_pipes > 1 ? $clog2(p_num_pipes) : 1;
  localparam p_input_lanes_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1;

  logic [p_input_lanes_bits-1:0] mapper_route_idx        [p_num_pipes];
  logic [p_pipe_bits-1:0]        mapper_lane_to_pipe_map [p_num_fe_lanes];

  SSInstMapper #(
    .t_msg             (t_dio_inst_window),
    .p_num_pipes       (p_num_pipes),
    .p_num_input_lanes (p_num_fe_lanes),
    .p_iq_depth        (p_iq_depth),
    .p_seq_num_bits    (p_seq_num_bits),
    .p_num_iter        (p_num_fe_lanes),
    .p_pipe_subsets    (p_pipe_subsets),
    .p_pipe_bypass     (c_pipe_bypass)
  ) inst_mapper (
    .in_msg           (router_in_msg),
    .val              (inst_chk_s1_pass),
    .iq_rdy           (iq_rdy),
    .iq_avail_slots   (iq_avail_slots),
    .oldest_seq_num   (oldest_seq_num),
    .route_idx        (mapper_route_idx),
    .iq_val           (iq_val),
    .lane_val         (lane_val),
    .lane_to_pipe_map (mapper_lane_to_pipe_map)
  );

  SSDIURouter #(
    .t_msg             (t_dio_inst_window),
    .p_num_pipes       (p_num_pipes),
    .p_num_input_lanes (p_num_fe_lanes)
  ) inst_router (
    .in_msg           (router_in_msg),
    .chk_pass         (inst_chk_s4_pass),
    .iq_rdy           (iq_rdy),
    .route_idx        (mapper_route_idx),
    .iq_val           (iq_val),
    .lane_to_pipe_map (mapper_lane_to_pipe_map),
    .iq_msg           (iq_msg),
    .iq_ins_try       (iq_ins_try),
    .dispatch_go      (dispatch_go)
  );

  //----------------------------------------------------------------------
  // Issue queues
  //----------------------------------------------------------------------
  // One per pipe.  The control-subset pipe uses a bypass queue.

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin: IQ_GEN
      IssueQueueOOO #(
        .t_msg          (t_dio_inst_window),
        .p_depth        (p_iq_depth),
        .p_num_regs     (p_num_phys_regs),
        .p_seq_num_bits (p_seq_num_bits),
        .p_num_be_lanes (p_num_be_lanes),
        .p_bypass       (c_pipe_bypass[i])
      ) issue_queue (
        .clk             (clk),
        .rst             (rst),

        // Insert (data from router)
        .ins_msg         (iq_msg[i]),
        .ins_try         (iq_ins_try[i]),
        .ins_rdy         (iq_rdy[i]),
        .ins_ack         (),
        .avail_slots     (iq_avail_slots[i]),

        // Dequeue
        .Ex              (Ex[i]),

        // Age comparison
        .oldest_seq_num  (oldest_seq_num),

        // Register file access
        .rf_raddr        (raddr[i]),
        .rf_rdata        (rdata[i]),

        // Completion interface
        .complete        (complete)
      );

      // JALR base register read -- assumes exactly one control pipe
      if( c_pipe_bypass[i] ) begin
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
