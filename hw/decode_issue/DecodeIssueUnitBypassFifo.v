//========================================================================
// DecodeIssueUnitBypassFifo.v
//========================================================================
// Wraps FifoBypass and presents an instruction-window FIFO with
// per-lane editable head state.
//
// Push side:  accepts F__DIntf interfaces, packs them internally, and
//             drives F[i].rdy = !full.  Pushes when any lane has valid
//             data and the FIFO has space.
//
// Read side:  outputs per-lane fields for the head entry with shadow
//             edits (invalid / dispatched) applied.
//
// Shadow state resets to zero on pop (new head gets clean state).

`ifndef HW_DECODEISSUE_DECODEISSUEUNITBYPASSFIFO_V
`define HW_DECODEISSUE_DECODEISSUEUNITBYPASSFIFO_V

`include "hw/common/FifoBypass.v"
`include "intf/F__DIntf.v"

module DecodeIssueUnitBypassFifo
#(
  parameter type t_msg     = logic [31:0],
  parameter p_seq_num_bits = 5,
  parameter p_depth        = 2,
  parameter p_bypass       = 0,
  parameter p_num_lanes    = 2
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Fetch Interface (push side)
  //----------------------------------------------------------------------

  F__DIntf.D_intf F [p_num_lanes],

  //----------------------------------------------------------------------
  // Pop Control
  //----------------------------------------------------------------------

  input  logic pop,
  output logic empty,

  //----------------------------------------------------------------------
  // Head Entry Output (per-lane, with editable state applied)
  //----------------------------------------------------------------------

  output t_msg o_msg [p_num_lanes],

  //----------------------------------------------------------------------
  // Per-lane Edit Signals (head entry only)
  //----------------------------------------------------------------------

  input  logic [p_num_lanes-1:0] edit_set_invalid,
  input  logic [p_num_lanes-1:0] edit_set_dispatched
);

  //----------------------------------------------------------------------
  // Internal Types
  //----------------------------------------------------------------------

  localparam p_fifo_lane_bits  = $bits(t_msg);
  localparam p_fifo_entry_bits = p_num_lanes * p_fifo_lane_bits;

  //----------------------------------------------------------------------
  // Pack Fetch Data & Drive Rdy
  //----------------------------------------------------------------------

  logic                         fifo_full;
  logic [p_fifo_entry_bits-1:0] fifo_wdata;
  logic [p_num_lanes-1:0]       F_val_vec;

  genvar i;
  generate
    for( i = 0; i < p_num_lanes; i++ ) begin: PACK_GEN
      assign fifo_wdata[i*p_fifo_lane_bits +: p_fifo_lane_bits] = {
        F[i].val,
        F[i].inst,
        F[i].pc,
        F[i].seq_num,
        F[i].inst_valid,
        1'b0
      };
      assign F[i].rdy    = !fifo_full;
      assign F_val_vec[i] = F[i].val;
    end
  endgenerate

  logic fifo_push;
  assign fifo_push = |F_val_vec & !fifo_full;

  //----------------------------------------------------------------------
  // Underlying FIFO
  //----------------------------------------------------------------------

  logic                         fifo_empty;
  logic [p_fifo_entry_bits-1:0] fifo_rdata;

  FifoBypass #(
    .p_entry_bits (p_fifo_entry_bits),
    .p_depth      (p_depth),
    .p_bypass     (p_bypass)
  ) fifo (
    .clk   (clk),
    .rst   (rst),
    .push  (fifo_push),
    .pop   (pop),
    .empty (fifo_empty),
    .full  (fifo_full),
    .wdata (fifo_wdata),
    .rdata (fifo_rdata)
  );

  assign empty = fifo_empty;

  //----------------------------------------------------------------------
  // Shadow State
  //----------------------------------------------------------------------

  logic [p_num_lanes-1:0] invalid_r;
  logic [p_num_lanes-1:0] dispatched_r;

  always_ff @( posedge clk ) begin
    if ( rst || pop ) begin
      invalid_r    <= '0;
      dispatched_r <= '0;
    end else begin
      invalid_r    <= invalid_r    | edit_set_invalid;
      dispatched_r <= dispatched_r | edit_set_dispatched;
    end
  end

  //----------------------------------------------------------------------
  // Unpack FIFO Head + Shadow → Outputs
  //----------------------------------------------------------------------

  always_comb begin
    for( int j = 0; j < p_num_lanes; j++ ) begin
      t_msg lane;
      lane = fifo_rdata[j*p_fifo_lane_bits +: p_fifo_lane_bits];
      
      o_msg[j] = '{
        !fifo_empty & lane.val & !invalid_r[j],
        lane.inst,
        lane.pc,
        lane.seq_num,
        lane.inst_valid,
        dispatched_r[j]
      };
    end
  end

endmodule

`endif // HW_DECODEISSUE_DECODEISSUEUNITBYPASSFIFO_V
