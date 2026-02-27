//========================================================================
// InstXbarIQCtrl.v
//========================================================================
// A crossbar scheduler for routing instructions from front-end lanes to
// issue queues with dedicated control instruction routing. Control
// instructions (matching p_ctrl_subset) are routed directly to the
// single output pipe whose p_pipe_subset matches p_ctrl_subset, using
// age-based priority and without depending on iq_rdy. Non-control
// instructions use the standard modified iSLIP algorithm.

`ifndef HW_DECODE_INSTXBARIQCTRL_V
`define HW_DECODE_INSTXBARIQCTRL_V

`include "defs/UArch.v"
`include "hw/util/MSeqAge.v"

import UArch::*;

module AgePE #(
  parameter p_num_input_lanes = 4,
  parameter p_seq_num_bits    = 8,
  parameter p_num_be_lanes    = 2
) (
  input  logic                         clk,
  input  logic                         rst,
  input  logic [p_num_input_lanes-1:0] req,
  input  logic [p_seq_num_bits-1:0]    age [p_num_input_lanes],
  output logic [p_num_input_lanes-1:0] gnt,
  output logic                         any_gnt,

  CommitNotif.sub commit [p_num_be_lanes]
);

  logic [p_num_input_lanes-1:0] is_oldest;
  logic older;

  MSeqAge #(
    .p_num_be_lanes(p_num_be_lanes)
  ) seq_age (
    .*
  );

  // For each request, check if it's the oldest among all requests
  always_comb begin
    older = 1'b0;
    for (int i = 0; i < p_num_input_lanes; i++) begin
      is_oldest[i] = req[i];
      if (req[i]) begin
        for (int j = 0; j < p_num_input_lanes; j++) begin
          if (req[j] && (i != j)) begin
            // Check if age[j] is older than age[i]
            // Using signed comparison for wrap-around handling

            older = seq_age.is_older(age[j], age[i]);

            // If older is true, age[j] is older (smaller seq_num)
            if (older) begin
              is_oldest[i] = 1'b0;
            end
          end
        end
      end
    end
  end

  assign gnt     = is_oldest;
  assign any_gnt = |req;

endmodule

module SlotsPE #(
  parameter p_num_pipes = 4,
  parameter p_slot_bits = 4
) (
  input  logic [p_num_pipes-1:0] req,
  input  logic [p_slot_bits:0]   slots [p_num_pipes],
  output logic [p_num_pipes-1:0] gnt,
  output logic                   any_gnt
);

  logic [p_num_pipes-1:0] has_most;

  // For each request, check if it has the most slots among all requests
  always_comb begin
    for (int i = 0; i < p_num_pipes; i++) begin
      has_most[i] = req[i];
      if (req[i]) begin
        for (int j = 0; j < p_num_pipes; j++) begin
          if (req[j] && (i != j)) begin
            // If slots[j] has MORE slots than slots[i],
            // or same slots but lower index, then i doesn't have most
            if (slots[j] > slots[i] || (slots[j] == slots[i] && j < i)) begin
              has_most[i] = 1'b0;
            end
          end
        end
      end
    end
  end

  assign gnt     = has_most;
  assign any_gnt = |req;

endmodule

