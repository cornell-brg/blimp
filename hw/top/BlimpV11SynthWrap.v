//========================================================================
// BlimpV11SynthWrap.v
//========================================================================
// Synthesis wrapper for BlimpV11. Flattens SV interfaces into plain
// ports so that Design Compiler can elaborate the design.

`ifndef HW_TOP_BLIMPV11SYNTHWRAP_V
`define HW_TOP_BLIMPV11SYNTHWRAP_V

`include "hw/top/BlimpV11.v"

`ifndef P_OPAQ_BITS
  `define P_OPAQ_BITS               8
`endif
`ifndef P_SEQ_NUM_BITS
  `define P_SEQ_NUM_BITS            5
`endif
`ifndef P_NUM_PHYS_REGS
  `define P_NUM_PHYS_REGS           36
`endif
`ifndef P_NUM_FE_LANES
  `define P_NUM_FE_LANES            2
`endif
`ifndef P_NUM_BE_LANES
  `define P_NUM_BE_LANES            2
`endif
`ifndef P_IQ_DEPTH
  `define P_IQ_DEPTH                4
`endif
`ifndef P_RECLAIM_WIDTH
  `define P_RECLAIM_WIDTH           4
`endif
`ifndef P_MAX_IN_FLIGHT
  `define P_MAX_IN_FLIGHT           4
`endif
`ifndef P_F_INTF_FIFO_DEPTH
  `define P_F_INTF_FIFO_DEPTH       1
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
`ifndef P_ALL_IQ_IN_ORDER
  `define P_ALL_IQ_IN_ORDER         0
`endif
`ifndef P_NUM_ALUS
  `define P_NUM_ALUS                2
`endif
`ifndef P_NUM_MULS
  `define P_NUM_MULS                1
`endif
`ifndef P_NUM_LDSTRS
  `define P_NUM_LDSTRS              1
`endif
`ifndef P_PIPE_BYPASS
  `define P_PIPE_BYPASS             'b11111
`endif

