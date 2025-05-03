//========================================================================
// ReqArbiter.v
//========================================================================
// Arbitrate between multiple memory requests

`ifndef FPGA_NET_REQARBITER_V
`define FPGA_NET_REQARBITER_V

`include "fpga/net/MemNetReq.v"
`include "hw/common/RRArb.v"

module ReqArbiter #(
  parameter p_num_arb   = 3,
  parameter p_opaq_bits = 8
) (
  input  logic clk,
  input  logic rst,

  MemNetReq.server arb [p_num_arb],
  MemNetReq.client gnt
);

  // ---------------------------------------------------------------------
  // Use Round-Robin arbitration
  // ---------------------------------------------------------------------

  logic [p_num_arb-1:0] rr_req, rr_gnt;

  genvar i;
  generate
    for( i = 0; i < p_num_arb; i++ ) begin: PACK_VAL
      assign rr_req[i] = arb[i].val;
    end
  endgenerate

  RRArb #( p_num_arb ) rr_arb (
    .clk (clk),
    .rst (rst),
    .en  (gnt.rdy),
    .req (rr_req),
    .gnt (rr_gnt)
  );

  assign gnt.val = |rr_gnt;

  // ---------------------------------------------------------------------
  // Assign ready signals based on gnt
  // ---------------------------------------------------------------------

  logic [p_num_arb-1:0] arb_rdy;

  generate
    for( i = 0; i < p_num_arb; i++ ) begin: PACK_RDY
      assign arb[i].rdy = arb_rdy[i] & gnt.rdy;
    end
  endgenerate

  assign arb_rdy = rr_gnt;

  // ---------------------------------------------------------------------
  // Pass message based on gnt
  // ---------------------------------------------------------------------

  localparam p_msg_bits = 71 + p_opaq_bits; // Hardcode for now

  logic [p_msg_bits-1:0] arb_msgs [p_num_arb];

  generate
    for( i = 0; i < p_num_arb; i = i + 1 ) begin: PACK_MSG
      assign arb_msgs[i] = ( rr_gnt[i] ) ? arb[i].msg : '0;
    end
  endgenerate

  assign gnt.msg = arb_msgs.or();
endmodule

`endif // FPGA_NET_REQARBITER_V
