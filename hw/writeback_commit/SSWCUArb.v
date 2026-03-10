//========================================================================
// SSWCUArb.v
//========================================================================
// An age-based iSLIP arbiter for writeback with integrated selection
// muxing. Selects up to m of the oldest requesting inputs across
// p_num_be_lanes output lanes, then muxes the granted pipe data into
// sequential output lanes. Analogous to SSDIURouter but for the
// writeback side (N pipes -> M BE lanes).
//
// The message struct (t_msg) must contain .val and .seq_num fields.

`ifndef HW_WRITEBACK_SSWCUARB_V
`define HW_WRITEBACK_SSWCUARB_V

`include "hw/common/ISLIPCore.v"
`include "hw/util/SSSeqAge.v"
`include "intf/CommitNotif.v"

module SSWCUArb #(
  parameter type t_msg         = logic,
  parameter p_num_pipes        = 8,
  parameter p_num_be_lanes     = 2,
  parameter p_seq_num_bits     = 8,
  parameter p_num_iter         = p_num_be_lanes
) (
  input  logic                            clk,
  input  logic                            rst,
  input  logic                            en,
  input  logic [$clog2(p_num_be_lanes):0] m,

  // Per-pipe inputs / outputs
  input  t_msg                            in_msg  [p_num_pipes],
  output logic                            rdy     [p_num_pipes],

  // Per-BE-lane outputs (selected/muxed)
  output t_msg                            sel_msg [p_num_be_lanes],

  CommitNotif.sub commit [p_num_be_lanes]
);

  //----------------------------------------------------------------------
  // Extract control signals from struct
  //----------------------------------------------------------------------

  logic [p_seq_num_bits-1:0] in_seq_num [p_num_pipes];
  logic                      in_val     [p_num_pipes];

  always_comb begin
    for (int ii = 0; ii < p_num_pipes; ii++) begin
      in_seq_num[ii] = in_msg[ii].seq_num;
      in_val[ii]     = in_msg[ii].val;
    end
  end

  //----------------------------------------------------------------------
  // Age tracking
  //----------------------------------------------------------------------

  logic [p_seq_num_bits-1:0] oldest_seq_num;

  SSSeqAge #(
    .p_num_be_lanes (p_num_be_lanes),
    .p_seq_num_bits (p_seq_num_bits)
  ) seq_age (
    .clk              (clk),
    .rst              (rst),
    .oldest_seq_num   (oldest_seq_num),
    .commit           (commit)
  );

  //----------------------------------------------------------------------
  // Build request and compatibility matrix
  //----------------------------------------------------------------------

  logic [p_num_pipes-1:0] req;

  always_comb begin
    for (int ii = 0; ii < p_num_pipes; ii++)
      req[ii] = in_val[ii];
  end

  logic compat [p_num_pipes][p_num_be_lanes];

  always_comb begin
    for (int ii = 0; ii < p_num_pipes; ii++)
      for (int jj = 0; jj < p_num_be_lanes; jj++)
        compat[ii][jj] = req[ii];
  end

  //----------------------------------------------------------------------
  // Output free init: only lanes within m are active
  //----------------------------------------------------------------------

  logic output_free_init [p_num_be_lanes];

  genvar gj;
  generate
    for (gj = 0; gj < p_num_be_lanes; gj++) begin : gen_output_free_init
      assign output_free_init[gj] = (($clog2(p_num_be_lanes)+1)'(gj) < m);
    end
  endgenerate

  //----------------------------------------------------------------------
  // Dummy slots (unused, ISLIPCore uses lowest-index accept)
  //----------------------------------------------------------------------

  logic [1:0] dummy_slots [p_num_be_lanes];

  generate
    for (gj = 0; gj < p_num_be_lanes; gj++) begin : gen_dummy_slots
      assign dummy_slots[gj] = '0;
    end
  endgenerate

  //----------------------------------------------------------------------
  // iSLIP matching via ISLIPCore (lowest-index accept)
  //----------------------------------------------------------------------

  logic final_match [p_num_pipes][p_num_be_lanes];

  ISLIPCore #(
    .p_num_inputs   (p_num_pipes),
    .p_num_outputs  (p_num_be_lanes),
    .p_seq_num_bits (p_seq_num_bits),
    .p_num_iter     (p_num_iter),
    .p_accept_mode  (1),             // Lowest-index accept
    .p_slot_bits    (1)
  ) u_islip (
    .compat           (compat),
    .seq_num          (in_seq_num),
    .oldest_seq_num   (oldest_seq_num),
    .output_free_init (output_free_init),
    .slots            (dummy_slots),
    .final_match      (final_match)
  );

  //----------------------------------------------------------------------
  // Grant computation
  //----------------------------------------------------------------------

  logic [p_num_pipes-1:0] gnt;

  always_comb begin
    gnt = '0;
    if (en) begin
      for (int ii = 0; ii < p_num_pipes; ii++)
        for (int jj = 0; jj < p_num_be_lanes; jj++)
          gnt[ii] |= final_match[ii][jj];
    end
  end

  //----------------------------------------------------------------------
  // Selection muxing: granted pipes -> sequential output lanes
  //----------------------------------------------------------------------

  int j_sel, k_sel;

  always_comb begin
    for (j_sel = 0; j_sel < p_num_be_lanes; j_sel++)
      sel_msg[j_sel] = '0;

    k_sel = 0;
    for (j_sel = 0; j_sel < p_num_pipes; j_sel++) begin
      if (gnt[j_sel] && (k_sel < p_num_be_lanes)) begin
        sel_msg[k_sel] = in_msg[j_sel];
        k_sel++;
      end
    end
  end

  //----------------------------------------------------------------------
  // Ready output: granted pipes are ready
  //----------------------------------------------------------------------

  generate
    for (genvar gi = 0; gi < p_num_pipes; gi++) begin : gen_rdy
      assign rdy[gi] = gnt[gi];
    end
  endgenerate

endmodule

`endif // HW_WRITEBACK_SSWCUARB_V
