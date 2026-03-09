//========================================================================
// SSDIURouter.v
//========================================================================
// A crossbar router for the decode-issue unit with integrated data
// muxing. Routes instructions from front-end lanes to issue queues
// using a modified iSLIP algorithm with age-based priority and
// slot-based accept. Muxes per-lane instruction data to per-pipe
// outputs directly. Analogous to SSWBArb but for the decode-issue
// side (N FE lanes -> M pipes).
//
// When p_ctrl_subset is non-zero, control instructions matching that
// subset are routed directly to the matching pipe via age-based priority,
// bypassing iSLIP and iq_rdy. Non-control instructions go through iSLIP
// as normal with the ctrl pipe excluded.
//
// The message struct (t_msg) must contain .uop and .seq_num fields.

`ifndef HW_DECODE_SSDIUROUTER_V
`define HW_DECODE_SSDIUROUTER_V

`include "defs/UArch.v"
`include "hw/util/SSSeqAge.v"
`include "hw/common/ISLIPCore.v"

import UArch::*;

module SSDIURouter #(
  parameter type t_msg = logic,

  parameter p_num_pipes = 8,

  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1},
  parameter rv_op_vec                   p_ctrl_subset  = '0,

  parameter p_num_input_lanes  = 2,
  parameter p_input_lanes_bits = p_num_input_lanes > 1 ? $clog2(p_num_input_lanes) : 1,
  parameter p_iq_depth         = 8,
  parameter p_iq_entries_bits  = p_iq_depth > 1 ? $clog2(p_iq_depth) : 1,
  parameter p_seq_num_bits     = 8,
  parameter p_num_iter         = 2,
  parameter p_num_be_lanes     = 2
) (
  input  logic                          clk,
  input  logic                          rst,

  // Per input lane: instruction messages and validity
  input  t_msg                          in_msg         [p_num_input_lanes],
  input  logic                          val            [p_num_input_lanes],

  // Per input lane: final check pass (for ins_en / dispatch_go)
  input  logic                          chk_pass       [p_num_input_lanes],

  // Per pipe: IQ status
  input  logic                          iq_rdy         [p_num_pipes],
  input  logic [p_iq_entries_bits:0]    iq_avail_slots [p_num_pipes],

  // Per pipe: routed instruction data outputs
  output t_msg                          iq_msg         [p_num_pipes],
  output logic                          iq_ins_val     [p_num_pipes],
  output logic                          iq_val         [p_num_pipes],

  // Per lane: routing results
  output logic                          lane_val       [p_num_input_lanes],
  output logic                          dispatch_go    [p_num_input_lanes],

  CommitNotif.sub commit [p_num_be_lanes]
);

  localparam p_pipe_bits = p_num_pipes > 1 ? $clog2(p_num_pipes) : 1;

  //----------------------------------------------------------------------
  // Extract control signals from struct
  //----------------------------------------------------------------------

  rv_uop                     in_uop     [p_num_input_lanes];
  logic [p_seq_num_bits-1:0] in_seq_num [p_num_input_lanes];

  always_comb begin
    for (int ii = 0; ii < p_num_input_lanes; ii++) begin
      in_uop[ii]     = rv_uop'(in_msg[ii].uop);
      in_seq_num[ii] = in_msg[ii].seq_num;
    end
  end

  //----------------------------------------------------------------------
  // Shared age comparison
  //----------------------------------------------------------------------

  SSSeqAge #(
    .p_num_be_lanes (p_num_be_lanes)
  ) seq_age (
    .*
  );

  logic [p_seq_num_bits-1:0] oldest_seq_num;
  assign oldest_seq_num = seq_age.oldest_seq_num;

  //----------------------------------------------------------------------
  // Control instruction detection (when p_ctrl_subset is active)
  //----------------------------------------------------------------------

  logic is_ctrl [p_num_input_lanes];

  always_comb begin
    for (int ii = 0; ii < p_num_input_lanes; ii++) begin
      if (p_ctrl_subset != '0)
        is_ctrl[ii] = in_subset(p_ctrl_subset, num_ops'(1 << in_uop[ii]));
      else
        is_ctrl[ii] = 1'b0;
    end
  end

  //----------------------------------------------------------------------
  // Compute opcode compatibility matrix
  //----------------------------------------------------------------------

  logic iq_compat_op [p_num_input_lanes][p_num_pipes];
  logic val_uop      [p_num_input_lanes][p_num_pipes];

  logic                      iq_rdy_masked   [p_num_pipes];
  logic [p_iq_entries_bits:0] iq_avail_masked [p_num_pipes];

  genvar i, j;
  generate
    for (j = 0; j < p_num_pipes; j++) begin : gen_mask_pipes
      if (p_ctrl_subset != '0 && p_pipe_subsets[j] == p_ctrl_subset) begin : gen_ctrl_mask
        assign iq_rdy_masked[j]   = 1'b0;
        assign iq_avail_masked[j] = '0;
      end else begin : gen_pass_mask
        assign iq_rdy_masked[j]   = iq_rdy[j];
        assign iq_avail_masked[j] = iq_avail_slots[j];
      end
    end
  endgenerate

  generate
    for (i = 0; i < p_num_input_lanes; i++) begin : gen_compat_in
      for (j = 0; j < p_num_pipes; j++) begin : gen_compat_out

        // Check if this input's opcode is supported by this output pipe
        always_comb begin
          val_uop[i][j] = 0;

          if( in_subset(p_pipe_subsets[j], OP_ADD_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_ADD    );
          if( in_subset(p_pipe_subsets[j], OP_SUB_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_SUB    );
          if( in_subset(p_pipe_subsets[j], OP_AND_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_AND    );
          if( in_subset(p_pipe_subsets[j], OP_OR_VEC     ) ) val_uop[i][j] |= ( in_uop[i] == OP_OR     );
          if( in_subset(p_pipe_subsets[j], OP_XOR_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_XOR    );
          if( in_subset(p_pipe_subsets[j], OP_SLT_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_SLT    );
          if( in_subset(p_pipe_subsets[j], OP_SLTU_VEC   ) ) val_uop[i][j] |= ( in_uop[i] == OP_SLTU   );
          if( in_subset(p_pipe_subsets[j], OP_SRA_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_SRA    );
          if( in_subset(p_pipe_subsets[j], OP_SRL_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_SRL    );
          if( in_subset(p_pipe_subsets[j], OP_SLL_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_SLL    );
          if( in_subset(p_pipe_subsets[j], OP_LUI_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_LUI    );
          if( in_subset(p_pipe_subsets[j], OP_AUIPC_VEC  ) ) val_uop[i][j] |= ( in_uop[i] == OP_AUIPC  );
          if( in_subset(p_pipe_subsets[j], OP_LB_VEC     ) ) val_uop[i][j] |= ( in_uop[i] == OP_LB     );
          if( in_subset(p_pipe_subsets[j], OP_LH_VEC     ) ) val_uop[i][j] |= ( in_uop[i] == OP_LH     );
          if( in_subset(p_pipe_subsets[j], OP_LW_VEC     ) ) val_uop[i][j] |= ( in_uop[i] == OP_LW     );
          if( in_subset(p_pipe_subsets[j], OP_LBU_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_LBU    );
          if( in_subset(p_pipe_subsets[j], OP_LHU_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_LHU    );
          if( in_subset(p_pipe_subsets[j], OP_SB_VEC     ) ) val_uop[i][j] |= ( in_uop[i] == OP_SB     );
          if( in_subset(p_pipe_subsets[j], OP_SH_VEC     ) ) val_uop[i][j] |= ( in_uop[i] == OP_SH     );
          if( in_subset(p_pipe_subsets[j], OP_SW_VEC     ) ) val_uop[i][j] |= ( in_uop[i] == OP_SW     );
          if( in_subset(p_pipe_subsets[j], OP_JAL_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_JAL    );
          if( in_subset(p_pipe_subsets[j], OP_JALR_VEC   ) ) val_uop[i][j] |= ( in_uop[i] == OP_JALR   );
          if( in_subset(p_pipe_subsets[j], OP_BEQ_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_BEQ    );
          if( in_subset(p_pipe_subsets[j], OP_BNE_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_BNE    );
          if( in_subset(p_pipe_subsets[j], OP_BLT_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_BLT    );
          if( in_subset(p_pipe_subsets[j], OP_BGE_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_BGE    );
          if( in_subset(p_pipe_subsets[j], OP_BLTU_VEC   ) ) val_uop[i][j] |= ( in_uop[i] == OP_BLTU   );
          if( in_subset(p_pipe_subsets[j], OP_BGEU_VEC   ) ) val_uop[i][j] |= ( in_uop[i] == OP_BGEU   );
          if( in_subset(p_pipe_subsets[j], OP_MUL_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_MUL    );
          if( in_subset(p_pipe_subsets[j], OP_MULH_VEC   ) ) val_uop[i][j] |= ( in_uop[i] == OP_MULH   );
          if( in_subset(p_pipe_subsets[j], OP_MULHSU_VEC ) ) val_uop[i][j] |= ( in_uop[i] == OP_MULHSU );
          if( in_subset(p_pipe_subsets[j], OP_MULHU_VEC  ) ) val_uop[i][j] |= ( in_uop[i] == OP_MULHU  );
          if( in_subset(p_pipe_subsets[j], OP_DIV_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_DIV    );
          if( in_subset(p_pipe_subsets[j], OP_DIVU_VEC   ) ) val_uop[i][j] |= ( in_uop[i] == OP_DIVU   );
          if( in_subset(p_pipe_subsets[j], OP_REM_VEC    ) ) val_uop[i][j] |= ( in_uop[i] == OP_REM    );
          if( in_subset(p_pipe_subsets[j], OP_REMU_VEC   ) ) val_uop[i][j] |= ( in_uop[i] == OP_REMU   );
        end

        // Exclude ctrl instructions from iSLIP, and mask ctrl pipe
        assign iq_compat_op[i][j] = val_uop[i][j] & val[i] & !is_ctrl[i]
                                  & iq_rdy_masked[j] & (iq_avail_masked[j] > 0);
      end
    end
  endgenerate

  //----------------------------------------------------------------------
  // iSLIP matching via ISLIPCore (slot-based accept)
  //----------------------------------------------------------------------

  // Ctrl pipe excluded from iSLIP via output_free_init
  logic output_free_init [p_num_pipes];
  generate
    for (j = 0; j < p_num_pipes; j++) begin : gen_output_free_init
      if (p_ctrl_subset != '0 && p_pipe_subsets[j] == p_ctrl_subset) begin : gen_ctrl_excl
        assign output_free_init[j] = 1'b0;
      end else begin : gen_free
        assign output_free_init[j] = 1'b1;
      end
    end
  endgenerate

  logic final_match [p_num_input_lanes][p_num_pipes];

  ISLIPCore #(
    .p_num_inputs   (p_num_input_lanes),
    .p_num_outputs  (p_num_pipes),
    .p_seq_num_bits (p_seq_num_bits),
    .p_num_iter     (p_num_iter),
    .p_accept_lsb   (0),
    .p_slot_bits    (p_iq_entries_bits)
  ) u_islip (
    .compat           (iq_compat_op),
    .seq_num          (in_seq_num),
    .oldest_seq_num   (oldest_seq_num),
    .output_free_init (output_free_init),
    .slots            (iq_avail_masked),
    .final_match      (final_match)
  );

  //----------------------------------------------------------------------
  // Control instruction routing (when p_ctrl_subset is active)
  //----------------------------------------------------------------------

  logic [p_num_input_lanes-1:0]  ctrl_req_vec;
  logic [p_num_input_lanes-1:0]  ctrl_gnt;
  logic                          ctrl_any_gnt;
  logic [p_input_lanes_bits-1:0] ctrl_route_idx;

  generate
    if (p_ctrl_subset != '0) begin : gen_ctrl_route

      always_comb begin
        for (int ii = 0; ii < p_num_input_lanes; ii++)
          ctrl_req_vec[ii] = val[ii] & is_ctrl[ii];
      end

      AgePE #(
        .p_num_input_lanes (p_num_input_lanes),
        .p_seq_num_bits    (p_seq_num_bits)
      ) u_ctrl_age (
        .req            (ctrl_req_vec),
        .age            (in_seq_num),
        .oldest_seq_num (oldest_seq_num),
        .gnt            (ctrl_gnt),
        .any_gnt        (ctrl_any_gnt)
      );

      always_comb begin
        ctrl_route_idx = '0;
        for (int ii = 0; ii < p_num_input_lanes; ii++)
          if (ctrl_gnt[ii])
            ctrl_route_idx = (p_input_lanes_bits)'(ii);
      end

    end else begin : gen_no_ctrl_route

      assign ctrl_req_vec   = '0;
      assign ctrl_gnt       = '0;
      assign ctrl_any_gnt   = 1'b0;
      assign ctrl_route_idx = '0;

    end
  endgenerate

  //----------------------------------------------------------------------
  // Route index and validity computation
  //----------------------------------------------------------------------

  logic [p_input_lanes_bits-1:0] route_idx [p_num_pipes];

  always_comb begin
    for (int jj = 0; jj < p_num_pipes; jj++) begin

      // Ctrl pipe: override with AgePE result
      if (p_ctrl_subset != '0 && p_pipe_subsets[jj] == p_ctrl_subset) begin
        iq_val[jj]    = ctrl_any_gnt;
        route_idx[jj] = ctrl_route_idx;

      // Non-ctrl pipes: use iSLIP match result
      end else begin
        iq_val[jj]    = 1'b0;
        route_idx[jj] = '0;

        for (int ii = 0; ii < p_num_input_lanes; ii++) begin
          if (final_match[ii][jj]) begin
            iq_val[jj]    = 1'b1;
            route_idx[jj] = (p_input_lanes_bits)'(ii);
          end
        end
      end
    end
  end

  //----------------------------------------------------------------------
  // Data muxing: per-lane data -> per-pipe outputs
  //----------------------------------------------------------------------

  always_comb begin
    for (int jj = 0; jj < p_num_pipes; jj++) begin
      iq_msg[jj]     = in_msg[route_idx[jj]];
      iq_ins_val[jj] = chk_pass[route_idx[jj]] & iq_val[jj];
    end
  end

  //----------------------------------------------------------------------
  // Lane-side outputs: lane_val and dispatch_go
  //----------------------------------------------------------------------

  logic [p_pipe_bits-1:0] lane_to_pipe_map [p_num_input_lanes];

  always_comb begin
    for (int ii = 0; ii < p_num_input_lanes; ii++) begin
      lane_val[ii]         = 1'b0;
      lane_to_pipe_map[ii] = '0;
      for (int jj = 0; jj < p_num_pipes; jj++) begin
        if (iq_val[jj] && route_idx[jj] == p_input_lanes_bits'(ii)) begin
          lane_val[ii]         = 1'b1;
          lane_to_pipe_map[ii] = p_pipe_bits'(jj);
        end
      end
      dispatch_go[ii] = chk_pass[ii] & iq_rdy[lane_to_pipe_map[ii]];
    end
  end

endmodule

`endif // HW_DECODE_SSDIUROUTER_V
