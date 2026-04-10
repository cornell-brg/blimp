//========================================================================
// SSInstMapper.v
//========================================================================
// Instruction-to-pipe mapper for the superscalar decode-issue unit.
// Computes an opcode/readiness compatibility matrix and uses a modified
// iSLIP algorithm with age-based priority and slot-based accept to
// produce a one-to-one mapping from front-end lanes to back-end pipes.
//
// Outputs per-pipe route indices and per-lane matched-pipe indices so
// that a downstream router can mux data without knowledge of the
// matching policy.
//
// The message struct (t_msg) must contain .uop, .seq_num,
// .src_pending0, and .src_pending1 fields.

`ifndef HW_DECODEISSUE_SSINSTMAPPER_V
`define HW_DECODEISSUE_SSINSTMAPPER_V

`include "defs/UArch.v"
`include "hw/common/ISLIPCore.v"

import UArch::*;

module SSInstMapper #(
  parameter type t_msg         = logic [31:0],
  parameter p_num_pipes        = 8,
  parameter p_num_input_lanes  = 2,
  parameter p_input_lanes_bits = p_num_input_lanes > 1 ? $clog2(p_num_input_lanes) : 1,
  parameter p_pipe_bits        = p_num_pipes > 1 ? $clog2(p_num_pipes) : 1,
  parameter p_iq_depth         = 8,
  parameter p_iq_entries_bits  = p_iq_depth > 1 ? $clog2(p_iq_depth) : 1,
  parameter p_seq_num_bits     = 8,
  parameter p_num_iter         = 2,
  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1},
  parameter logic [p_num_pipes-1:0]     p_pipe_bypass  = '0
) (
  // Per input lane: instruction messages and validity
  input  t_msg                       in_msg         [p_num_input_lanes],
  input  logic                       val            [p_num_input_lanes],

  // Per pipe: IQ status
  input  logic                       iq_rdy         [p_num_pipes],
  input  logic [p_iq_entries_bits:0] iq_avail_slots [p_num_pipes],

  // Oldest in-flight sequence number (from external SSSeqAge)
  input  logic [p_seq_num_bits-1:0]  oldest_seq_num,

  // Per pipe: mapping results
  output logic [p_input_lanes_bits-1:0] route_idx [p_num_pipes],
  output logic                          iq_val    [p_num_pipes],

  // Per lane: mapping results
  output logic                       lane_val         [p_num_input_lanes],
  output logic [p_pipe_bits-1:0]     lane_to_pipe_map [p_num_input_lanes]
);

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
  // Source readiness (for bypass pipe gating)
  //----------------------------------------------------------------------

  logic src_ready [p_num_input_lanes];

  always_comb begin
    for (int ii = 0; ii < p_num_input_lanes; ii++)
      src_ready[ii] = !in_msg[ii].src_pending0 & !in_msg[ii].src_pending1;
  end

  //----------------------------------------------------------------------
  // Compute opcode compatibility matrix
  //----------------------------------------------------------------------

  logic iq_compat_op [p_num_input_lanes][p_num_pipes];
  logic val_uop      [p_num_input_lanes][p_num_pipes];

  genvar i, j;
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

        assign iq_compat_op[i][j] = val_uop[i][j] & val[i]
                                   & iq_rdy[j] & (iq_avail_slots[j] > 0)
                                   & (src_ready[i] | !p_pipe_bypass[j]);
      end
    end
  endgenerate

  //----------------------------------------------------------------------
  // iSLIP matching via ISLIPCore (slot-based accept)
  //----------------------------------------------------------------------

  logic output_free_init [p_num_pipes];
  generate
    for (j = 0; j < p_num_pipes; j++) begin : gen_output_free_init
      assign output_free_init[j] = 1'b1;
    end
  endgenerate

  logic final_match [p_num_input_lanes][p_num_pipes];

  ISLIPCore #(
    .p_num_inputs   (p_num_input_lanes),
    .p_num_outputs  (p_num_pipes),
    .p_seq_num_bits (p_seq_num_bits),
    .p_num_iter     (p_num_iter),
    .p_accept_mode  (0),                // Slots-based accept
    .p_slot_bits    (p_iq_entries_bits)
  ) u_islip (
    .compat           (iq_compat_op),
    .seq_num          (in_seq_num),
    .oldest_seq_num   (oldest_seq_num),
    .output_free_init (output_free_init),
    .slots            (iq_avail_slots),
    .final_match      (final_match)
  );

  //----------------------------------------------------------------------
  // Route index and lane mapping computation
  //----------------------------------------------------------------------

  always_comb begin
    // Per-pipe: which input lane is routed here
    for (int jj = 0; jj < p_num_pipes; jj++) begin
      iq_val[jj]    = 1'b0;
      route_idx[jj] = '0;

      for (int ii = 0; ii < p_num_input_lanes; ii++) begin
        if (final_match[ii][jj]) begin
          iq_val[jj]    = 1'b1;
          route_idx[jj] = (p_input_lanes_bits)'(ii);
        end
      end
    end

    // Per-lane: which pipe this lane was matched to
    for (int ii = 0; ii < p_num_input_lanes; ii++) begin
      lane_val[ii]         = 1'b0;
      lane_to_pipe_map[ii] = '0;
      for (int jj = 0; jj < p_num_pipes; jj++) begin
        if (iq_val[jj] && route_idx[jj] == p_input_lanes_bits'(ii)) begin
          lane_val[ii]         = 1'b1;
          lane_to_pipe_map[ii] = p_pipe_bits'(jj);
        end
      end
    end
  end

endmodule

`endif // HW_DECODEISSUE_SSINSTMAPPER_V
