//========================================================================
// MROBCoverage
//========================================================================
// A coverage class for a particular parametrization of the MROB

// //------------------------------------------------------------------------
// // VCS Coverage
// //------------------------------------------------------------------------
// `ifndef VERILATOR

// Interface between the DUT and coverage class --------------------------

// interface MROBTestIntf #(
//   parameter p_depth     = 32,
//   parameter p_msg_bits  = 32,
//   parameter p_num_lanes = 2
// )(
//   input logic clk
// );

//   localparam p_entry_bits = $clog2( p_depth );

//   logic rst;

//   //----------------------------------------------------------------------
//   // Insert
//   //----------------------------------------------------------------------

//   logic [p_entry_bits-1:0] ins_idx     [p_num_lanes];
//   logic [p_msg_bits-1:0]   ins_msg     [p_num_lanes];
//   logic                    ins_msg_val [p_num_lanes];
//   logic                    ins_rdy;
//   logic                    ins_en;
//   logic [p_entry_bits:0]   avail_slots;

//   //----------------------------------------------------------------------
//   // Dequeue
//   //----------------------------------------------------------------------

//   logic [p_entry_bits-1:0] deq_idx     [p_num_lanes];
//   logic [p_msg_bits-1:0]   deq_msg     [p_num_lanes];
//   logic                    deq_msg_val [p_num_lanes];
//   logic                    deq_rdy;
//   logic                    deq_en;

// endinterface

// // Coverage class --------------------------------------------------------

// class MROBCoverage #(
//   parameter p_depth     = 32,
//   parameter p_msg_bits  = 32,
//   parameter p_num_lanes = 2
// );

//   virtual MROBTestIntf #(p_depth, p_msg_bits, p_num_lanes) vintf;

//   // Covergroup ----------------------------------------------------------

//   covergroup mrob_cg @( posedge vintf.clk );

//     // Coverpoints

//     reset: coverpoint vintf.rst {
//       bins zero = { 0 };
//       bins one  = { 1 };
//       bins reserve = default;
//     }

//   endgroup

//   // Function to create an instance of this class

//   function new( virtual MROBTestIntf #(p_depth, p_msg_bits, p_num_lanes) vintf );
//     this.vintf = vintf;
//     mrob_cg = new();
//   endfunction

// endclass

//------------------------------------------------------------------------
// VCoverage
//------------------------------------------------------------------------
// `else

