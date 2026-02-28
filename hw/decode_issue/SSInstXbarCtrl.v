//========================================================================
// SSInstXbarCtrl.v
//========================================================================
// Wrapper around SSInstXbar that separates control instruction routing.
// Control instructions (matching p_ctrl_subset) are routed directly to
// the single output pipe whose p_pipe_subset matches p_ctrl_subset,
// using age-based priority and without depending on iq_rdy. Non-control
// instructions are forwarded to SSInstXbar for standard iSLIP routing.

`ifndef HW_DECODE_SSINSTXBARCTRL_V
`define HW_DECODE_SSINSTXBARCTRL_V

`include "hw/decode_issue/SSInstXbar.v"

import UArch::*;

module SSInstXbarCtrl #(
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
  parameter p_num_iter                                 = 2,
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
  // Mask inputs to SSInstXbar: hide control instructions and ctrl pipe
  //----------------------------------------------------------------------

  logic                      xbar_val         [p_num_input_lanes];
  logic                      xbar_iq_rdy      [p_num_pipes];
  logic [p_iq_entries_bits:0] xbar_iq_avail   [p_num_pipes];

  // Filter control instructions out of val
  always_comb begin
    for (int ii = 0; ii < p_num_input_lanes; ii++) begin
      xbar_val[ii] = val[ii] & !is_ctrl[ii];
    end
  end

  // Force ctrl pipe's iq_rdy/avail_slots to 0 so iSLIP ignores it
  genvar k;
  generate
    for (k = 0; k < p_num_pipes; k++) begin : gen_mask_pipes
      if (p_pipe_subsets[k] == p_ctrl_subset) begin : gen_ctrl_mask
        assign xbar_iq_rdy[k]    = 1'b0;
        assign xbar_iq_avail[k]  = '0;
      end else begin : gen_pass_mask
        assign xbar_iq_rdy[k]    = iq_rdy[k];
        assign xbar_iq_avail[k]  = iq_avail_slots[k];
      end
    end
  endgenerate

  //----------------------------------------------------------------------
  // SSInstXbar handles non-control instruction routing via iSLIP
  //----------------------------------------------------------------------

  logic [p_input_lanes_bits-1:0] xbar_route_idx [p_num_pipes];
  logic                          xbar_iq_val    [p_num_pipes];

  SSInstXbar #(
    .p_num_pipes       (p_num_pipes),
    .p_pipe_subsets    (p_pipe_subsets),
    .p_num_input_lanes (p_num_input_lanes),
    .p_iq_depth        (p_iq_depth),
    .p_seq_num_bits    (p_seq_num_bits),
    .p_num_iter        (p_num_iter),
    .p_num_be_lanes    (p_num_be_lanes)
  ) u_xbar (
    .clk            (clk),
    .rst            (rst),
    .uop            (uop),
    .seq_num        (seq_num),
    .val            (xbar_val),
    .iq_rdy         (xbar_iq_rdy),
    .iq_avail_slots (xbar_iq_avail),
    .iq_route_idx   (xbar_route_idx),
    .iq_val         (xbar_iq_val),
    .commit         (commit)
  );

  //----------------------------------------------------------------------
  // Control age-based instruction routing
  //----------------------------------------------------------------------

  SSSeqAge #(
    .p_num_be_lanes(p_num_be_lanes)
  ) seq_age (
    .*
  );

  logic [p_seq_num_bits-1:0] oldest_seq_num;
  assign oldest_seq_num = seq_age.oldest_seq_num;

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
    .p_seq_num_bits    (p_seq_num_bits)
  ) u_ctrl_age (
    .req            (ctrl_req_vec),
    .age            (seq_num),
    .oldest_seq_num (oldest_seq_num),
    .gnt            (ctrl_gnt),
    .any_gnt        (ctrl_any_gnt)
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
  // Combine outputs
  //----------------------------------------------------------------------

  always_comb begin
    for (int jj = 0; jj < p_num_pipes; jj++) begin
      if (p_pipe_subsets[jj] == p_ctrl_subset) begin
        iq_val[jj]       = ctrl_any_gnt;
        iq_route_idx[jj] = ctrl_route_idx;
      end else begin
        iq_val[jj]       = xbar_iq_val[jj];
        iq_route_idx[jj] = xbar_route_idx[jj];
      end
    end
  end

endmodule

`endif // HW_DECODE_SSINSTXBARCTRL_V
