//========================================================================
// SSDecoder.v
//========================================================================
// Superscalar decoder with oldest-control-instruction tracking.
//
// Takes an array of t_msg messages (one per front-end lane), decodes
// each instruction, and produces enriched output messages with decoded
// fields populated.  Also locates the oldest valid, undispatched control
// instruction via chain propagation and bundles the result into a
// t_ctrl_info struct.

`ifndef HW_DECODEISSUE_SSDECODER_V
`define HW_DECODEISSUE_SSDECODER_V

`include "hw/decode_issue/InstDecoder.v"
`include "hw/decode_issue/ImmGen.v"

import ISA::*;

//------------------------------------------------------------------------
// OldestCtrlInstTracker
//------------------------------------------------------------------------
// Finds the oldest valid, undispatched control instruction across all
// front-end lanes using chain propagation.  Uses per-lane pending
// status to determine whether the oldest control instruction's sources
// are ready.

module OldestCtrlInstTracker #(
  parameter p_num_fe_lanes     = 2,
  parameter rv_op_vec p_brx_subset = '0,
  parameter p_fe_lane_idx_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1
) (
  // Per-lane decoder outputs used for classification
  input rv_uop      uop         [p_num_fe_lanes],
  input logic [1:0] jal         [p_num_fe_lanes],
  input logic       decoder_val [p_num_fe_lanes],

  // Per-lane instruction window state
  input logic       entry_val   [p_num_fe_lanes],
  input logic [1:0] inst_status [p_num_fe_lanes],

  // Oldest control instruction search results
  output logic [p_fe_lane_idx_bits-1:0] oldest_ctrl_inst_idx,
  output logic                          oldest_ctrl_inst_found,
  output logic                          oldest_ctrl_inst_is_brx,

  // Per-lane source pending status from rename table
  input  logic lookup_new_inst_pending [p_num_fe_lanes][2],
  output logic oldest_ctrl_inst_srcs_ready
);

  localparam [1:0] INST_STATUS_INVALID    = 2'b00,
                   INST_STATUS_READY      = 2'b01,
                   INST_STATUS_DISPATCHED = 2'b10;

  //----------------------------------------------------------------------
  // Search chains
  //----------------------------------------------------------------------

  logic                          ctrl_found_chain  [p_num_fe_lanes + 1] /* verilator split_var */;
  logic [p_fe_lane_idx_bits-1:0] ctrl_idx_chain    [p_num_fe_lanes + 1] /* verilator split_var */;
  logic                          ctrl_is_brx_chain [p_num_fe_lanes + 1] /* verilator split_var */;

  assign ctrl_found_chain[0]  = 1'b0;
  assign ctrl_idx_chain[0]    = '0;
  assign ctrl_is_brx_chain[0] = 1'b0;

  //----------------------------------------------------------------------
  // Per-lane search
  //----------------------------------------------------------------------

  genvar i;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: LANE_GEN

      logic is_brx, is_ctrl, is_valid;

      assign is_brx   = in_subset(p_brx_subset, num_ops'(1 << uop[i]));
      assign is_ctrl  = is_brx || (jal[i] != 2'd0);
      assign is_valid = entry_val[i]                               &&
                         decoder_val[i]                            &&
                         (inst_status[i] != INST_STATUS_INVALID)   &&
                         (inst_status[i] != INST_STATUS_DISPATCHED);

      logic take;
      assign take = is_ctrl && is_valid && !ctrl_found_chain[i];

      assign ctrl_found_chain[i+1]  = ctrl_found_chain[i] || take;
      assign ctrl_idx_chain[i+1]    = take ? p_fe_lane_idx_bits'(i) :
                                             ctrl_idx_chain[i];
      assign ctrl_is_brx_chain[i+1] = take ? is_brx :
                                             ctrl_is_brx_chain[i];
    end
  endgenerate

  //----------------------------------------------------------------------
  // Outputs
  //----------------------------------------------------------------------

  assign oldest_ctrl_inst_found  = ctrl_found_chain[p_num_fe_lanes];
  assign oldest_ctrl_inst_idx    = ctrl_idx_chain[p_num_fe_lanes];
  assign oldest_ctrl_inst_is_brx = ctrl_is_brx_chain[p_num_fe_lanes];

  always_comb begin
    oldest_ctrl_inst_srcs_ready = 1'b1;

    if( oldest_ctrl_inst_found ) begin
      oldest_ctrl_inst_srcs_ready =
        !lookup_new_inst_pending[oldest_ctrl_inst_idx][0] &
        (!oldest_ctrl_inst_is_brx |
         !lookup_new_inst_pending[oldest_ctrl_inst_idx][1]);
    end
  end

endmodule

//------------------------------------------------------------------------
// SSDecoder
//------------------------------------------------------------------------
// Superscalar decoder: takes an array of messages, decodes each, and
// produces enriched output messages plus oldest control instruction info.

module SSDecoder #(
  parameter type t_msg       = logic,
  parameter type t_ctrl_info = logic,
  parameter p_num_fe_lanes     = 2,
  parameter rv_op_vec p_brx_subset = '0,
  parameter p_fe_lane_idx_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1
) (
  // Per-lane message input / output
  input  t_msg in_msg  [p_num_fe_lanes],
  output t_msg out_msg [p_num_fe_lanes],

  // Decoder-only per-lane outputs (not in t_msg)
  output logic       decoder_val [p_num_fe_lanes],
  output logic [4:0] raddr0      [p_num_fe_lanes],
  output logic [4:0] raddr1      [p_num_fe_lanes],
  output logic       wen         [p_num_fe_lanes],

  // Oldest control instruction (bundled struct)
  output t_ctrl_info oldest_ctrl_inst,

  // Per-lane source pending status from rename table
  input logic lookup_new_inst_pending [p_num_fe_lanes][2]
);

  //----------------------------------------------------------------------
  // Per-lane decode
  //----------------------------------------------------------------------

  // Internal per-lane signals from InstDecoder / ImmGen
  rv_uop      int_uop     [p_num_fe_lanes];
  logic [4:0] int_waddr   [p_num_fe_lanes];
  rv_imm_type int_imm_sel [p_num_fe_lanes];
  logic       int_op2_sel [p_num_fe_lanes];
  logic [1:0] int_jal     [p_num_fe_lanes];
  logic       int_op3_sel [p_num_fe_lanes];
  logic [31:0] int_imm    [p_num_fe_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: LANE_GEN

      InstDecoder decoder (
        .inst    (in_msg[i].inst),
        .val     (decoder_val[i]),
        .uop     (int_uop[i]),
        .raddr0  (raddr0[i]),
        .raddr1  (raddr1[i]),
        .waddr   (int_waddr[i]),
        .wen     (wen[i]),
        .imm_sel (int_imm_sel[i]),
        .op2_sel (int_op2_sel[i]),
        .jal     (int_jal[i]),
        .op3_sel (int_op3_sel[i])
      );

      ImmGen imm_gen (
        .inst    (in_msg[i].inst),
        .imm_sel (int_imm_sel[i]),
        .imm     (int_imm[i])
      );

      // Enrich message with decoded fields
      always_comb begin
        out_msg[i]         = in_msg[i];
        out_msg[i].uop     = int_uop[i];
        out_msg[i].waddr   = int_waddr[i];
        out_msg[i].imm     = int_imm[i];
        out_msg[i].op2_sel = int_op2_sel[i];
        out_msg[i].op3_sel = int_op3_sel[i];
      end
    end
  endgenerate

  //----------------------------------------------------------------------
  // Oldest control instruction tracker
  //----------------------------------------------------------------------

  logic [p_fe_lane_idx_bits-1:0] ctrl_idx;
  logic                          ctrl_found;
  logic                          ctrl_is_brx;
  logic                          ctrl_srcs_ready;

  // Extract entry_val and inst_status for the tracker.
  logic       entry_val   [p_num_fe_lanes];
  logic [1:0] inst_status [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: TRACKER_UNPACK
      assign entry_val[i]   = in_msg[i].val;
      assign inst_status[i] = in_msg[i].inst_status;
    end
  endgenerate

  OldestCtrlInstTracker #(
    .p_num_fe_lanes (p_num_fe_lanes),
    .p_brx_subset   (p_brx_subset)
  ) ctrl_tracker (
    .uop                         (int_uop),
    .jal                         (int_jal),
    .decoder_val                 (decoder_val),
    .entry_val                   (entry_val),
    .inst_status                 (inst_status),
    .oldest_ctrl_inst_idx        (ctrl_idx),
    .oldest_ctrl_inst_found      (ctrl_found),
    .oldest_ctrl_inst_is_brx     (ctrl_is_brx),
    .lookup_new_inst_pending     (lookup_new_inst_pending),
    .oldest_ctrl_inst_srcs_ready (ctrl_srcs_ready)
  );

  //----------------------------------------------------------------------
  // Bundle oldest control instruction info
  //----------------------------------------------------------------------

  always_comb begin
    oldest_ctrl_inst.found      = ctrl_found;
    oldest_ctrl_inst.is_brx     = ctrl_is_brx;
    oldest_ctrl_inst.srcs_ready = ctrl_srcs_ready;
    oldest_ctrl_inst.idx        = ctrl_idx;
    oldest_ctrl_inst.jal        = int_jal[ctrl_idx];
    oldest_ctrl_inst.pc         = in_msg[ctrl_idx].pc;
    oldest_ctrl_inst.imm        = int_imm[ctrl_idx];
    oldest_ctrl_inst.seq_num    = in_msg[ctrl_idx].seq_num;
  end

endmodule

`endif // HW_DECODEISSUE_SSDECODER_V
