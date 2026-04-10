//========================================================================
// ISLIPCore.v
//========================================================================
// A parameterized iSLIP matching engine. Performs multi-iteration
// input-output matching with:
//   - Age-based grant phase (each output selects the oldest requesting input)
//   - Configurable accept phase (slot-based or lowest-index priority)
//
// The parent module provides:
//   - A compatibility matrix (compat[i][j]) encoding which inputs can
//     route to which outputs (including validity, readiness, etc.)
//   - Initial output free mask (to control which outputs are active)
//   - Age information for the grant phase
//   - Slot information for the accept phase (if using slot-based accept)
//
// Used by SSInstXbar (decode-issue crossbar) and WBArb (writeback arbiter).

`ifndef HW_COMMON_ISLIPCORE_V
`define HW_COMMON_ISLIPCORE_V

//----------------------------------------------------------------------
// AgePE
//----------------------------------------------------------------------
// Age-based priority encoder that selects the oldest requesting input.

module AgePE #(
  parameter p_num_input_lanes = 4,
  parameter p_seq_num_bits    = 8
) (
  input  logic [p_num_input_lanes-1:0] req,
  input  logic [p_seq_num_bits-1:0]    age            [p_num_input_lanes],
  input  logic [p_seq_num_bits-1:0]    oldest_seq_num,
  output logic [p_num_input_lanes-1:0] gnt
);

  logic [p_num_input_lanes-1:0] is_oldest;
  logic                         older;

  // For each request, check if it's the oldest among all requests
  always_comb begin
    older = 1'b0;
    for (int i = 0; i < p_num_input_lanes; i++) begin
      is_oldest[i] = req[i];
      if (req[i]) begin
        for (int j = 0; j < p_num_input_lanes; j++) begin
          if (req[j] && (i != j)) begin
            // Check if age[j] is older than age[i]
            // Using XOR-based wrap-around-safe comparison

            older = ( age[j] < age[i]      ) ^
                    ( age[j] < oldest_seq_num ) ^
                    ( age[i] < oldest_seq_num );

            // If older is true, age[j] is older
            if (older) begin
              is_oldest[i] = 1'b0;
            end
          end
        end
      end
    end
  end

  assign gnt     = is_oldest;

endmodule

//----------------------------------------------------------------------
// SlotsPE
//----------------------------------------------------------------------
// Slot-based priority encoder that selects the output with the most
// available slots.

