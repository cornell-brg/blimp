//========================================================================
// BlimpV11TestHarness.v
//========================================================================
// A top-level testing harness for Blimp V11

`ifndef HW_TOP_TEST_BLIMPV11TESTHARNESS_V
`define HW_TOP_TEST_BLIMPV11TESTHARNESS_V

`include "asm/assemble.v"
`include "hw/top/BlimpV11.v"
`include "intf/MemIntf.v"
`include "intf/InstTraceNotif.v"
`include "test/fl/MemIntfTestServer.v"
`include "test/fl/InstMTraceSub.v"
`include "fl/fl_vtrace.v"

import TestEnv::*;

module BlimpV11TestHarness #(
  parameter p_opaq_bits              = 8,
  parameter p_seq_num_bits           = 5,
  parameter p_num_phys_regs          = 36,
  parameter p_num_fe_lanes           = 2,
  parameter p_num_be_lanes           = 2,
  parameter p_iq_depth               = 4,
  parameter p_reclaim_width          = p_num_be_lanes,
  parameter p_max_in_flight          = 8,
  parameter p_mem_send_intv_delay    = 1,
  parameter p_mem_recv_intv_delay    = 1,
  parameter p_f_intf_fifo_depth      = 4,
  parameter p_f_intf_fifo_bypass     = 0,
  parameter p_x_intf_fifo_depth      = 4,
  parameter p_x_intf_fifo_bypass     = 0,
  parameter p_alu_d_intf_fifo_depth  = 4,
  parameter p_mul_d_intf_fifo_depth  = 4,
  parameter p_mem_d_intf_fifo_depth  = 4,
  parameter p_mem_d_intf_fifo_bypass = 0,
  parameter p_num_pipes              = 8,
  parameter p_all_iq_in_order        = 0,

  // Simulation-only backpressure parameters (packed: 8 bits per lane/pipe)
  parameter [p_num_fe_lanes*8-1:0] p_sim_f2d_bp = '0,
  parameter [p_num_pipes*8-1:0]    p_sim_d2x_bp = '0,
  parameter [p_num_pipes*8-1:0]    p_sim_x2w_bp = '0
);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  initial t.timeout = 20000;

  `MEM_REQ_DEFINE ( p_opaq_bits );
  `MEM_RESP_DEFINE( p_opaq_bits );

  `MEM_REQ_DEFINE_SS ( p_opaq_bits, p_num_fe_lanes );
  `MEM_RESP_DEFINE_SS( p_opaq_bits, p_num_fe_lanes );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_words (p_num_fe_lanes)
  ) imem_intf();

  MemIntf #(
    .p_opaq_bits (p_opaq_bits)
  ) dmem_intf();

  InstTraceNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) inst_trace_notif[p_num_be_lanes]();

  BlimpV11 #(
    .p_opaq_bits              (p_opaq_bits),
    .p_seq_num_bits           (p_seq_num_bits),
    .p_num_phys_regs          (p_num_phys_regs),
    .p_num_be_lanes           (p_num_be_lanes),
    .p_num_fe_lanes           (p_num_fe_lanes),
    .p_iq_depth               (p_iq_depth),
    .p_reclaim_width          (p_reclaim_width),
    .p_max_in_flight          (p_max_in_flight),
    .p_num_pipes              (p_num_pipes),
    .p_f_intf_fifo_depth      (p_f_intf_fifo_depth),
    .p_f_intf_fifo_bypass     (p_f_intf_fifo_bypass),
    .p_x_intf_fifo_depth      (p_x_intf_fifo_depth),
    .p_x_intf_fifo_bypass     (p_x_intf_fifo_bypass),
    .p_alu_d_intf_fifo_depth  (p_alu_d_intf_fifo_depth),
    .p_mul_d_intf_fifo_depth  (p_mul_d_intf_fifo_depth),
    .p_mem_d_intf_fifo_depth  (p_mem_d_intf_fifo_depth),
    .p_mem_d_intf_fifo_bypass (p_mem_d_intf_fifo_bypass),
    .p_all_iq_in_order        (p_all_iq_in_order),
    .p_sim_f2d_bp             (p_sim_f2d_bp),
    .p_sim_d2x_bp             (p_sim_d2x_bp),
    .p_sim_x2w_bp             (p_sim_x2w_bp)
  ) dut (
    .inst_mem   (imem_intf),
    .data_mem   (dmem_intf),
    .inst_trace (inst_trace_notif),
    .*
  );

  //----------------------------------------------------------------------
  // FL Memory
  //----------------------------------------------------------------------

  MemIntfTestServer #(
    .t_req_msg         (`MEM_REQ_SS ( p_opaq_bits, p_num_fe_lanes )),
    .t_resp_msg        (`MEM_RESP_SS( p_opaq_bits, p_num_fe_lanes )),
    .p_send_intv_delay (p_mem_send_intv_delay),
    .p_recv_intv_delay (p_mem_recv_intv_delay),
    .p_opaq_bits       (p_opaq_bits),
    .p_num_words       (p_num_fe_lanes)
  ) fl_imem (
    .dut (imem_intf),
    .*
  );

  MemIntfTestServer #(
    .t_req_msg         (`MEM_REQ ( p_opaq_bits )),
    .t_resp_msg        (`MEM_RESP( p_opaq_bits )),
    .p_send_intv_delay (p_mem_send_intv_delay),
    .p_recv_intv_delay (p_mem_recv_intv_delay),
    .p_opaq_bits       (p_opaq_bits)
  ) fl_dmem (
    .dut (dmem_intf),
    .*
  );

  logic [31:0] asm_binary;

  task asm(
    input logic [31:0] addr,
    input string       inst
  );
    asm_binary = assemble( inst, addr );
    fl_imem.init_mem( addr, asm_binary );
    fl_init         ( addr, asm_binary );
  endtask

  task data(
    input logic [31:0] addr,
    input logic [31:0] data
  );
    fl_dmem.init_mem( addr, data );
    fl_init         ( addr, data );
  endtask

  //----------------------------------------------------------------------
  // Instruction Tracing
  //----------------------------------------------------------------------

  logic [31:0] inst_trace_notif_pc    [p_num_be_lanes];
  logic  [4:0] inst_trace_notif_waddr [p_num_be_lanes];
  logic [31:0] inst_trace_notif_wdata [p_num_be_lanes];
  logic        inst_trace_notif_wen   [p_num_be_lanes];
  logic        inst_trace_notif_val   [p_num_be_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign inst_trace_notif_pc[i]    = inst_trace_notif[i].pc;
      assign inst_trace_notif_waddr[i] = inst_trace_notif[i].waddr;
      assign inst_trace_notif_wdata[i] = inst_trace_notif[i].wdata;
      assign inst_trace_notif_wen[i]   = inst_trace_notif[i].wen;
      assign inst_trace_notif_val[i]   = inst_trace_notif[i].val;
    end
  endgenerate

  InstMTraceSub #(
    .p_num_lanes (p_num_be_lanes)
  ) inst_trace_sub (
    .pc    (inst_trace_notif_pc),
    .waddr (inst_trace_notif_waddr),
    .wdata (inst_trace_notif_wdata),
    .wen   (inst_trace_notif_wen),
    .val   (inst_trace_notif_val),
    .*
  );

  task check_trace(
    input logic [31:0] pc,
    input logic  [4:0] waddr,
    input logic [31:0] wdata,
    input logic        wen
  );

    inst_trace_sub.check_trace(
      pc,
      waddr,
      wdata,
      wen
    );
  endtask

  logic      check_traces_success;
  inst_trace check_traces_fl_trace;

  task check_traces();
    while( 1 ) begin
      check_traces_success = fl_trace( check_traces_fl_trace );
      if( !check_traces_success ) return;

      inst_trace_sub.check_trace(
        check_traces_fl_trace.pc,
        check_traces_fl_trace.waddr,
        check_traces_fl_trace.wdata,
        check_traces_fl_trace.wen
      );
    end
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    trace = "";

    trace = {trace, fl_imem.trace( t.trace_level )};
    trace = {trace, " || "};
    trace = {trace, fl_dmem.trace( t.trace_level )};
    trace = {trace, " || "};
    trace = {trace, dut.trace( t.trace_level )};
    trace = {trace, " || "};
    trace = {trace, inst_trace_sub.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ
endmodule

`endif // HW_TOP_TEST_BLIMPV11TESTHARNESS_V
