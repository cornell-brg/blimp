//========================================================================
// FetchUnitL5SynthWrap.v
//========================================================================
// Synthesis wrapper for FetchUnitL5. Flattens SV interfaces into plain
// ports so that Design Compiler can elaborate the design.

`ifndef HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL5SYNTHWRAP_V
`define HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL5SYNTHWRAP_V

`include "hw/fetch/fetch_unit_variants/FetchUnitL5.v"

module FetchUnitL5SynthWrap
#(
  parameter p_opaq_bits     = 8,
  parameter p_reclaim_width = 2,
  parameter p_seq_num_bits  = 5,
  parameter p_max_in_flight = 16,
  parameter p_num_fe_lanes  = 4,
  parameter p_num_be_lanes  = 4,
  parameter p_num_phys_regs = 36,

  // Derived
  parameter p_phys_addr_bits = $clog2(p_num_phys_regs),
  parameter p_mem_data_bits  = p_num_fe_lanes * 32,
  parameter p_mem_strb_bits  = p_num_fe_lanes * 4,
  parameter p_mem_msg_bits   = 1 + p_opaq_bits + 32 + p_mem_strb_bits + p_mem_data_bits
)
(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Memory Interface (flattened)
  //----------------------------------------------------------------------

  output logic                       mem_req_val,
  input  logic                       mem_req_rdy,
  output logic [p_mem_msg_bits-1:0]  mem_req_msg,

  input  logic                       mem_resp_val,
  output logic                       mem_resp_rdy,
  input  logic [p_mem_msg_bits-1:0]  mem_resp_msg,

  //----------------------------------------------------------------------
  // F -> D Interface (flattened, per lane)
  //----------------------------------------------------------------------

  output logic               [31:0] D_inst        [p_num_fe_lanes],
  output logic               [31:0] D_pc          [p_num_fe_lanes],
  output logic                      D_val         [p_num_fe_lanes],
  input  logic                      D_rdy         [p_num_fe_lanes],
  output logic [p_seq_num_bits-1:0] D_seq_num     [p_num_fe_lanes],
  output logic                [1:0] D_inst_status [p_num_fe_lanes],

  //----------------------------------------------------------------------
  // Commit Interface (flattened, per BE lane)
  //----------------------------------------------------------------------

  input  logic               [31:0] commit_pc      [p_num_be_lanes],
  input  logic                [4:0] commit_waddr   [p_num_be_lanes],
  input  logic               [31:0] commit_wdata   [p_num_be_lanes],
  input  logic                      commit_wen     [p_num_be_lanes],
  input  logic                      commit_val     [p_num_be_lanes],
  input  logic [p_seq_num_bits-1:0] commit_seq_num [p_num_be_lanes],
  input  logic [p_phys_addr_bits-1:0] commit_ppreg [p_num_be_lanes],

  //----------------------------------------------------------------------
  // Squash Interface (flattened)
  //----------------------------------------------------------------------

  input  logic [p_seq_num_bits-1:0] squash_seq_num,
  input  logic               [31:0] squash_target,
  input  logic                      squash_val
);

  //----------------------------------------------------------------------
  // Interface instantiations
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_words (p_num_fe_lanes)
  ) mem_intf ();

  F__DIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) d_intf [p_num_fe_lanes] ();

  CommitNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) commit_intf [p_num_be_lanes] ();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_intf ();

  //----------------------------------------------------------------------
  // Memory interface connections
  //----------------------------------------------------------------------

  assign mem_req_val       = mem_intf.req_val;
  assign mem_intf.req_rdy  = mem_req_rdy;
  assign mem_req_msg       = mem_intf.req_msg;

  assign mem_intf.resp_val = mem_resp_val;
  assign mem_resp_rdy      = mem_intf.resp_rdy;
  assign mem_intf.resp_msg = mem_resp_msg;

  //----------------------------------------------------------------------
  // F -> D interface connections
  //----------------------------------------------------------------------

  genvar i;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: D_INTF_FLAT
      assign D_inst[i]        = d_intf[i].inst;
      assign D_pc[i]          = d_intf[i].pc;
      assign D_val[i]         = d_intf[i].val;
      assign d_intf[i].rdy    = D_rdy[i];
      assign D_seq_num[i]     = d_intf[i].seq_num;
      assign D_inst_status[i] = d_intf[i].inst_status;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Commit interface connections
  //----------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin: COMMIT_FLAT
      assign commit_intf[i].pc      = commit_pc[i];
      assign commit_intf[i].waddr   = commit_waddr[i];
      assign commit_intf[i].wdata   = commit_wdata[i];
      assign commit_intf[i].wen     = commit_wen[i];
      assign commit_intf[i].val     = commit_val[i];
      assign commit_intf[i].seq_num = commit_seq_num[i];
      assign commit_intf[i].ppreg   = commit_ppreg[i];
    end
  endgenerate

  //----------------------------------------------------------------------
  // Squash interface connections
  //----------------------------------------------------------------------

  assign squash_intf.seq_num = squash_seq_num;
  assign squash_intf.target  = squash_target;
  assign squash_intf.val     = squash_val;

  //----------------------------------------------------------------------
  // DUT
  //----------------------------------------------------------------------

  FetchUnitL5 #(
    .p_reclaim_width (p_reclaim_width),
    .p_seq_num_bits  (p_seq_num_bits),
    .p_max_in_flight (p_max_in_flight),
    .p_num_fe_lanes  (p_num_fe_lanes),
    .p_num_be_lanes  (p_num_be_lanes)
  ) dut (
    .clk    (clk),
    .rst    (rst),
    .mem    (mem_intf),
    .D      (d_intf),
    .commit (commit_intf),
    .squash (squash_intf)
  );

endmodule

`endif // HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL5SYNTHWRAP_V
