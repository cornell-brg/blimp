//========================================================================
// ExQueue_test.v
//========================================================================
// A testbench for our execute unit buffer

`include "defs/UArch.v"
`include "hw/execute/ExQueue.v"
`include "test/fl/TestIstream.v"
`include "test/fl/TestOstream.v"

import UArch::*;
import TestEnv::*;

//========================================================================
// ExQueueTestSuite
//========================================================================
// A test suite for the ExQueue

module ExQueueTestSuite #(
  parameter p_suite_num    = 0,
  parameter p_seq_num_bits = 5,
  parameter p_depth        = 8,

  parameter p_send_intv_delay = 0,
  parameter p_recv_intv_delay = 0
);

  //verilator lint_off UNUSEDSIGNAL
  string suite_name = $sformatf("%0d: ExQueueTestSuite_%0d_%0d_%0d_%0d", 
                                p_suite_num, p_seq_num_bits, p_depth,
                                p_send_intv_delay, p_recv_intv_delay);
  //verilator lint_on UNUSEDSIGNAL

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  X__WIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) in_intf();

  X__WIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) out_intf();

  ExQueue #(
    .p_seq_num_bits (p_seq_num_bits),
    .p_depth        (p_depth)
  ) dut (
    .in  (in_intf),
    .out (out_intf),
    .*
  );

  //----------------------------------------------------------------------
  // FL Streams
  //----------------------------------------------------------------------

  typedef struct packed {
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
    logic                [4:0] waddr;
    logic               [31:0] wdata;
    logic                      wen;
  } t_x__w_msg;

  t_x__w_msg in_msg;

  assign in_intf.pc      = in_msg.pc;
  assign in_intf.seq_num = in_msg.seq_num;
  assign in_intf.waddr   = in_msg.waddr;
  assign in_intf.wdata   = in_msg.wdata;
  assign in_intf.wen     = in_msg.wen;

  TestIstream #( t_x__w_msg, p_send_intv_delay ) in_Istream (
    .msg (in_msg),
    .val (in_intf.val),
    .rdy (in_intf.rdy),
    .*
  );

  t_x__w_msg msg_to_send;

  task send(
    input logic               [31:0] pc,
    input logic [p_seq_num_bits-1:0] seq_num,
    input logic                [4:0] waddr,
    input logic               [31:0] wdata,
    input logic                      wen
  );
    msg_to_send.pc      = pc;
    msg_to_send.seq_num = seq_num;
    msg_to_send.waddr   = waddr;
    msg_to_send.wdata   = wdata;
    msg_to_send.wen     = wen;

    in_Istream.send(msg_to_send);
  endtask

  t_x__w_msg out_msg;

  assign out_msg.pc      = out_intf.pc;
  assign out_msg.seq_num = out_intf.seq_num;
  assign out_msg.waddr   = out_intf.waddr;
  assign out_msg.wdata   = out_intf.wdata;
  assign out_msg.wen     = out_intf.wen;

  TestOstream #( t_x__w_msg, p_recv_intv_delay ) out_Ostream (
    .msg (out_msg),
    .val (out_intf.val),
    .rdy (out_intf.rdy),
    .*
  );

  t_x__w_msg msg_to_recv;

  task recv(
    input logic               [31:0] pc,
    input logic [p_seq_num_bits-1:0] seq_num,
    input logic                [4:0] waddr,
    input logic               [31:0] wdata,
    input logic                      wen
  );
    msg_to_recv.pc      = pc;
    msg_to_recv.seq_num = seq_num;
    msg_to_recv.waddr   = waddr;
    msg_to_recv.wdata   = wdata;
    msg_to_recv.wen     = wen;

    out_Ostream.recv(msg_to_recv);
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    trace = "";

    trace = {trace, in_Istream.trace( t.trace_level )};
    trace = {trace, " | "};
    trace = {trace, out_Ostream.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // test_case_1_basic
  //----------------------------------------------------------------------

  task test_case_1_basic();
    t.test_case_begin( "test_case_1_basic" );
    if( !t.run_test ) return;

    fork
      //    pc  seq_num waddr wdata wen
      send( '0, '0,     '0,   '0,   '0 );
      recv( '0, '0,     '0,   '0,   '0 );
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_2_delay
  //----------------------------------------------------------------------

  task test_case_2_delay();
    t.test_case_begin( "test_case_2_delay" );
    if( !t.run_test ) return;

    fork
      //    pc  seq_num waddr wdata wen
      begin
        for( int i = 0; i < 6; i++ ) begin
          send( 32'(i), '0,     '0,   '0,   '0 );
        end
      end
      begin
        for( int i = 0; i < 3; i++ ) begin
          @( posedge clk );
          #1;
        end
        for( int i = 0; i < 6; i++ ) begin
          recv( 32'(i), '0,     '0,   '0,   '0 );
        end
      end
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_3_random
  //----------------------------------------------------------------------

  logic               [31:0] rand_pc      [30];
  logic [p_seq_num_bits-1:0] rand_seq_num [30];
  logic                [4:0] rand_waddr   [30];
  logic               [31:0] rand_wdata   [30];
  logic                      rand_wen     [30];

  task test_case_3_random();
    t.test_case_begin( "test_case_3_random" );
    if( !t.run_test ) return;

    // Pre-generate all random values
    for( int i = 0; i < 30; i++ ) begin
      rand_pc[i]      = 32'( $urandom() );
      rand_seq_num[i] = p_seq_num_bits'( $urandom() );
      rand_waddr[i]   = 5'( $urandom() );
      rand_wdata[i]   = 32'( $urandom() );
      rand_wen[i]     = 1'( $urandom() );
    end

    fork
      // Sending
      begin
        for( int i = 0; i < 30; i++ ) begin
          send(
            rand_pc[i],
            rand_seq_num[i],
            rand_waddr[i],
            rand_wdata[i],
            rand_wen[i]
          );
        end
      end

      // Receiving
      begin
        for( int i = 0; i < 30; i++ ) begin
          recv(
            rand_pc[i],
            rand_seq_num[i],
            rand_waddr[i],
            rand_wdata[i],
            rand_wen[i]
          );
        end
      end
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_1_basic();
    test_case_2_delay();
    test_case_3_random();
  endtask

endmodule

//========================================================================
// ExQueue_test
//========================================================================

module ExQueue_test;
  ExQueueTestSuite #(1)              suite_1();
  ExQueueTestSuite #(2, 6,  4, 0, 0) suite_2();
  ExQueueTestSuite #(3, 3,  1, 0, 0) suite_3();
  ExQueueTestSuite #(4, 4,  2, 3, 0) suite_4();
  ExQueueTestSuite #(5, 9, 32, 0, 3) suite_5();
  ExQueueTestSuite #(6, 5,  8, 3, 3) suite_6();

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

    test_bench_end();
  end
endmodule