module InstXbarIQCtrl #(
  parameter p_num_pipes                                = 8,
  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1},
  parameter rv_op_vec p_ctrl_subset                    = OP_JAL_VEC  |
                                                          OP_JALR_VEC |
                                                          OP_BEQ_VEC  |
                                                          OP_BNE_VEC  |
                                                          OP_BLT_VEC  |
                                                          OP_BGE_VEC  |
                                                          OP_BLTU_VEC |
                                                          OP_BGEU_VEC,
  parameter p_num_input_lanes                          = 2,
  parameter p_input_lanes_bits                         = p_num_input_lanes > 1 ? $clog2(p_num_input_lanes) : 1,
  parameter p_iq_depth                                 = 8,
  parameter p_iq_entries_bits                          = p_iq_depth > 1 ? $clog2(p_iq_depth) : 1,
  parameter p_seq_num_bits                             = 8,
  parameter p_num_iter                                 = 2,  // Number of iSLIP iterations
  parameter p_num_be_lanes                             = 2
) (
  input  logic                          clk,
  input  logic                          rst,
  input  rv_uop                         uop            [p_num_input_lanes],
  input  logic [p_seq_num_bits-1:0]     seq_num        [p_num_input_lanes],
  input  logic                          val            [p_num_input_lanes],

  input  logic                          iq_rdy         [p_num_pipes],
  input  logic [p_iq_entries_bits:0]    iq_avail_slots [p_num_pipes],

  output logic [p_input_lanes_bits-1:0] iq_route_idx   [p_num_pipes],
  output logic                          iq_val         [p_num_pipes],

  CommitNotif.sub commit [p_num_be_lanes]
);

  //----------------------------------------------------------------------
  // Detect control instructions on each input
  //----------------------------------------------------------------------

  logic is_ctrl [p_num_input_lanes];

  always_comb begin
    for (int ii = 0; ii < p_num_input_lanes; ii++) begin
      is_ctrl[ii] = in_subset(p_ctrl_subset, num_ops'(1 << uop[ii]));
    end
  end

  //----------------------------------------------------------------------
  // Control instruction routing (age-based, no iq_rdy dependency)
  //----------------------------------------------------------------------

  logic [p_num_input_lanes-1:0] ctrl_req_vec;

  always_comb begin
    for (int ii = 0; ii < p_num_input_lanes; ii++) begin
      ctrl_req_vec[ii] = val[ii] & is_ctrl[ii];
    end
  end

  logic [p_num_input_lanes-1:0] ctrl_gnt;
  logic                         ctrl_any_gnt;

  AgePE #(
    .p_num_input_lanes (p_num_input_lanes),
    .p_seq_num_bits    (p_seq_num_bits),
    .p_num_be_lanes    (p_num_be_lanes)
  ) u_ctrl_age (
    .clk     (clk),
    .rst     (rst),
    .req     (ctrl_req_vec),
    .age     (seq_num),
    .gnt     (ctrl_gnt),
    .any_gnt (ctrl_any_gnt),
    .commit  (commit)
  );

  logic [p_input_lanes_bits-1:0] ctrl_route_idx;

  always_comb begin
    ctrl_route_idx = '0;
    for (int ii = 0; ii < p_num_input_lanes; ii++) begin
      if (ctrl_gnt[ii])
        ctrl_route_idx = (p_input_lanes_bits)'(ii);
    end
  end

  //----------------------------------------------------------------------
  // Compute opcode compatibility matrix (non-control path only)
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

          if( in_subset(p_pipe_subsets[j], OP_ADD_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_ADD    );
          if( in_subset(p_pipe_subsets[j], OP_SUB_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_SUB    );
          if( in_subset(p_pipe_subsets[j], OP_AND_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_AND    );
          if( in_subset(p_pipe_subsets[j], OP_OR_VEC     ) ) val_uop[i][j] |= ( uop[i] == OP_OR     );
          if( in_subset(p_pipe_subsets[j], OP_XOR_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_XOR    );
          if( in_subset(p_pipe_subsets[j], OP_SLT_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_SLT    );
          if( in_subset(p_pipe_subsets[j], OP_SLTU_VEC   ) ) val_uop[i][j] |= ( uop[i] == OP_SLTU   );
          if( in_subset(p_pipe_subsets[j], OP_SRA_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_SRA    );
          if( in_subset(p_pipe_subsets[j], OP_SRL_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_SRL    );
          if( in_subset(p_pipe_subsets[j], OP_SLL_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_SLL    );
          if( in_subset(p_pipe_subsets[j], OP_LUI_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_LUI    );
          if( in_subset(p_pipe_subsets[j], OP_AUIPC_VEC  ) ) val_uop[i][j] |= ( uop[i] == OP_AUIPC  );
          if( in_subset(p_pipe_subsets[j], OP_LB_VEC     ) ) val_uop[i][j] |= ( uop[i] == OP_LB     );
          if( in_subset(p_pipe_subsets[j], OP_LH_VEC     ) ) val_uop[i][j] |= ( uop[i] == OP_LH     );
          if( in_subset(p_pipe_subsets[j], OP_LW_VEC     ) ) val_uop[i][j] |= ( uop[i] == OP_LW     );
          if( in_subset(p_pipe_subsets[j], OP_LBU_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_LBU    );
          if( in_subset(p_pipe_subsets[j], OP_LHU_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_LHU    );
          if( in_subset(p_pipe_subsets[j], OP_SB_VEC     ) ) val_uop[i][j] |= ( uop[i] == OP_SB     );
          if( in_subset(p_pipe_subsets[j], OP_SH_VEC     ) ) val_uop[i][j] |= ( uop[i] == OP_SH     );
          if( in_subset(p_pipe_subsets[j], OP_SW_VEC     ) ) val_uop[i][j] |= ( uop[i] == OP_SW     );
          if( in_subset(p_pipe_subsets[j], OP_JAL_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_JAL    );
          if( in_subset(p_pipe_subsets[j], OP_JALR_VEC   ) ) val_uop[i][j] |= ( uop[i] == OP_JALR   );
          if( in_subset(p_pipe_subsets[j], OP_BEQ_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_BEQ    );
          if( in_subset(p_pipe_subsets[j], OP_BNE_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_BNE    );
          if( in_subset(p_pipe_subsets[j], OP_BLT_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_BLT    );
          if( in_subset(p_pipe_subsets[j], OP_BGE_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_BGE    );
          if( in_subset(p_pipe_subsets[j], OP_BLTU_VEC   ) ) val_uop[i][j] |= ( uop[i] == OP_BLTU   );
          if( in_subset(p_pipe_subsets[j], OP_BGEU_VEC   ) ) val_uop[i][j] |= ( uop[i] == OP_BGEU   );
          if( in_subset(p_pipe_subsets[j], OP_MUL_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_MUL    );
          if( in_subset(p_pipe_subsets[j], OP_MULH_VEC   ) ) val_uop[i][j] |= ( uop[i] == OP_MULH   );
          if( in_subset(p_pipe_subsets[j], OP_MULHSU_VEC ) ) val_uop[i][j] |= ( uop[i] == OP_MULHSU );
          if( in_subset(p_pipe_subsets[j], OP_MULHU_VEC  ) ) val_uop[i][j] |= ( uop[i] == OP_MULHU  );
          if( in_subset(p_pipe_subsets[j], OP_DIV_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_DIV    );
          if( in_subset(p_pipe_subsets[j], OP_DIVU_VEC   ) ) val_uop[i][j] |= ( uop[i] == OP_DIVU   );
          if( in_subset(p_pipe_subsets[j], OP_REM_VEC    ) ) val_uop[i][j] |= ( uop[i] == OP_REM    );
          if( in_subset(p_pipe_subsets[j], OP_REMU_VEC   ) ) val_uop[i][j] |= ( uop[i] == OP_REMU   );
        end

        // Ctrl pipe: excluded from iSLIP (compat always 0)
        // Non-ctrl pipes: exclude control instructions
        if (p_pipe_subsets[j] == p_ctrl_subset) begin : gen_ctrl_compat
          assign iq_compat_op[i][j] = 1'b0;
        end else begin : gen_non_ctrl_compat
          assign iq_compat_op[i][j] = val_uop[i][j] & val[i] & !is_ctrl[i] & iq_rdy[j] & (iq_avail_slots[j] > 0);
        end
      end
    end
  endgenerate

  //----------------------------------------------------------------------
  // Modified iSLIP matching algorithm (non-control instructions)
  //----------------------------------------------------------------------

  // Per-iteration signals
  logic [p_num_input_lanes-1:0] g_req    [p_num_iter][p_num_pipes];
  logic [p_num_input_lanes-1:0] g_result [p_num_iter][p_num_pipes];
  logic                         g_any     [p_num_iter][p_num_pipes];

  logic [p_num_pipes-1:0] a_req    [p_num_iter][p_num_input_lanes];
  logic [p_num_pipes-1:0] a_result [p_num_iter][p_num_input_lanes];
  logic                   a_any    [p_num_iter][p_num_input_lanes];

  /* verilator lint_off UNOPTFLAT */
  logic input_free  [p_num_iter+1][p_num_input_lanes];
  logic output_free [p_num_iter+1][p_num_pipes];
  /* verilator lint_on UNOPTFLAT */

  logic match [p_num_iter][p_num_input_lanes][p_num_pipes];

  // All ports free at iteration 0
  generate
    for (i = 0; i < p_num_input_lanes; i++) begin : gep_num_input_lanesit_input_free
      assign input_free[0][i] = 1'b1;
    end
    for (j = 0; j < p_num_pipes; j++) begin : gep_num_input_lanesit_output_free
      assign output_free[0][j] = 1'b1;
    end
  endgenerate

  // Unrolled iterations
  generate
    for (genvar it = 0; it < p_num_iter; it++) begin : gen_iter

      // --- GRANT PHASE (age-based priority for inputs) ---
      for (j = 0; j < p_num_pipes; j++) begin : gen_grant

        // Build request vector for this output
        for (genvar ii = 0; ii < p_num_input_lanes; ii++) begin : gen_g_req
          assign g_req[it][j][ii] = iq_compat_op[ii][j] & input_free[it][ii] & output_free[it][j];
        end

        // Grant to oldest (smallest seq_num) requesting input
        AgePE #(
          .p_num_input_lanes (p_num_input_lanes),
          .p_seq_num_bits    (p_seq_num_bits),
          .p_num_be_lanes    (p_num_be_lanes)
        ) u_grant_age_enc (
          .clk    (clk),
          .rst    (rst),
          .req    (g_req[it][j]),
          .age    (seq_num),
          .gnt    (g_result[it][j]),
          .any_gnt(g_any[it][j]),
          .commit (commit)
        );
      end

      // --- ACCEPT PHASE (slot-based priority for outputs) ---
      for (i = 0; i < p_num_input_lanes; i++) begin : gen_accept

        // Build request vector for this input (transpose of grant results)
        for (genvar jj = 0; jj < p_num_pipes; jj++) begin : gen_a_req
          assign a_req[it][i][jj] = g_result[it][jj][i];
        end

        // Accept from output with most available slots
        SlotsPE #(
          .p_num_pipes (p_num_pipes),
          .p_slot_bits (p_iq_entries_bits)
        ) u_accept_slot_enc (
          .req    (a_req[it][i]),
          .slots  (iq_avail_slots),
          .gnt    (a_result[it][i]),
          .any_gnt(a_any[it][i])
        );
      end

      // --- COMPUTE MATCHES ---
      for (i = 0; i < p_num_input_lanes; i++) begin : gen_match_i
        for (j = 0; j < p_num_pipes; j++) begin : gen_match_j
          assign match[it][i][j] = g_result[it][j][i] & a_any[it][i] & a_result[it][i][j];
        end
      end

      // --- UPDATE FREE MASKS ---
      for (i = 0; i < p_num_input_lanes; i++) begin : gen_update_input_free
        assign input_free[it+1][i] = input_free[it][i] & ~a_any[it][i];
      end

      for (j = 0; j < p_num_pipes; j++) begin : gen_update_output_free
        logic any_match;

        always_comb begin
          any_match = 1'b0;
          for (int ii = 0; ii < p_num_input_lanes; ii++) begin
            if (match[it][ii][j])
              any_match = 1'b1;
          end
        end

        assign output_free[it+1][j] = output_free[it][j] & ~any_match;
      end

    end
  endgenerate

  //----------------------------------------------------------------------
  // Accumulate results and generate outputs
  //----------------------------------------------------------------------

  logic final_match [p_num_input_lanes][p_num_pipes];

  always_comb begin
    // Combine matches across all iterations
    for (int ii = 0; ii < p_num_input_lanes; ii++) begin
      for (int jj = 0; jj < p_num_pipes; jj++) begin
        final_match[ii][jj] = 1'b0;
        for (int it = 0; it < p_num_iter; it++) begin
          final_match[ii][jj] |= match[it][ii][jj];
        end
      end
    end

    // Generate output signals
    for (int jj = 0; jj < p_num_pipes; jj++) begin

      // Ctrl pipe: route oldest control instruction, no iq_rdy dependency
      if (p_pipe_subsets[jj] == p_ctrl_subset) begin
        iq_val[jj]       = ctrl_any_gnt;
        iq_route_idx[jj] = ctrl_route_idx;

      // Non-ctrl pipes: use iSLIP results
      end else begin
        iq_val[jj] = 1'b0;
        iq_route_idx[jj] = '0;

        for (int ii = 0; ii < p_num_input_lanes; ii++) begin
          if (final_match[ii][jj]) begin
            iq_val[jj] = 1'b1;
            iq_route_idx[jj] = (p_input_lanes_bits)'(ii);
          end
        end
      end
    end
  end

endmodule

`endif // HW_DECODE_INSTXBARIQCTRL_V