module SlotsPE #(
  parameter p_num_pipes = 4,
  parameter p_slot_bits = 4
) (
  input  logic [p_num_pipes-1:0] req,
  input  logic [p_slot_bits:0]   slots   [p_num_pipes],
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

//----------------------------------------------------------------------
// ISLIPCore
//----------------------------------------------------------------------

module ISLIPCore #(
  parameter p_num_inputs   = 4,
  parameter p_num_outputs  = 4,
  parameter p_seq_num_bits = 8,
  parameter p_num_iter     = 2,
  parameter p_accept_mode  = 0,   // 0 = SlotsPE, 1 = lowest-index
  parameter p_slot_bits    = 4    // only used when p_accept_mode = 0
) (
  // Compatibility matrix: compat[i][j] = input i can route to output j
  input  logic                      compat           [p_num_inputs][p_num_outputs],

  // Age inputs for grant phase
  input  logic [p_seq_num_bits-1:0] seq_num          [p_num_inputs],
  input  logic [p_seq_num_bits-1:0] oldest_seq_num,

  // Initial output availability
  input  logic                      output_free_init [p_num_outputs],

  // Slot counts for SlotsPE accept (unused when p_accept_mode = 1)
  input  logic [p_slot_bits:0]      slots            [p_num_outputs],

  // Output: match matrix
  output logic                      final_match      [p_num_inputs][p_num_outputs]
);

  //----------------------------------------------------------------------
  // Per-iteration signals
  //----------------------------------------------------------------------

  logic [p_num_inputs-1:0]  g_req    [p_num_iter][p_num_outputs];
  logic [p_num_inputs-1:0]  g_result [p_num_iter][p_num_outputs];

  logic [p_num_outputs-1:0] a_req    [p_num_iter][p_num_inputs];
  logic [p_num_outputs-1:0] a_result [p_num_iter][p_num_inputs];
  logic                     a_any    [p_num_iter][p_num_inputs];

  /* verilator lint_off UNOPTFLAT */
  logic input_free  [p_num_iter+1][p_num_inputs];
  logic output_free [p_num_iter+1][p_num_outputs];
  /* verilator lint_on UNOPTFLAT */

  logic match [p_num_iter][p_num_inputs][p_num_outputs];

  //----------------------------------------------------------------------
  // Initialize free masks
  //----------------------------------------------------------------------

  genvar gi, gj;
  generate
    for (gi = 0; gi < p_num_inputs; gi++) begin : gen_init_input_free
      assign input_free[0][gi] = 1'b1;
    end
    for (gj = 0; gj < p_num_outputs; gj++) begin : gen_init_output_free
      assign output_free[0][gj] = output_free_init[gj];
    end
  endgenerate

  //----------------------------------------------------------------------
  // Unrolled iSLIP iterations
  //----------------------------------------------------------------------

  generate
    for (genvar it = 0; it < p_num_iter; it++) begin : gen_iter

      // --- GRANT PHASE: each output selects the oldest requesting input ---
      for (gj = 0; gj < p_num_outputs; gj++) begin : gen_grant

        // Build request vector for this output
        for (genvar ii = 0; ii < p_num_inputs; ii++) begin : gen_g_req
          assign g_req[it][gj][ii] = compat[ii][gj]
                                   & input_free[it][ii]
                                   & output_free[it][gj];
        end

        // Grant to the oldest requesting input
        AgePE #(
          .p_num_input_lanes (p_num_inputs),
          .p_seq_num_bits    (p_seq_num_bits)
        ) u_grant (
          .req            (g_req[it][gj]),
          .age            (seq_num),
          .oldest_seq_num (oldest_seq_num),
          .gnt            (g_result[it][gj])
        );
      end

      // --- ACCEPT PHASE ---
      for (gi = 0; gi < p_num_inputs; gi++) begin : gen_accept

        // Build request vector (transpose of grant results)
        for (genvar jj = 0; jj < p_num_outputs; jj++) begin : gen_a_req
          assign a_req[it][gi][jj] = g_result[it][jj][gi];
        end

        if (p_accept_mode) begin : gen_accept_lsb
          // Lowest-index priority: isolate lowest set bit
          assign a_any[it][gi]    = |a_req[it][gi];
          assign a_result[it][gi] = a_req[it][gi] & (~a_req[it][gi] + 1);

        end else begin : gen_accept_slots
          // Slot-based priority: select output with most available slots
          SlotsPE #(
            .p_num_pipes (p_num_outputs),
            .p_slot_bits (p_slot_bits)
          ) u_accept (
            .req     (a_req[it][gi]),
            .slots   (slots),
            .gnt     (a_result[it][gi]),
            .any_gnt (a_any[it][gi])
          );
        end
      end

      // --- COMPUTE MATCHES ---
      for (gi = 0; gi < p_num_inputs; gi++) begin : gen_match_i
        for (gj = 0; gj < p_num_outputs; gj++) begin : gen_match_j
          assign match[it][gi][gj] = g_result[it][gj][gi]
                                   & a_any[it][gi]
                                   & a_result[it][gi][gj];
        end
      end

      // --- UPDATE FREE MASKS ---
      for (gi = 0; gi < p_num_inputs; gi++) begin : gen_upd_input
        assign input_free[it+1][gi] = input_free[it][gi] & ~a_any[it][gi];
      end

      for (gj = 0; gj < p_num_outputs; gj++) begin : gen_upd_output
        logic any_match_j;

        always_comb begin
          any_match_j = 1'b0;
          for (int ii = 0; ii < p_num_inputs; ii++)
            if (match[it][ii][gj]) any_match_j = 1'b1;
        end

        assign output_free[it+1][gj] = output_free[it][gj] & ~any_match_j;
      end

    end
  endgenerate

  //----------------------------------------------------------------------
  // Accumulate matches across iterations
  //----------------------------------------------------------------------

  always_comb begin
    for (int ii = 0; ii < p_num_inputs; ii++)
      for (int jj = 0; jj < p_num_outputs; jj++) begin
        final_match[ii][jj] = 1'b0;
        for (int it = 0; it < p_num_iter; it++)
          final_match[ii][jj] |= match[it][ii][jj];
      end
  end

endmodule

`endif // HW_COMMON_ISLIPCORE_V
