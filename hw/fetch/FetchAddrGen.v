//========================================================================
// FetchAddrGen.v
//========================================================================
// Generates memory request addresses for the fetch unit. Maintains the
// current fetch block base address and produces the request address and
// valid signal, accounting for squash redirects.

`ifndef HW_FETCH_FETCHADDRGEN_V
`define HW_FETCH_FETCHADDRGEN_V

module FetchAddrGen
#(
  parameter p_num_fe_lanes  = 2,
  parameter p_max_in_flight = 16,
  parameter p_rst_addr      = 32'h200,

  // Derived parameters (do not override)
  parameter p_flight_bits   = $clog2(p_max_in_flight) + 1 > $clog2(p_num_fe_lanes) + 1
                               ? $clog2(p_max_in_flight) + 1
                               : $clog2(p_num_fe_lanes) + 1
)
(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Control inputs
  //----------------------------------------------------------------------

  input  logic        squash_val,
  input  logic [31:0] squash_target,
  input  logic        memreq_rdy,

  input  logic [p_flight_bits-1:0] num_in_flight,
  input  logic [p_flight_bits-1:0] num_to_squash,

  //----------------------------------------------------------------------
  // Outputs
  //----------------------------------------------------------------------

  output logic        mem_req_val,
  output logic [31:0] mem_req_addr,
  output logic        memreq_xfer
);

  // Bitmask to extract the fetch-block-aligned base from an address
  logic [31:0] target_base_bm;
  assign target_base_bm = {{(32-$clog2(p_num_fe_lanes)){1'b1}},
                           {$clog2(p_num_fe_lanes){1'b0}}} << 2;

  //----------------------------------------------------------------------
  // Current fetch block base address
  //----------------------------------------------------------------------

  localparam logic [31:0] c_lane_stride = p_num_fe_lanes << 2;

  logic [31:0] curr_fetch_block_base;

  always_ff @( posedge clk ) begin
    if ( rst )
      curr_fetch_block_base <= p_rst_addr;
    else if ( squash_val & memreq_xfer )
      curr_fetch_block_base <= (squash_target & target_base_bm) + c_lane_stride;
    else if ( squash_val )
      curr_fetch_block_base <= (squash_target & target_base_bm);
    else if ( memreq_xfer )
      curr_fetch_block_base <= mem_req_addr + c_lane_stride;
  end

  //----------------------------------------------------------------------
  // Request address and valid
  //----------------------------------------------------------------------

  always_comb begin
    if ( squash_val )
      mem_req_addr = (squash_target & target_base_bm);
    else
      mem_req_addr = curr_fetch_block_base;
  end

  localparam logic [p_flight_bits-1:0] c_max_in_flight = p_max_in_flight[p_flight_bits-1:0];

  assign mem_req_val  = squash_val |
                        (num_in_flight + num_to_squash < c_max_in_flight)
                        && !rst;
  assign memreq_xfer = mem_req_val & memreq_rdy;

endmodule

`endif // HW_FETCH_FETCHADDRGEN_V
