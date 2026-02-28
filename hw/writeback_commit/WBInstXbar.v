//========================================================================
// WBInstXbar.v
//========================================================================
// Wrapper around SSInstXbar for writeback arbitration. Maps execution
// pipes as input lanes and commit lanes as output pipes, with universal
// opcode compatibility (any pipe can go to any lane). Uses age-based
// priority to select the oldest instructions first.

`ifndef HW_WRITEBACK_WBINSTXBAR_V
`define HW_WRITEBACK_WBINSTXBAR_V

`include "hw/decode_issue/SSInstXbar.v"

import UArch::*;

module WBInstXbar #(
  parameter p_num_pipes    = 8,
  parameter p_num_be_lanes = 2,
  parameter p_pipe_bits    = p_num_pipes > 1 ? $clog2(p_num_pipes) : 1,
  parameter p_seq_num_bits = 8,
  parameter p_num_iter     = p_num_be_lanes
) (
  input  logic                      clk,
  input  logic                      rst,

  input  logic [p_seq_num_bits-1:0] seq_num     [p_num_pipes],
  input  logic                      val         [p_num_pipes],

  input  logic [p_seq_num_bits:0]   avail_slots,

  output logic [p_pipe_bits-1:0]    route_idx   [p_num_be_lanes],
  output logic                      out_val     [p_num_be_lanes],
  output logic                      gnt         [p_num_pipes],

  CommitNotif.sub commit [p_num_be_lanes]
);

  //----------------------------------------------------------------------
  // Universal opcode - all outputs accept OP_ADD
  //----------------------------------------------------------------------

  rv_uop xbar_uop [p_num_pipes];

  always_comb begin
    for (int i = 0; i < p_num_pipes; i++)
      xbar_uop[i] = OP_ADD;
  end

  //----------------------------------------------------------------------
  // Per-lane readiness based on available slots
  //----------------------------------------------------------------------

  logic       xbar_rdy   [p_num_be_lanes];
  logic [1:0] xbar_avail [p_num_be_lanes];

  always_comb begin
    for (int i = 0; i < p_num_be_lanes; i++) begin
      xbar_rdy[i]   = (avail_slots > (p_seq_num_bits+1)'(i));
      xbar_avail[i] = (avail_slots > (p_seq_num_bits+1)'(i)) ? 2'd1 : 2'd0;
    end
  end

  //----------------------------------------------------------------------
  // SSInstXbar: pipes as input lanes, commit lanes as output pipes
  //----------------------------------------------------------------------

  SSInstXbar #(
    .p_num_pipes       (p_num_be_lanes),
    .p_pipe_subsets    ('{default: OP_ADD_VEC}),
    .p_num_input_lanes (p_num_pipes),
    .p_iq_depth        (2),
    .p_seq_num_bits    (p_seq_num_bits),
    .p_num_iter        (p_num_iter),
    .p_num_be_lanes    (p_num_be_lanes)
  ) u_xbar (
    .clk            (clk),
    .rst            (rst),
    .uop            (xbar_uop),
    .seq_num        (seq_num),
    .val            (val),
    .iq_rdy         (xbar_rdy),
    .iq_avail_slots (xbar_avail),
    .iq_route_idx   (route_idx),
    .iq_val         (out_val),
    .commit         (commit)
  );

  //----------------------------------------------------------------------
  // Per-pipe grant from per-lane route assignments
  //----------------------------------------------------------------------

  always_comb begin
    for (int p = 0; p < p_num_pipes; p++)
      gnt[p] = 1'b0;
    for (int l = 0; l < p_num_be_lanes; l++) begin
      if (out_val[l])
        gnt[route_idx[l]] = 1'b1;
    end
  end

endmodule

`endif // HW_WRITEBACK_WBINSTXBAR_V