module BlimpV11SynthWrap #(

  // BEGIN TOP PARAMS
  parameter p_opaq_bits               = `P_OPAQ_BITS,
  parameter p_seq_num_bits            = `P_SEQ_NUM_BITS,
  parameter p_num_phys_regs           = `P_NUM_PHYS_REGS,
  parameter p_num_fe_lanes            = `P_NUM_FE_LANES,
  parameter p_num_be_lanes            = `P_NUM_BE_LANES,
  parameter p_iq_depth                = `P_IQ_DEPTH,
  parameter p_reclaim_width           = `P_RECLAIM_WIDTH,
  parameter p_max_in_flight           = `P_MAX_IN_FLIGHT,
  parameter p_f_intf_fifo_depth       = `P_F_INTF_FIFO_DEPTH,
  parameter p_x_intf_fifo_depth       = `P_X_INTF_FIFO_DEPTH,
  parameter p_alu_d_intf_fifo_depth   = `P_ALU_D_INTF_FIFO_DEPTH,
  parameter p_mul_d_intf_fifo_depth   = `P_MUL_D_INTF_FIFO_DEPTH,
  parameter p_mem_d_intf_fifo_depth   = `P_MEM_D_INTF_FIFO_DEPTH,
  parameter p_ctrl_d_intf_fifo_depth  = `P_CTRL_D_INTF_FIFO_DEPTH,
  parameter p_num_alus                = `P_NUM_ALUS,
  parameter p_num_muls                = `P_NUM_MULS,
  parameter p_num_ldstrs              = `P_NUM_LDSTRS,
  parameter p_all_iq_in_order         = `P_ALL_IQ_IN_ORDER,
  parameter p_pipe_bypass             = `P_PIPE_BYPASS,
  // END TOP PARAMS

  // Derived
  parameter p_imem_data_bits = p_num_fe_lanes * 32,
  parameter p_imem_strb_bits = p_num_fe_lanes * 4,
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

  output logic                        imem_req_val,
  input  logic                        imem_req_rdy,
  output logic [p_imem_msg_bits-1:0]  imem_req_msg,

  input  logic                        imem_resp_val,
  output logic                        imem_resp_rdy,
  input  logic [p_imem_msg_bits-1:0]  imem_resp_msg,

  //----------------------------------------------------------------------
  // Data Memory (flattened)
  //----------------------------------------------------------------------

  output logic                        dmem_req_val,
  input  logic                        dmem_req_rdy,
  output logic [p_dmem_msg_bits-1:0]  dmem_req_msg,

  input  logic                        dmem_resp_val,
  output logic                        dmem_resp_rdy,
  input  logic [p_dmem_msg_bits-1:0]  dmem_resp_msg,

  //----------------------------------------------------------------------
  // Instruction Trace (flattened, per BE lane)
  //----------------------------------------------------------------------

  output logic [p_num_be_lanes*32-1:0]               trace_pc,
  output logic [p_num_be_lanes*5-1:0]                trace_waddr,
  output logic [p_num_be_lanes*32-1:0]               trace_wdata,
  output logic [p_num_be_lanes-1:0]                  trace_wen,
  output logic [p_num_be_lanes-1:0]                  trace_val,
  output logic [p_num_be_lanes*p_seq_num_bits-1:0]   trace_seq_num
);

  //----------------------------------------------------------------------
  // Interface instantiations
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_words (p_num_fe_lanes)
  ) inst_mem ();

  MemIntf #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_words (1)
  ) data_mem [1]();

  InstTraceNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) inst_trace [p_num_be_lanes] ();

  //----------------------------------------------------------------------
  // Instruction memory connections
  //----------------------------------------------------------------------

  assign imem_req_val       = inst_mem.req_val;
  assign inst_mem.req_rdy   = imem_req_rdy;
  assign imem_req_msg       = inst_mem.req_msg;

  assign inst_mem.resp_val  = imem_resp_val;
  assign imem_resp_rdy      = inst_mem.resp_rdy;
  assign inst_mem.resp_msg  = imem_resp_msg;

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

  genvar i;
  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin: TRACE_FLAT
      assign trace_pc      [i*32 +: 32]            = inst_trace[i].pc;
      assign trace_waddr   [i*5 +: 5]              = inst_trace[i].waddr;
      assign trace_wdata   [i*32 +: 32]            = inst_trace[i].wdata;
      assign trace_wen     [i]                      = inst_trace[i].wen;
      assign trace_val     [i]                      = inst_trace[i].val;
      assign trace_seq_num [i*p_seq_num_bits +: p_seq_num_bits] = inst_trace[i].seq_num;
    end
  endgenerate

  //----------------------------------------------------------------------
  // DUT
  //----------------------------------------------------------------------

  BlimpV11 #(
    .p_opaq_bits               (p_opaq_bits),
    .p_seq_num_bits            (p_seq_num_bits),
    .p_num_phys_regs           (p_num_phys_regs),
    .p_num_fe_lanes            (p_num_fe_lanes),
    .p_num_be_lanes            (p_num_be_lanes),
    .p_iq_depth                (p_iq_depth),
    .p_reclaim_width           (p_reclaim_width),
    .p_max_in_flight           (p_max_in_flight),
    .p_f_intf_fifo_depth       (p_f_intf_fifo_depth),
    .p_x_intf_fifo_depth       (p_x_intf_fifo_depth),
    .p_alu_d_intf_fifo_depth   (p_alu_d_intf_fifo_depth),
    .p_mul_d_intf_fifo_depth   (p_mul_d_intf_fifo_depth),
    .p_mem_d_intf_fifo_depth   (p_mem_d_intf_fifo_depth),
    .p_ctrl_d_intf_fifo_depth  (p_ctrl_d_intf_fifo_depth),
    .p_num_alus                (p_num_alus),
    .p_num_muls                (p_num_muls),
    .p_num_ldstrs              (p_num_ldstrs),
    .p_pipe_bypass             (p_pipe_bypass),
    .p_all_iq_in_order         (p_all_iq_in_order)
  ) blimp_v11 (
    .clk        (clk),
    .rst        (rst),
    .inst_mem   (inst_mem),
    .data_mem   (data_mem),
    .inst_trace (inst_trace)
  );

endmodule

`endif // HW_TOP_BLIMPV11SYNTHWRAP_V
