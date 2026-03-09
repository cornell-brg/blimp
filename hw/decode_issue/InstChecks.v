//========================================================================
// InstChecks.v
//========================================================================
// Instruction validation checkers for superscalar DIU
//
// Four check stages run in series per lane to determine if an
// instruction may be dispatched this cycle:
//
//   S1  Validity    -- entry and decoder both valid
//   S2  Control     -- ordering w.r.t. oldest control instruction
//   S3  Allocation  -- physical register available (serialised across lanes)
//   S4  Structural  -- crossbar can route to target pipe
//
// Every stage uses the common InstCheckIntf for inter-stage and
// inter-lane signals (prev_stage_pass, prev_inst_pass, pass, etc.).
// Stage-specific ports are declared separately.

`ifndef HW_DECODEISSUE_INSTCHECKS_V
`define HW_DECODEISSUE_INSTCHECKS_V

`include "intf/InstCheckIntf.v"

//------------------------------------------------------------------------
// InstCheckS1 -- Validity
//------------------------------------------------------------------------
// Pass when the IW entry is valid, the instruction is valid, and the
// decoder recognises the opcode.

module InstCheckS1 (
  InstCheckIntf.check chk_intf,

  input logic entry_val,
  input logic entry_inst_val,
  input logic decoder_val
);

  assign chk_intf.pass =
    chk_intf.prev_stage_pass &&
    entry_val                &&
    entry_inst_val           &&
    decoder_val;

  assign chk_intf.invalidate         = 1'b0;
  assign chk_intf.prev_inst_pass_out = chk_intf.pass || !chk_intf.inst_valid;

endmodule

//------------------------------------------------------------------------
// InstCheckS2 -- Control instruction ordering
//------------------------------------------------------------------------
// Enforce dispatch ordering around the oldest control (branch / jump)
// instruction in the window.  Instructions older than the control
// instruction may proceed freely; the control instruction itself may
// proceed only when its sources are ready; younger instructions are
// blocked (and invalidated when the control instruction dispatches,
// unless it is a branch).

module InstCheckS2 #(
  parameter inst_idx           = 0,
  parameter p_num_fe_lanes     = 2,
  parameter p_fe_lane_idx_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1
) (
  InstCheckIntf.check chk_intf,

  input logic                           oldest_ctrl_inst_found,
  input logic                           oldest_ctrl_inst_is_brx,
  input logic [p_fe_lane_idx_bits-1:0]  oldest_ctrl_inst_idx,
  input logic                           oldest_ctrl_inst_srcs_ready,
  input logic                           oldest_ctrl_inst_dispatch_en,

  input logic                           squash_sub_val
);

  assign chk_intf.pass = chk_intf.prev_stage_pass && !squash_sub_val && (
    !oldest_ctrl_inst_found ||
    int'(inst_idx) < int'(oldest_ctrl_inst_idx) ||
    (int'(inst_idx) == int'(oldest_ctrl_inst_idx) && oldest_ctrl_inst_srcs_ready)
  );

  assign chk_intf.invalidate = chk_intf.prev_stage_pass && (
    squash_sub_val || (
      oldest_ctrl_inst_found                      &&
      !oldest_ctrl_inst_is_brx                    &&
      int'(inst_idx) > int'(oldest_ctrl_inst_idx) &&
      oldest_ctrl_inst_dispatch_en
    )
  );

  assign chk_intf.prev_inst_pass_out = chk_intf.pass || !chk_intf.inst_valid;

endmodule

//------------------------------------------------------------------------
// InstCheckS3 -- Physical register allocation
//------------------------------------------------------------------------
// Serialise register allocation across lanes: a lane may only attempt
// allocation after the previous lane has passed.  Instructions that do
// not write a register (decoder_wen == 0) or that have already been
// dispatched pass immediately.

module InstCheckS3 (
  InstCheckIntf.check chk_intf,

  input  logic decoder_wen,

  input  logic alloc_rdy,
  input  logic dispatched
);

  assign chk_intf.pass = chk_intf.prev_stage_pass & chk_intf.prev_inst_pass &
                         (dispatched | alloc_rdy | !decoder_wen);

  assign chk_intf.invalidate         = 1'b0;
  assign chk_intf.prev_inst_pass_out = chk_intf.pass || !chk_intf.inst_valid;

endmodule

//------------------------------------------------------------------------
// InstCheckS4 -- Structural hazard (crossbar routing)
//------------------------------------------------------------------------
// The crossbar can route at most one instruction per pipe per cycle.
// Pass when the target lane is valid, the previous instruction has
// passed (or was already dispatched), and this instruction has not
// already been dispatched.

module InstCheckS4 (
  InstCheckIntf.check chk_intf,

  input logic dispatched,
  input logic prev_inst_dispatched,
  input logic lane_val
);

  assign chk_intf.pass = chk_intf.prev_stage_pass                          &&
                         lane_val                                          &&
                         (chk_intf.prev_inst_pass || prev_inst_dispatched) &&
                         !dispatched;

  assign chk_intf.invalidate         = 1'b0;
  assign chk_intf.prev_inst_pass_out = chk_intf.pass || !chk_intf.inst_valid;

endmodule

`endif // HW_DECODEISSUE_INSTCHECKS_V
