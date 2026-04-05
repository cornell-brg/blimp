//========================================================================
// DIUFifo.v
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

`ifndef HW_DECODEISSUE_DIUBYPASSFIFO_V
`define HW_DECODEISSUE_DIUBYPASSFIFO_V

`include "hw/common/Fifo.v"
`include "intf/F__DIntf.v"

module DIUFifo
#(
  parameter type t_msg     = logic [31:0],
  parameter p_seq_num_bits = 5,
  parameter p_depth        = 2,
  parameter p_num_lanes    = 2
)(
  input  logic clk,
  input  logic rst,
  input  logic clear,

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

  input  logic [1:0] edit_inst_state [p_num_lanes]
);

  //----------------------------------------------------------------------
  // Internal Types
  //----------------------------------------------------------------------

  localparam [1:0] INST_STATUS_INVALID    = 2'b00,
                   INST_STATUS_READY      = 2'b01,
                   INST_STATUS_DISPATCHED = 2'b10;

  localparam p_fifo_lane_bits  = $bits(t_msg);
  localparam p_fifo_entry_bits = p_num_lanes * p_fifo_lane_bits;

  //----------------------------------------------------------------------
  // Pack Fetch Data & Drive Rdy
  //----------------------------------------------------------------------

  logic                         fifo_full;
  logic [p_fifo_entry_bits-1:0] fifo_wdata;
  logic [p_num_lanes-1:0]       F_val_vec;

  // Extract interface fields into arrays (interfaces can't be runtime-indexed).
  logic                      F_val_arr        [p_num_lanes];
  logic [31:0]               F_inst_arr       [p_num_lanes];
  logic [31:0]               F_pc_arr         [p_num_lanes];
  logic [p_seq_num_bits-1:0] F_seq_num_arr    [p_num_lanes];
  logic [1:0]                F_inst_status_arr [p_num_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_lanes; i++ ) begin: PACK_GEN
      assign F[i].rdy             = !fifo_full | pop;
      assign F_val_vec[i]         = F[i].val;
      assign F_val_arr[i]         = F[i].val;
      assign F_inst_arr[i]        = F[i].inst;
      assign F_pc_arr[i]          = F[i].pc;
      assign F_seq_num_arr[i]     = F[i].seq_num;
      assign F_inst_status_arr[i] = F[i].inst_status;
    end
  endgenerate

  always_comb begin
    for( int ii = 0; ii < p_num_lanes; ii++ ) begin
      t_msg packed_lane;
      packed_lane            = '0;
      packed_lane.val        = F_val_arr[ii];
      packed_lane.inst       = F_inst_arr[ii];
      packed_lane.pc         = F_pc_arr[ii];
      packed_lane.seq_num    = F_seq_num_arr[ii];
      packed_lane.inst_status = F_inst_status_arr[ii];
      fifo_wdata[ii*p_fifo_lane_bits +: p_fifo_lane_bits] = packed_lane;
    end
  end

  logic fifo_push;
  assign fifo_push = |F_val_vec & (!fifo_full | pop);

  //----------------------------------------------------------------------
  // Underlying FIFO
  //----------------------------------------------------------------------

  logic                         fifo_empty;
  logic [p_fifo_entry_bits-1:0] fifo_rdata;

  Fifo #(
    .p_entry_bits (p_fifo_entry_bits),
    .p_depth      (p_depth)
  ) fifo (
    .clk   (clk),
    .rst   (rst),
    .clear (clear),
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

  logic [1:0] inst_state_r [p_num_lanes];

  always_ff @( posedge clk ) begin
    if ( rst || pop || clear ) begin
      for( int j = 0; j < p_num_lanes; j++ )
        inst_state_r[j] <= INST_STATUS_READY;
    end else begin
      for( int j = 0; j < p_num_lanes; j++ ) begin
        if( inst_state_r[j] == INST_STATUS_INVALID ||
            edit_inst_state[j] == INST_STATUS_INVALID )
          inst_state_r[j] <= INST_STATUS_INVALID;
        else if( edit_inst_state[j] == INST_STATUS_DISPATCHED )
          inst_state_r[j] <= INST_STATUS_DISPATCHED;
      end
    end
  end

  //----------------------------------------------------------------------
  // Unpack FIFO Head + Shadow → Outputs
  //----------------------------------------------------------------------

  always_comb begin
    for( int j = 0; j < p_num_lanes; j++ ) begin
      t_msg lane;
      lane = fifo_rdata[j*p_fifo_lane_bits +: p_fifo_lane_bits];

      o_msg[j]     = lane;
      o_msg[j].val = !fifo_empty & lane.val &
                     (inst_state_r[j] != INST_STATUS_INVALID);

      if( inst_state_r[j] != INST_STATUS_READY )
        o_msg[j].inst_status = inst_state_r[j];
    end
  end

endmodule

`endif // HW_DECODEISSUE_DIUBYPASSFIFO_V
