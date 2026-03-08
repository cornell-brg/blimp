//========================================================================
// InsnChecks.v
//========================================================================
// Instruction validation checkers for superscalar DIU

`ifndef HW_DECODEISSUE_INSNCHECKS_V
`define HW_DECODEISSUE_INSNCHECKS_V

// valid instruction
module InsnCheckS1 (
  InsnCheckIntf.check intf,

  input  logic entry_val,
  input  logic entry_insn_val,
  input  logic decoder_val
);

  assign intf.pass =
    intf.prev_stage_pass &&
    entry_val &&
    entry_insn_val &&
    decoder_val;

  assign intf.invalidate = 1'b0;
  assign intf.prev_insn_pass_out = intf.pass || !intf.insn_valid;

endmodule

// check against control insn
module InsnCheckS2 #(
  parameter insn_idx = 0,
  parameter p_num_fe_lanes = 2,
  parameter p_fe_lane_idx_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1
) (
  InsnCheckIntf.check intf,

  // Details about oldest control instruction in IW if present
  input  logic oldest_ctrl_insn_found,
  input  logic oldest_ctrl_insn_is_brx,
  input  logic [p_fe_lane_idx_bits-1:0] oldest_ctrl_insn_idx,
  input  logic oldest_ctrl_insn_srcs_ready,
  input  logic oldest_ctrl_insn_dispatch_en,

  input  logic squash_sub_val
);

  assign intf.pass = intf.prev_stage_pass && !squash_sub_val && (
    !oldest_ctrl_insn_found ||
    int'(insn_idx) < int'(oldest_ctrl_insn_idx) ||
    (int'(insn_idx) == int'(oldest_ctrl_insn_idx) && oldest_ctrl_insn_srcs_ready)
  );

  assign intf.invalidate = intf.prev_stage_pass && (
    squash_sub_val || (
      oldest_ctrl_insn_found &&
      !oldest_ctrl_insn_is_brx &&
      int'(insn_idx) > int'(oldest_ctrl_insn_idx) &&
      oldest_ctrl_insn_dispatch_en
    )
  );

  assign intf.prev_insn_pass_out = intf.pass || !intf.insn_valid;

endmodule

// check if can be allocated preg for areg if necessary
module InsnCheckS3 (
  InsnCheckIntf.check intf,

  input  logic decoder_wen,

  output logic alloc_try,
  input  logic alloc_rdy,
  input  logic dispatched
);

  assign alloc_try    = intf.prev_stage_pass & decoder_wen & intf.prev_insn_pass;
  assign intf.pass    = intf.prev_stage_pass & intf.prev_insn_pass &
                        (dispatched | alloc_rdy | !decoder_wen);
  assign intf.invalidate = 1'b0;
  assign intf.prev_insn_pass_out = intf.pass || !intf.insn_valid;

endmodule

// check for structural hazard (xbar cannot route)
module InsnCheckS4 (
  InsnCheckIntf.check intf,

  input logic dispatched,
  input logic prev_insn_dispatched,
  input logic lane_val
);

  assign intf.pass = intf.prev_stage_pass &&
                     lane_val &&
                     (intf.prev_insn_pass || prev_insn_dispatched) &&
                     !dispatched;
  assign intf.invalidate = 1'b0;
  assign intf.prev_insn_pass_out = intf.pass || !intf.insn_valid;

endmodule

`endif // HW_DECODEISSUE_INSNCHECKS_V
