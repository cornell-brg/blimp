//========================================================================
// WCUFifo.v
//========================================================================
// Wraps FifoBypass and presents a multi-lane FIFO for the writeback
// pipeline registers.
//
// Push side:  accepts t_msg array, packs all lanes into one FIFO entry.
// Read side:  outputs per-lane t_msg from the FIFO head.

`ifndef HW_WRITEBACK_WCUBYPASSFIFO_V
`define HW_WRITEBACK_WCUBYPASSFIFO_V

`include "hw/common/Fifo.v"

module WCUFifo
#(
  parameter p_entry_bits = 32,
  parameter p_depth      = 2,
  parameter p_num_lanes  = 2,
  parameter p_lane_bits  = p_entry_bits / p_num_lanes
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Push Side
  //----------------------------------------------------------------------

  input  logic push,
  input  logic [p_lane_bits-1:0] i_msg [p_num_lanes],
  output logic full,

  //----------------------------------------------------------------------
  // Pop Side
  //----------------------------------------------------------------------

  input  logic pop,
  output logic empty,
  output logic [p_lane_bits-1:0] o_msg [p_num_lanes]
);

  //----------------------------------------------------------------------
  // Pack Input Lanes
  //----------------------------------------------------------------------

  logic [p_entry_bits-1:0] fifo_wdata;

  genvar i;
  generate
    for( i = 0; i < p_num_lanes; i++ ) begin: PACK_GEN
      assign fifo_wdata[i*p_lane_bits +: p_lane_bits] = i_msg[i];
    end
  endgenerate

  //----------------------------------------------------------------------
  // Underlying FIFO
  //----------------------------------------------------------------------

  logic                    fifo_empty;
  logic                    fifo_full;
  logic [p_entry_bits-1:0] fifo_rdata;

  Fifo #(
    .p_entry_bits (p_entry_bits),
    .p_depth      (p_depth)
  ) fifo (
    .clk   (clk),
    .rst   (rst),
    .clear (1'b0),
    .push  (push),
    .pop   (pop),
    .empty (fifo_empty),
    .full  (fifo_full),
    .wdata (fifo_wdata),
    .rdata (fifo_rdata)
  );

  assign empty = fifo_empty;
  assign full  = fifo_full;

  //----------------------------------------------------------------------
  // Unpack FIFO Head
  //----------------------------------------------------------------------

  always_comb begin
    for( int j = 0; j < p_num_lanes; j++ ) begin
      o_msg[j] = fifo_rdata[j*p_lane_bits +: p_lane_bits];
    end
  end

endmodule

`endif // HW_WRITEBACK_WCUBYPASSFIFO_V
