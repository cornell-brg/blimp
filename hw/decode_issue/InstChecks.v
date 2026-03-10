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
// Every stage has four InstChkIntf ports:
//   in_intra_chk   -- from the previous stage (same lane)
//   in_inter_chk   -- from the previous lane  (same stage)
//   out_intra_chk  -- to the next stage       (same lane)
//   out_inter_chk  -- to the next lane        (same stage)
//
// The interface carries pass, invalidate, and inst_status.  Sentinels
// at stage 0 and lane 0 seed the chains with appropriate defaults.

`ifndef HW_DECODEISSUE_INSTCHECKS_V
`define HW_DECODEISSUE_INSTCHECKS_V

`include "intf/InstCheckIntf.v"

//------------------------------------------------------------------------
// InstCheckS1 -- Validity
//------------------------------------------------------------------------
// Pass when the IW entry is valid, the instruction is valid, and the
// decoder recognises the opcode.

module InstCheckS1 #(
  parameter inst_idx       = 0,
  parameter p_num_fe_lanes = 2
) (
  InstChkIntf.in  in_intra_chk,
  InstChkIntf.in  in_inter_chk,
  InstChkIntf.out out_intra_chk,
  InstChkIntf.out out_inter_chk,

  input logic entry_val,
  input logic decoder_val
);

  localparam [1:0] INST_STATUS_INVALID    = 2'b00,
                   INST_STATUS_READY      = 2'b01,
                   INST_STATUS_DISPATCHED = 2'b10;

  // Output intra-check
  assign out_intra_chk.pass =
    in_intra_chk.pass                                    &&
    entry_val                                            &&
    (in_intra_chk.inst_status == INST_STATUS_READY)      &&
    decoder_val;
  assign out_intra_chk.invalidate  = 1'b0;
  assign out_intra_chk.inst_status = in_intra_chk.inst_status;

  // Output inter-check
  assign out_inter_chk.pass        = 1'b1;
  assign out_inter_chk.invalidate  = 1'b0;
  assign out_inter_chk.inst_status = in_intra_chk.inst_status;

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
  InstChkIntf.in  in_intra_chk,
  InstChkIntf.in  in_inter_chk,
  InstChkIntf.out out_intra_chk,
  InstChkIntf.out out_inter_chk,

  input logic                          oldest_ctrl_inst_found,
  input logic                          oldest_ctrl_inst_is_brx,
  input logic [p_fe_lane_idx_bits-1:0] oldest_ctrl_inst_idx,
  input logic                          oldest_ctrl_inst_srcs_ready,
  input logic                          oldest_ctrl_inst_dispatch_en,

  input logic                          squash_sub_val,

  output logic                         alloc_try
);

  localparam [1:0] INST_STATUS_INVALID    = 2'b00,
                   INST_STATUS_READY      = 2'b01,
                   INST_STATUS_DISPATCHED = 2'b10;

  // Output intra-check
  assign out_intra_chk.pass = in_intra_chk.pass && !squash_sub_val && (
    !oldest_ctrl_inst_found ||
    int'(inst_idx) < int'(oldest_ctrl_inst_idx) ||
    (int'(inst_idx) == int'(oldest_ctrl_inst_idx) && oldest_ctrl_inst_srcs_ready)
  );
  assign out_intra_chk.invalidate = in_intra_chk.pass && (
    squash_sub_val || (
      oldest_ctrl_inst_found                      &&
      !oldest_ctrl_inst_is_brx                    &&
      int'(inst_idx) > int'(oldest_ctrl_inst_idx) &&
      oldest_ctrl_inst_dispatch_en
    )
  );
  assign out_intra_chk.inst_status = in_intra_chk.inst_status;

  // Output inter-check
  assign out_inter_chk.pass        = 1'b1;
  assign out_inter_chk.invalidate  = 1'b0;
  assign out_inter_chk.inst_status = in_intra_chk.inst_status;

  // Alloc try
  assign alloc_try = in_intra_chk.pass && 
    in_intra_chk.inst_status != INST_STATUS_DISPATCHED;

endmodule

//------------------------------------------------------------------------
// InstCheckS3 -- Physical register allocation
//------------------------------------------------------------------------
// Serialise register allocation across lanes: a lane may only attempt
// allocation after the previous lane has passed.  Instructions that do
// not write a register (decoder_wen == 0) or that have already been
// dispatched pass immediately.

module InstCheckS3 #(
  parameter inst_idx       = 0,
  parameter p_num_fe_lanes = 2
) (
  InstChkIntf.in  in_intra_chk,
  InstChkIntf.in  in_inter_chk,
  InstChkIntf.out out_intra_chk,
  InstChkIntf.out out_inter_chk,

  input logic decoder_wen,
  input logic alloc_rdy
);

  localparam [1:0] INST_STATUS_INVALID    = 2'b00,
                   INST_STATUS_READY      = 2'b01,
                   INST_STATUS_DISPATCHED = 2'b10;

  // Output intra-check
  assign out_intra_chk.pass =
    in_intra_chk.pass & in_inter_chk.pass &
    ((in_intra_chk.inst_status == INST_STATUS_DISPATCHED) |
     alloc_rdy | !decoder_wen);
  assign out_intra_chk.invalidate  = 1'b0;
  assign out_intra_chk.inst_status = in_intra_chk.inst_status;

  // Output inter-check
  assign out_inter_chk.pass = out_intra_chk.pass ||
    (in_intra_chk.inst_status != INST_STATUS_READY);
  assign out_inter_chk.invalidate  = 1'b0;
  assign out_inter_chk.inst_status = in_intra_chk.inst_status;

endmodule

//------------------------------------------------------------------------
// InstCheckS4 -- Structural hazard (crossbar routing)
//------------------------------------------------------------------------
// The crossbar can route at most one instruction per pipe per cycle.
// Pass when the target lane is valid, the previous instruction has
// passed (or was already dispatched), and this instruction has not
// already been dispatched.

module InstCheckS4 #(
  parameter inst_idx       = 0,
  parameter p_num_fe_lanes = 2
) (
  InstChkIntf.in  in_intra_chk,
  InstChkIntf.in  in_inter_chk,
  InstChkIntf.out out_intra_chk,
  InstChkIntf.out out_inter_chk,

  input logic lane_val
);

  localparam [1:0] INST_STATUS_INVALID    = 2'b00,
                   INST_STATUS_READY      = 2'b01,
                   INST_STATUS_DISPATCHED = 2'b10;

  // Output intra-check
  assign out_intra_chk.pass =
    in_intra_chk.pass                                          &&
    lane_val                                                   &&
    (in_inter_chk.pass                                         ||
     (in_inter_chk.inst_status == INST_STATUS_DISPATCHED));
  assign out_intra_chk.invalidate  = 1'b0;
  assign out_intra_chk.inst_status = in_intra_chk.inst_status;

  // Output inter-check
  assign out_inter_chk.pass = out_intra_chk.pass ||
    (in_intra_chk.inst_status != INST_STATUS_READY);
  assign out_inter_chk.invalidate  = 1'b0;
  assign out_inter_chk.inst_status = in_intra_chk.inst_status;

endmodule

`endif // HW_DECODEISSUE_INSTCHECKS_V
