//========================================================================
// SSDIURouter.v
//========================================================================
// Pure data router for the decode-issue unit.  Given a lane-to-pipe
// mapping from SSInstMapper, muxes per-lane instruction data to
// per-pipe outputs and computes dispatch_go / iq_ins_try.
//
// The message struct (t_msg) is opaque to this module.

`ifndef HW_DECODE_SSDIUROUTER_V
`define HW_DECODE_SSDIUROUTER_V

module SSDIURouter #(
  parameter type t_msg         = logic [31:0],
  parameter p_num_pipes        = 8,
  parameter p_num_input_lanes  = 2,
  parameter p_input_lanes_bits = p_num_input_lanes > 1 ? $clog2(p_num_input_lanes) : 1,
  parameter p_pipe_bits        = p_num_pipes > 1 ? $clog2(p_num_pipes) : 1
) (
  // Per input lane: instruction messages
  input  t_msg                          in_msg   [p_num_input_lanes],

  // Per input lane: final check pass (for iq_ins_try / dispatch_go)
  input  logic                          chk_pass [p_num_input_lanes],

  // Per pipe: IQ readiness
  input  logic                          iq_rdy   [p_num_pipes],

  // Mapping from SSInstMapper
  input  logic [p_input_lanes_bits-1:0] route_idx        [p_num_pipes],
  input  logic                          iq_val           [p_num_pipes],
  input  logic [p_pipe_bits-1:0]        lane_to_pipe_map [p_num_input_lanes],

  // Per pipe: routed instruction data outputs
  output t_msg                          iq_msg     [p_num_pipes],
  output logic                          iq_ins_try [p_num_pipes],

  // Per lane: dispatch result
  output logic                          dispatch_go [p_num_input_lanes]
);

  //----------------------------------------------------------------------
  // Data muxing: per-lane data -> per-pipe outputs
  //----------------------------------------------------------------------

  always_comb begin
    for (int jj = 0; jj < p_num_pipes; jj++) begin
      iq_msg[jj]     = in_msg[route_idx[jj]];
      iq_ins_try[jj] = chk_pass[route_idx[jj]] & iq_val[jj];
    end
  end

  //----------------------------------------------------------------------
  // dispatch_go
  //----------------------------------------------------------------------

  always_comb begin
    for (int ii = 0; ii < p_num_input_lanes; ii++)
      dispatch_go[ii] = chk_pass[ii] & iq_rdy[lane_to_pipe_map[ii]];
  end

endmodule

`endif // HW_DECODE_SSDIUROUTER_V
