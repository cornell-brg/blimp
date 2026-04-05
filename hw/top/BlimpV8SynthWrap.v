//========================================================================
// BlimpV8SynthWrap.v
//========================================================================
// Synthesis wrapper for BlimpV8. Flattens SV interfaces into plain
// ports so that Design Compiler can elaborate the design.

`ifndef HW_TOP_BLIMPV8SYNTHWRAP_V
`define HW_TOP_BLIMPV8SYNTHWRAP_V

`include "hw/top/BlimpV8.v"

`ifndef P_OPAQ_BITS
  `define P_OPAQ_BITS               8
`endif
`ifndef P_SEQ_NUM_BITS
  `define P_SEQ_NUM_BITS            5
`endif
`ifndef P_NUM_PHYS_REGS
  `define P_NUM_PHYS_REGS           36
`endif
`ifndef P_RECLAIM_WIDTH
  `define P_RECLAIM_WIDTH           4
`endif
`ifndef P_MAX_IN_FLIGHT
  `define P_MAX_IN_FLIGHT           2
`endif
`ifndef P_X_INTF_FIFO_DEPTH
  `define P_X_INTF_FIFO_DEPTH       1
`endif
`ifndef P_ALU_D_INTF_FIFO_DEPTH
  `define P_ALU_D_INTF_FIFO_DEPTH   1
`endif
`ifndef P_MUL_D_INTF_FIFO_DEPTH
  `define P_MUL_D_INTF_FIFO_DEPTH   1
`endif
`ifndef P_MEM_D_INTF_FIFO_DEPTH
  `define P_MEM_D_INTF_FIFO_DEPTH   1
`endif
`ifndef P_CTRL_D_INTF_FIFO_DEPTH
  `define P_CTRL_D_INTF_FIFO_DEPTH  1
`endif
`ifndef P_NUM_ALUS
  `define P_NUM_ALUS                2
`endif
`ifndef P_NUM_MULS
  `define P_NUM_MULS                2
`endif
`ifndef P_NUM_LDSTRS
  `define P_NUM_LDSTRS              1
`endif

