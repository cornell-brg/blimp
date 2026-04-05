//========================================================================
// FetchSquashTracker.v
//========================================================================
// Tracks the number of in-flight fetch requests, the number of stale
// responses that must be drained after a squash, and squash restart
// state. Produces a should_drop signal that tells the datapath to
// discard incoming memory responses, and per-lane restart information
// for the first valid fetch block after a squash.

`ifndef HW_FETCH_FETCHSQUASHTRACKER_V
`define HW_FETCH_FETCHSQUASHTRACKER_V

module FetchSquashTracker
#(
  parameter p_max_in_flight = 16,
  parameter p_num_fe_lanes  = 2,

  // Derived parameters (do not override)
  parameter p_flight_bits   = $clog2(p_max_in_flight) + 1 > $clog2(p_num_fe_lanes) + 1
                               ? $clog2(p_max_in_flight) + 1
                               : $clog2(p_num_fe_lanes) + 1,
  parameter p_lane_idx_bits = p_num_fe_lanes > 1
                               ? $clog2(p_num_fe_lanes) : 1
)
(
  input  logic        clk,
  input  logic        rst,

  //----------------------------------------------------------------------
  // Control inputs
  //----------------------------------------------------------------------

  input  logic        squash_val,
  input  logic [31:0] squash_target,
  input  logic        memreq_xfer,
  input  logic        D_xfer_all,
  input  logic        mem_resp_val,

  //----------------------------------------------------------------------
  // Outputs
  //----------------------------------------------------------------------

  output logic [p_flight_bits-1:0]   num_in_flight,
  output logic [p_flight_bits-1:0]   num_to_squash,
  output logic                       should_drop,
  output logic                       needs_squash_restart,
  output logic [p_lane_idx_bits-1:0] squash_restart_offset
);

  localparam logic [p_flight_bits-1:0] c_num_fe_lanes = p_num_fe_lanes;

  //----------------------------------------------------------------------
  // Number of in-flight requests
  //----------------------------------------------------------------------

  logic [p_flight_bits-1:0] num_in_flight_next;

  always_ff @( posedge clk ) begin
    if( rst )
      num_in_flight <= '0;
    else
      num_in_flight <= num_in_flight_next;
  end

  always_comb begin
    num_in_flight_next = num_in_flight;

    // All in-flight messages should be squashed
    if( squash_val )
      num_in_flight_next = 0;

    // Add in-flight fetch block (c_num_fe_lanes messages) for each request to
    // imem that goes out
    if( memreq_xfer & !D_xfer_all )
      num_in_flight_next = num_in_flight_next + c_num_fe_lanes;

    // Response that comes back and is consumed by D
    if( D_xfer_all & !memreq_xfer )
      num_in_flight_next = num_in_flight_next - c_num_fe_lanes;
  end

  //----------------------------------------------------------------------
  // Number of in-flight requests to squash
  //----------------------------------------------------------------------

  logic [p_flight_bits-1:0] num_to_squash_next;

  always_ff @( posedge clk ) begin
    if( rst )
      num_to_squash <= '0;
    else
      num_to_squash <= num_to_squash_next;
  end

  always_comb begin
    num_to_squash_next = num_to_squash;

    // If squashing, the next number of instructions to squash is incremented by
    // the number of instructions in flight
    if( squash_val )
      num_to_squash_next = num_to_squash_next + num_in_flight;

    // Drain a stale fetch block when memory delivers a response and we have
    // some to squash (should_drop is guaranteed true, so mem.resp_rdy is high)
    if( mem_resp_val & ( num_to_squash_next > 0 ) )
      num_to_squash_next = num_to_squash_next - c_num_fe_lanes;
  end

  assign should_drop = squash_val | ( num_to_squash > 0 );

  //----------------------------------------------------------------------
  // Squash restart state
  //----------------------------------------------------------------------
  // After a squash, the first valid fetch block may start at a mid-block
  // lane. needs_squash_restart tracks whether the next good block needs
  // lane masking, and squash_restart_offset records which lane to start
  // from.

  logic [31:0] target_offset_bm;
  assign target_offset_bm = {{(32-$clog2(p_num_fe_lanes)){1'b0}},
                             {$clog2(p_num_fe_lanes){1'b1}}};

  always_ff @( posedge clk ) begin
    if( rst )
      needs_squash_restart <= 1'b0;
    else if( squash_val )
      needs_squash_restart <= 1'b1;
    else if( D_xfer_all )
      needs_squash_restart <= 1'b0;
  end

  always_ff @( posedge clk ) begin
    if( rst )
      squash_restart_offset <= '0;
    else if( squash_val )
      squash_restart_offset <= p_lane_idx_bits'((squash_target >> 2) & target_offset_bm);
  end

endmodule

`endif // HW_FETCH_FETCHSQUASHTRACKER_V