module MROBCoverage #(
  parameter p_depth     = 32,
  parameter p_msg_bits  = 32,
  parameter p_num_lanes = 2,
  parameter p_entry_bits = $clog2( p_depth )
)(
  input logic clk,
  input logic rst,

  // Insert

  input logic [p_entry_bits-1:0] ins_idx     [p_num_lanes],
  input logic [p_msg_bits-1:0]   ins_msg     [p_num_lanes],
  input logic                    ins_msg_val [p_num_lanes],
  input logic                    ins_rdy,
  input logic                    ins_en,
  input logic [p_entry_bits:0]   avail_slots,

  // Dequeue

  input logic [p_entry_bits-1:0] deq_idx     [p_num_lanes],
  input logic [p_msg_bits-1:0]   deq_msg     [p_num_lanes],
  input logic                    deq_msg_val [p_num_lanes],
  input logic                    deq_rdy,
  input logic                    deq_en,

  // Internal signals

  input logic [p_entry_bits-1:0] deq_ptr,
  input logic can_bypass
);

  localparam MAX_IDX = (p_entry_bits)'($unsigned(1 << p_entry_bits) - 1);
  localparam MAX_MSG = (p_msg_bits)'($unsigned(1 << p_msg_bits) - 1);
  localparam MAX_AVAIL_SLOTS = (p_entry_bits+1)'(p_depth);
  localparam MAX_PTR = p_depth - 1;

  // Coverpoints ---------------------------------------------------------

  // Reset
  RST_0: cover property ( @(posedge clk) rst == 0 );
  RST_1: cover property ( @(posedge clk) rst == 1 );

  // Insert index
  /* verilator lint_off WIDTHEXPAND */
  generate
    genvar i;
    for( i = 0; i < p_num_lanes; i++ ) begin : g_ins_idx
      INS_IDX_0:   cover property ( @(posedge clk) ins_idx[i] == 0 );
      INS_IDX_R0:  cover property ( @(posedge clk) (ins_idx[i] % 4) == 0 );
      INS_IDX_R1:  cover property ( @(posedge clk) (ins_idx[i] % 4) == 1 );
      INS_IDX_R2:  cover property ( @(posedge clk) (ins_idx[i] % 4) == 2 );
      INS_IDX_R3:  cover property ( @(posedge clk) (ins_idx[i] % 4) == 3 );
      INS_IDX_MAX: cover property ( @(posedge clk) ins_idx[i] == MAX_IDX );
    end
  endgenerate
  /* verilator lint_on WIDTHEXPAND */

  // Insert message
  generate
    for( i = 0; i < p_num_lanes; i++ ) begin : g_ins_msg
      INS_MSG_0:   cover property ( @(posedge clk) ins_msg[i] == 0 );
      INS_MSG_MID: cover property ( @(posedge clk) (ins_msg[i] > 0) && (ins_msg[i] < MAX_MSG) );
      INS_MSG_MAX: cover property ( @(posedge clk) ins_msg[i] == MAX_MSG );
    end
  endgenerate

  // Insert valid
  generate
    for( i = 0; i < p_num_lanes; i++ ) begin : g_ins_val
      INS_MSG_VAL_0: cover property ( @(posedge clk) ins_msg_val[i] == 0 );
      INS_MSG_VAL_1: cover property ( @(posedge clk) ins_msg_val[i] == 1 );
    end
  endgenerate

  // Insert ready
  INS_RDY_0: cover property ( @(posedge clk) ins_rdy == 0 );
  INS_RDY_1: cover property ( @(posedge clk) ins_rdy == 1 );

  // Insert enable
  INS_EN_0: cover property ( @(posedge clk) ins_en == 0 );
  INS_EN_1: cover property ( @(posedge clk) ins_en == 1 );

  // Available slots
  AVAIL_SLOTS_0: cover property ( @(posedge clk) avail_slots == 0 );
  AVAIL_SLOTS_1: cover property ( @(posedge clk) avail_slots == 1 );
  AVAIL_SLOTS_MID: cover property ( @(posedge clk) (avail_slots > 1) && (avail_slots < MAX_AVAIL_SLOTS) );
  AVAIL_SLOTS_MAX: cover property ( @(posedge clk) avail_slots == MAX_AVAIL_SLOTS );

  // Dequeue index
  /* verilator lint_off WIDTHEXPAND */
  generate
    for( i = 0; i < p_num_lanes; i++ ) begin : g_deq_idx
      DEQ_IDX_0:   cover property ( @(posedge clk) deq_idx[i] == 0 );
      DEQ_IDX_R0:  cover property ( @(posedge clk) (deq_idx[i] % 4) == 0 );
      DEQ_IDX_R1:  cover property ( @(posedge clk) (deq_idx[i] % 4) == 1 );
      DEQ_IDX_R2:  cover property ( @(posedge clk) (deq_idx[i] % 4) == 2 );
      DEQ_IDX_R3:  cover property ( @(posedge clk) (deq_idx[i] % 4) == 3 );
      DEQ_IDX_MAX: cover property ( @(posedge clk) deq_idx[i] == MAX_IDX );
    end
  endgenerate
  /* verilator lint_on WIDTHEXPAND */

  // Dequeue message
  generate
    for( i = 0; i < p_num_lanes; i++ ) begin : g_deq_msg
      DEQ_MSG_0:   cover property ( @(posedge clk) deq_msg[i] == 0 );
      DEQ_MSG_MID: cover property ( @(posedge clk) (deq_msg[i] > 0) && (deq_msg[i] < MAX_MSG) );
      DEQ_MSG_MAX: cover property ( @(posedge clk) deq_msg[i] == MAX_MSG );
    end
  endgenerate

  // Dequeue valid
  generate
    for( i = 0; i < p_num_lanes; i++ ) begin : g_deq_val
      DEQ_MSG_VAL_0: cover property ( @(posedge clk) deq_msg_val[i] == 0 );
      DEQ_MSG_VAL_1: cover property ( @(posedge clk) deq_msg_val[i] == 1 );
    end
  endgenerate

  // Dequeue ready
  DEQ_RDY_0: cover property ( @(posedge clk) deq_rdy == 0 );
  DEQ_RDY_1: cover property ( @(posedge clk) deq_rdy == 1 );

  // Dequeue enable
  DEQ_EN_0: cover property ( @(posedge clk) deq_en == 0 );
  DEQ_EN_1: cover property ( @(posedge clk) deq_en == 1 );

  // Dequeue pointer
  /* verilator lint_off WIDTHEXPAND */
  DEQ_PTR_0:       cover  property ( @(posedge clk) deq_ptr == 0 );
  DEQ_PTR_1:       cover  property ( @(posedge clk) deq_ptr == 1 );
  DEQ_PTR_MID:     cover  property ( @(posedge clk) (deq_ptr > 1) && (deq_ptr < MAX_PTR) );
  DEQ_PTR_MAX:     cover  property ( @(posedge clk) deq_ptr == MAX_PTR );
  DEQ_PTR_ILLEGAL: assert property ( @(posedge clk) !(deq_ptr > MAX_PTR) );
  /* verilator lint_on WIDTHEXPAND */

  // Bypass enable
  CAN_BYPASS_0: cover property ( @(posedge clk) can_bypass == 0 );
  CAN_BYPASS_1: cover property ( @(posedge clk) can_bypass == 1 );

  // Cover crosses -------------------------------------------------------

  // TODO

endmodule

// `endif /* VERILATOR */
