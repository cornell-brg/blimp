//========================================================================
// BlimpV8_sp26TestHarness.v
//========================================================================
// A top-level testing harness for Blimp V8_sp26

`ifndef HW_TOP_TEST_BLIMPV8_SP26TESTHARNESS_V
`define HW_TOP_TEST_BLIMPV8_SP26TESTHARNESS_V

`include "asm/assemble.v"
`include "hw/top/BlimpV8_sp26.v"
`include "intf/MemIntf.v"
`include "intf/InstTraceNotif.v"
`include "test/fl/MemIntfTestServer_2Port.v"
`include "test/fl/InstTraceSub.v"
`include "fl/fl_vtrace.v"

import TestEnv::*;

module BlimpV8_sp26TestHarness #(
  parameter p_opaq_bits     = 8,
  parameter p_seq_num_bits  = 5,
  parameter p_num_phys_regs = 36,

  parameter p_mem_send_intv_delay = 1,
  parameter p_mem_recv_intv_delay = 1
);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  initial t.timeout = 80000;

  `MEM_REQ_DEFINE ( p_opaq_bits );
  `MEM_RESP_DEFINE( p_opaq_bits );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits)
  ) mem_intf[2]();

  InstTraceNotif inst_trace_notif();

  logic inst_trace_deq_rdy = 1'b0;
  logic debug               = 1'b0;

  BlimpV8_sp26 #(
    .p_opaq_bits     (p_opaq_bits),
    .p_seq_num_bits  (p_seq_num_bits),
    .p_num_phys_regs (p_num_phys_regs)
  ) dut (
    .inst_mem           (mem_intf[0]),
    .data_mem           (mem_intf[1]),
    .inst_trace         (inst_trace_notif),
    .inst_trace_deq_rdy (inst_trace_deq_rdy),
    .debug              (debug),
    .*
  );

  //----------------------------------------------------------------------
  // FL Memory
  //----------------------------------------------------------------------

  MemIntfTestServer_2Port #(
    .t_req_msg         (`MEM_REQ ( p_opaq_bits )),
    .t_resp_msg        (`MEM_RESP( p_opaq_bits )),
    .p_send_intv_delay (p_mem_send_intv_delay),
    .p_recv_intv_delay (p_mem_recv_intv_delay),
    .p_opaq_bits       (p_opaq_bits)
  ) fl_mem (
    .dut (mem_intf),
    .*
  );

  logic [31:0] asm_binary;

  task asm(
    input logic [31:0] addr,
    input string       inst
  );
    asm_binary = assemble( inst, addr );
    fl_mem.init_mem( addr, asm_binary );
    fl_init        ( addr, asm_binary );
  endtask

  task data(
    input logic [31:0] addr,
    input logic [31:0] data
  );
    fl_mem.init_mem( addr, data );
    fl_init        ( addr, data );
  endtask

  //----------------------------------------------------------------------
  // Debug Mode Helpers
  //----------------------------------------------------------------------

  task set_debug( input logic val );
    debug = val;
  endtask

  task set_inst_trace_deq_rdy( input logic val );
    inst_trace_deq_rdy = val;
  endtask

  task debug_step(
    input logic [31:0] pc,
    input logic  [4:0] waddr,
    input logic [31:0] wdata,
    input logic        wen
  );
    inst_trace_deq_rdy = 1'b0;
    check_trace( pc, waddr, wdata, wen );
    inst_trace_deq_rdy = 1'b1;
    @( posedge clk ); #1;
    inst_trace_deq_rdy = 1'b0;
  endtask

  //----------------------------------------------------------------------
  // Instruction Tracing
  //----------------------------------------------------------------------

  InstTraceSub inst_trace_sub (
    .pc    (inst_trace_notif.pc),
    .waddr (inst_trace_notif.waddr),
    .wdata (inst_trace_notif.wdata),
    .wen   (inst_trace_notif.wen),
    .val   (inst_trace_notif.val),
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

    trace = {trace, fl_mem.trace( t.trace_level )};
    trace = {trace, " || "};
    trace = {trace, dut.trace( t.trace_level )};
    trace = {trace, " || "};
    trace = {trace, inst_trace_sub.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ
endmodule

`endif // HW_TOP_TEST_BLIMPV8_SP26TESTHARNESS_V