module BlimpV8SynthWrap #(

  // BEGIN TOP PARAMS
  parameter p_opaq_bits              = `P_OPAQ_BITS,
  parameter p_seq_num_bits           = `P_SEQ_NUM_BITS,
  parameter p_num_phys_regs          = `P_NUM_PHYS_REGS,
  parameter p_reclaim_width          = `P_RECLAIM_WIDTH,
  parameter p_max_in_flight          = `P_MAX_IN_FLIGHT,
  parameter p_x_intf_fifo_depth      = `P_X_INTF_FIFO_DEPTH,
  parameter p_alu_d_intf_fifo_depth  = `P_ALU_D_INTF_FIFO_DEPTH,
  parameter p_mul_d_intf_fifo_depth  = `P_MUL_D_INTF_FIFO_DEPTH,
  parameter p_mem_d_intf_fifo_depth  = `P_MEM_D_INTF_FIFO_DEPTH,
  parameter p_ctrl_d_intf_fifo_depth = `P_CTRL_D_INTF_FIFO_DEPTH,
  parameter p_num_alus               = `P_NUM_ALUS,
  parameter p_num_muls               = `P_NUM_MULS,
  parameter p_num_ldstrs             = `P_NUM_LDSTRS,
  // END TOP PARAMS

  // Derived
  parameter p_imem_data_bits = 32,
  parameter p_imem_strb_bits = 4,
  parameter p_imem_msg_bits  = 1 + p_opaq_bits + 32 + p_imem_strb_bits + p_imem_data_bits,
  parameter p_dmem_data_bits = 32,
  parameter p_dmem_strb_bits = 4,
  parameter p_dmem_msg_bits  = 1 + p_opaq_bits + 32 + p_dmem_strb_bits + p_dmem_data_bits
) (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Instruction Memory (flattened)
  //----------------------------------------------------------------------

  output logic                       imem_req_val,
  input  logic                       imem_req_rdy,
  output logic [p_imem_msg_bits-1:0] imem_req_msg,

  input  logic                       imem_resp_val,
  output logic                       imem_resp_rdy,
  input  logic [p_imem_msg_bits-1:0] imem_resp_msg,

  //----------------------------------------------------------------------
  // Data Memory
  //----------------------------------------------------------------------

  output logic [p_num_ldstrs-1:0]     dmem_req_val,
  input  logic [p_num_ldstrs-1:0]     dmem_req_rdy,
  output logic [p_dmem_msg_bits-1:0]  dmem_req_msg,

  input  logic [p_num_ldstrs-1:0]    dmem_resp_val,
  output logic [p_num_ldstrs-1:0]    dmem_resp_rdy,
  input  logic [p_dmem_msg_bits-1:0]  dmem_resp_msg,

  //----------------------------------------------------------------------
  // Instruction Trace (flattened)
  //----------------------------------------------------------------------

  output logic               [31:0] trace_pc,
  output logic                [4:0] trace_waddr,
  output logic               [31:0] trace_wdata,
  output logic                      trace_wen,
  output logic                      trace_val,
  output logic [p_seq_num_bits-1:0] trace_seq_num
);

  //----------------------------------------------------------------------
  // Interface instantiations
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_words (1)
  ) inst_mem ();

  MemIntf #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_words (1)
  ) data_mem [p_num_ldstrs]();

  InstTraceNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) inst_trace ();

  //----------------------------------------------------------------------
  // Instruction memory connections
  //----------------------------------------------------------------------

  assign imem_req_val      = inst_mem.req_val;
  assign inst_mem.req_rdy  = imem_req_rdy;
  assign imem_req_msg      = inst_mem.req_msg;

  assign inst_mem.resp_val = imem_resp_val;
  assign imem_resp_rdy     = inst_mem.resp_rdy;
  assign inst_mem.resp_msg = imem_resp_msg;

  //----------------------------------------------------------------------
  // Data memory connections
  //----------------------------------------------------------------------

  assign dmem_req_val         = data_mem[0].req_val;
  assign data_mem[0].req_rdy  = dmem_req_rdy;
  assign dmem_req_msg         = data_mem[0].req_msg;

  assign data_mem[0].resp_val = dmem_resp_val;
  assign dmem_resp_rdy        = data_mem[0].resp_rdy;
  assign data_mem[0].resp_msg = dmem_resp_msg;

  //----------------------------------------------------------------------
  // Instruction trace connections
  //----------------------------------------------------------------------

  assign trace_pc      = inst_trace.pc;
  assign trace_waddr   = inst_trace.waddr;
  assign trace_wdata   = inst_trace.wdata;
  assign trace_wen     = inst_trace.wen;
  assign trace_val     = inst_trace.val;
  assign trace_seq_num = inst_trace.seq_num;

  //----------------------------------------------------------------------
  // DUT
  //----------------------------------------------------------------------

  BlimpV8 #(
    .p_opaq_bits              (p_opaq_bits),
    .p_seq_num_bits           (p_seq_num_bits),
    .p_num_phys_regs          (p_num_phys_regs),
    .p_reclaim_width          (p_reclaim_width),
    .p_max_in_flight          (p_max_in_flight),
    .p_x_intf_fifo_depth      (p_x_intf_fifo_depth),
    .p_alu_d_intf_fifo_depth  (p_alu_d_intf_fifo_depth),
    .p_mul_d_intf_fifo_depth  (p_mul_d_intf_fifo_depth),
    .p_mem_d_intf_fifo_depth  (p_mem_d_intf_fifo_depth),
    .p_ctrl_d_intf_fifo_depth (p_ctrl_d_intf_fifo_depth),
    .p_num_alus               (p_num_alus),
    .p_num_muls               (p_num_muls),
    .p_num_ldstrs             (p_num_ldstrs)
  ) blimp_v8 (
    .clk        (clk),
    .rst        (rst),
    .inst_mem   (inst_mem),
    .data_mem   (data_mem),
    .inst_trace (inst_trace)
  );

endmodule

`endif // HW_TOP_BLIMPV8SYNTHWRAP_V
