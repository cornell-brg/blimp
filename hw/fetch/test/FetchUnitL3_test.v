//========================================================================
// FetchUintL3_test.v
//========================================================================
// A testbench for our fetch unit

`include "hw/fetch/fetch_unit_variants/FetchUnitL3.v"
`include "intf/F__DIntf.v"
`include "intf/MemIntf.v"
`include "intf/SquashNotif.v"
`include "test/fl/MemIntfTestServer.v"
`include "test/fl/TestOstream.v"
`include "test/fl/TestPub.v"

import TestEnv::*;

//========================================================================
// FetchUnitL3TestSuite
//========================================================================
// A test suite for a particular parametrization of the Fetch unit

module FetchUnitL3TestSuite #(
  parameter p_suite_num     = 0,
  parameter p_opaq_bits     = 8,
  parameter p_seq_num_bits  = 5,
  parameter p_max_in_flight = 16,

  parameter p_mem_send_intv_delay = 1,
  parameter p_mem_recv_intv_delay = 1,
  parameter p_D_recv_intv_delay   = 0
);
  string suite_name = $sformatf("%0d: FetchUnitL3TestSuite_%0d_%0d_%0d_%0d_%0d_%0d", 
                                p_suite_num, p_opaq_bits, p_seq_num_bits, p_max_in_flight,
                                p_mem_send_intv_delay, p_mem_recv_intv_delay,
                                p_D_recv_intv_delay);

  localparam p_num_seq_nums = 2 ** p_seq_num_bits;

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  `MEM_REQ_DEFINE ( p_opaq_bits );
  `MEM_RESP_DEFINE( p_opaq_bits );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits)
  ) mem_intf();

  F__DIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) F__D_intf();

  CommitNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) commit_notif();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_notif();

  FetchUnitL3 #(
    .p_seq_num_bits  (p_seq_num_bits),
    .p_max_in_flight (p_max_in_flight)
  ) dut (
    .mem    (mem_intf),
    .D      (F__D_intf),
    .commit (commit_notif),
    .squash (squash_notif),
    .*
  );

  //----------------------------------------------------------------------
  // FL Memory
  //----------------------------------------------------------------------

  MemIntfTestServer #(
    .t_req_msg         (`MEM_REQ ( p_opaq_bits )),
    .t_resp_msg        (`MEM_RESP( p_opaq_bits )),
    .p_send_intv_delay (p_mem_send_intv_delay),
    .p_recv_intv_delay (p_mem_recv_intv_delay),
    .p_opaq_bits       (p_opaq_bits)
  ) fl_mem (
    .dut (mem_intf),
    .*
  );

  //----------------------------------------------------------------------
  // FL D Ostream
  //----------------------------------------------------------------------

  typedef struct packed {
    logic               [31:0] inst;
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
  } t_f__d_msg;

  t_f__d_msg f__d_msg;

  assign f__d_msg.inst    = F__D_intf.inst;
  assign f__d_msg.pc      = F__D_intf.pc;
  assign f__d_msg.seq_num = F__D_intf.seq_num;

  TestOstream #( t_f__d_msg, p_D_recv_intv_delay ) D_Ostream (
    .msg (f__d_msg),
    .val (F__D_intf.val),
    .rdy (F__D_intf.rdy),
    .*
  );

  t_f__d_msg msg_to_recv;

  task recv(
    input logic               [31:0] inst,
    input logic               [31:0] pc,
    input logic [p_seq_num_bits-1:0] seq_num
  );
    msg_to_recv.inst    = inst;
    msg_to_recv.pc      = pc;
    msg_to_recv.seq_num = seq_num;

    D_Ostream.recv(msg_to_recv);
  endtask

  //----------------------------------------------------------------------
  // Commit Notification
  //----------------------------------------------------------------------

  typedef struct packed {
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
    logic                [4:0] waddr;
    logic               [31:0] wdata;
    logic                      wen;
  } t_commit_msg;

  t_commit_msg commit_msg;

  assign commit_notif.pc      = commit_msg.pc;
  assign commit_notif.seq_num = commit_msg.seq_num;
  assign commit_notif.waddr   = commit_msg.waddr;
  assign commit_notif.wdata   = commit_msg.wdata;
  assign commit_notif.wen     = commit_msg.wen;

  TestPub #( t_commit_msg ) commit_pub (
    .msg (commit_msg),
    .val (commit_notif.val),
    .*
  );

  t_commit_msg msg_to_commit;

  task commit(
    input logic [p_seq_num_bits-1:0] seq_num
  );
    msg_to_commit.seq_num = seq_num;
    msg_to_commit.pc      = 32'( $urandom() );
    msg_to_commit.waddr   =  5'( $urandom() );
    msg_to_commit.wdata   = 32'( $urandom() );
    msg_to_commit.wen     =  1'( $urandom() );

    commit_pub.pub( msg_to_commit );
  endtask

  //----------------------------------------------------------------------
  // Squash Notification
  //----------------------------------------------------------------------

  typedef struct packed {
    logic [p_seq_num_bits-1:0] seq_num;
    logic               [31:0] target;
  } t_squash_msg;

  t_squash_msg squash_msg;

  assign squash_notif.seq_num = squash_msg.seq_num;
  assign squash_notif.target  = squash_msg.target;

  TestPub #( t_squash_msg ) squash_pub (
    .msg (squash_msg),
    .val (squash_notif.val),
    .*
  );

  t_squash_msg msg_to_squash;

  task squash(
    input logic [p_seq_num_bits-1:0] seq_num,
    input logic               [31:0] target
  );
    msg_to_squash.seq_num = seq_num;
    msg_to_squash.target  = target;

    squash_pub.pub( msg_to_squash );
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
    trace = {trace, " | "};
    trace = {trace, dut.trace( t.trace_level )};
    trace = {trace, " | "};
    trace = {trace, D_Ostream.trace( t.trace_level )};
    trace = {trace, " - "};
    trace = {trace, commit_pub.trace( t.trace_level )};
    trace = {trace, " - "};
    trace = {trace, squash_pub.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Include test cases
  //----------------------------------------------------------------------

  `include "hw/fetch/test/test_cases/basic_test_cases.v"
  `include "hw/fetch/test/test_cases/seq_num_test_cases.v"
  `include "hw/fetch/test/test_cases/squash_test_cases.v"

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    run_basic_test_cases();
    run_seq_num_test_cases();
    run_squash_test_cases();
  endtask
endmodule

//========================================================================
// FetchUnitL1_test
//========================================================================

module FetchUnitL3_test;
  FetchUnitL3TestSuite #(1)                    suite_1();
  FetchUnitL3TestSuite #(2, 8, 5, 32, 0, 0, 0) suite_2();
  FetchUnitL3TestSuite #(3, 1, 2,  8, 0, 0, 0) suite_3();
  FetchUnitL3TestSuite #(4, 8, 3,  4, 3, 0, 0) suite_4();
  FetchUnitL3TestSuite #(5, 8, 4, 64, 0, 3, 0) suite_5();
  FetchUnitL3TestSuite #(6, 8, 2,  1, 0, 0, 3) suite_6();
  FetchUnitL3TestSuite #(7, 4, 3, 16, 3, 3, 3) suite_7();
  FetchUnitL3TestSuite #(8, 1, 4, 16, 9, 9, 9) suite_8();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();
    if ((s <= 0) || (s == 2)) suite_2.run_test_suite();
    if ((s <= 0) || (s == 3)) suite_3.run_test_suite();
    if ((s <= 0) || (s == 4)) suite_4.run_test_suite();
    if ((s <= 0) || (s == 5)) suite_5.run_test_suite();
    if ((s <= 0) || (s == 6)) suite_6.run_test_suite();
    if ((s <= 0) || (s == 7)) suite_7.run_test_suite();
    if ((s <= 0) || (s == 8)) suite_8.run_test_suite();

    test_bench_end();
  end
endmodule
