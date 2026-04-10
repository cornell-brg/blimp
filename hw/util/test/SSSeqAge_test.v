//========================================================================
// SSSeqAge_test.v
//========================================================================
// A testbench for our multi-commit sequence number age logic

`include "test/TestUtils.v"
`include "hw/util/SSSeqAge.v"
`include "intf/CommitNotif.v"
`include "test/fl/TestMPub.v"

import TestEnv::*;

//========================================================================
// SSSeqAgeTestSuite
//========================================================================
// A test suite for a particular parametrization of the age logic

module SSSeqAgeTestSuite #(
  parameter p_suite_num    = 0,
  parameter p_seq_num_bits = 5,
  parameter p_num_be_lanes = 2,
  parameter p_num_phys_regs = 36
);

  string suite_name = $sformatf("%0d: MSeqNumAgeIntfTestSuite_%0d",
                                p_suite_num, p_seq_num_bits);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;

  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  CommitNotif #( 
    .p_seq_num_bits (p_seq_num_bits)
  ) commit_notif [p_num_be_lanes] ();

  logic [p_seq_num_bits-1:0] oldest_seq_num;

  SSSeqAge #(
    .p_num_be_lanes  (p_num_be_lanes),
    .p_seq_num_bits  (p_seq_num_bits),
    .p_num_phys_regs (p_num_phys_regs)
  ) dut(
    .commit (commit_notif),
    .*
  );

  logic [31:0] unused_commit_pc    [p_num_be_lanes];
  logic  [4:0] unused_commid_waddr [p_num_be_lanes];
  logic [31:0] unused_commit_wdata [p_num_be_lanes];
  logic        unused_commit_wen   [p_num_be_lanes];

  genvar i;
  for( i = 0; i < p_num_be_lanes; i++ ) begin
    assign unused_commit_pc[i]    = commit_notif[i].pc;
    assign unused_commid_waddr[i] = commit_notif[i].waddr;
    assign unused_commit_wdata[i] = commit_notif[i].wdata;
    assign unused_commit_wen[i]   = commit_notif[i].wen;
  end

  //----------------------------------------------------------------------
  // commit
  //----------------------------------------------------------------------
  // Commit an instruction with a given sequence number

  typedef struct packed {
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
    logic                [4:0] waddr;
    logic               [31:0] wdata;
    logic                      wen;
  } t_commit_msg;

  t_commit_msg commit_msg     [p_num_be_lanes];
  logic        commit_msg_val [p_num_be_lanes];

  for( i = 0; i < p_num_be_lanes; i++) begin
    assign commit_notif[i].pc      = commit_msg[i].pc;
    assign commit_notif[i].seq_num = commit_msg[i].seq_num;
    assign commit_notif[i].waddr   = commit_msg[i].waddr;
    assign commit_notif[i].wdata   = commit_msg[i].wdata;
    assign commit_notif[i].wen     = commit_msg[i].wen;
    assign commit_notif[i].val     = commit_msg_val[i];
  end
  
  TestMPub #(
    .t_msg    (t_commit_msg),
    .num_msgs (p_num_be_lanes)
  ) CommitMPub (
    .msg (commit_msg),
    .val (commit_msg_val),
    .*
  );

  t_commit_msg msg_to_pub     [p_num_be_lanes];
  logic        msg_to_pub_val [p_num_be_lanes];

  task commit (
    input logic [p_seq_num_bits-1:0] seq_nums [p_num_be_lanes],
    input logic                      val      [p_num_be_lanes]
  );
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      msg_to_pub[j].pc      = 32'( $urandom() );
      msg_to_pub[j].waddr   =  5'( $urandom() );
      msg_to_pub[j].wdata   = 32'( $urandom() );
      msg_to_pub[j].wen     =  1'( $urandom() );
      msg_to_pub[j].seq_num = seq_nums[j];
      msg_to_pub_val[j]     = val[j];
    end
    CommitMPub.pub(msg_to_pub, msg_to_pub_val);
  endtask

  //----------------------------------------------------------------------
  // check
  //----------------------------------------------------------------------
  // All tasks start at #1 after the rising edge of the clock. So we
  // write the inputs #1 after the rising edge, and check the outputs #1
  // before the next rising edge.

  logic dut_is_older;

  task check (
    input logic [p_seq_num_bits-1:0] seq_num_0,
    input logic [p_seq_num_bits-1:0] seq_num_1,
    input logic                      is_older
  );
    if ( !t.failed ) begin
      #8;
      
      dut_is_older = dut.is_older( seq_num_0, seq_num_1 );

      if ( t.verbose ) begin
        $display( "%3d: (%h) %h %h > %b", t.cycles,
                  dut.oldest_seq_num, seq_num_0, seq_num_1, dut_is_older );
      end

      `CHECK_EQ( dut_is_older, is_older );

      #2;

    end
  endtask

  //----------------------------------------------------------------------
  // test_case_1_basic
  //----------------------------------------------------------------------

  task test_case_1_basic();
    t.test_case_begin( "test_case_1_basic" );
    if( !t.run_test ) return;

    //     seq_num_0 seq_num_1 is_older
    check( 1,        2,        1 );
    check( 2,        1,        0 );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_2_lesser_tail
  //----------------------------------------------------------------------

  task test_case_2_lesser_tail();
    t.test_case_begin( "test_case_2_lesser_tail" );
    if( !t.run_test ) return;

    //     seq_num_0 seq_num_1 is_older
    check( 2,        3,        1 );
    check( 3,        2,        0 );

    commit( '{0, 1}, '{1, 1} ); // Tail is now 2

    //     seq_num_0 seq_num_1 is_older
    check( 2,        3,        1 );
    check( 3,        2,        0 );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_3_greater_tail
  //----------------------------------------------------------------------

  task test_case_3_greater_tail();
    t.test_case_begin( "test_case_3_greater_tail" );
    if( !t.run_test ) return;

    commit( '{0, 1}, '{1, 1} ); // Tail is now 2

    //     seq_num_0 seq_num_1 is_older
    check( 0,        1,        1 );
    check( 1,        0,        0 );

    commit( '{2, 3}, '{1, 0} ); // Tail is now 3

    //     seq_num_0 seq_num_1 is_older
    check( 1,        2,        1 );
    check( 2,        1,        0 );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_4_middle_tail
  //----------------------------------------------------------------------

  task test_case_4_middle_tail();
    t.test_case_begin( "test_case_4_middle_tail" );
    if( !t.run_test ) return;

    commit( '{0, 1}, '{1, 0} ); // Tail is now 1

    //     seq_num_0 seq_num_1 is_older
    check( 0,        2,        0 );
    check( 2,        0,        1 );

    commit( '{0, 1}, '{1, 1} ); // Tail is now 2

    //     seq_num_0 seq_num_1 is_older
    check( 1,        3,        0 );
    check( 3,        1,        1 );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_5_same_tail
  //----------------------------------------------------------------------

  task test_case_5_same_tail();
    t.test_case_begin( "test_case_5_same_tail" );
    if( !t.run_test ) return;

    commit( '{0, 1}, '{1, 0} ); // Tail is now 1

    //     seq_num_0 seq_num_1 is_older
    check( 1,        2,        1 );
    check( 2,        1,        0 );
    check( 1,        0,        1 );
    check( 0,        1,        0 );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_6_random
  //----------------------------------------------------------------------

  // logic [p_seq_num_bits-1:0] rand_seq_num_0;
  // logic [p_seq_num_bits-1:0] rand_seq_num_1;
  // logic [p_seq_num_bits-1:0] rand_oldest_seq_num;
  // logic                      exp_is_older;

  // longint rand_seq_num_0_adj;
  // longint rand_seq_num_1_adj;

  // task test_case_6_random();
  //   t.test_case_begin( "test_case_6_random" );
  //   if( !t.run_test ) return;

  //   for( int i = 0; i < 30; i++ ) begin
  //     do begin
  //       rand_seq_num_0 = p_seq_num_bits'( $urandom() );
  //       rand_seq_num_1 = p_seq_num_bits'( $urandom() );
  //     end while( rand_seq_num_0 == rand_seq_num_1 );
  //     rand_oldest_seq_num = p_seq_num_bits'( $urandom() );

  //     rand_seq_num_0_adj = longint'(rand_seq_num_0);
  //     rand_seq_num_1_adj = longint'(rand_seq_num_1);

  //     if( rand_seq_num_0_adj < longint'(rand_oldest_seq_num) )
  //       rand_seq_num_0_adj = rand_seq_num_0_adj + ( 2 ** p_seq_num_bits );
  //     if( rand_seq_num_1_adj < longint'(rand_oldest_seq_num) )
  //       rand_seq_num_1_adj = rand_seq_num_1_adj + ( 2 ** p_seq_num_bits );

  //     exp_is_older = ( rand_seq_num_0_adj < rand_seq_num_1_adj );

  //     commit( rand_oldest_seq_num - 1 ); // Tail is now rand_oldest_seq_num
  //     check( rand_seq_num_0, rand_seq_num_1, exp_is_older );
  //   end

  //   t.test_case_end();
  // endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_1_basic();
    test_case_2_lesser_tail();
    test_case_3_greater_tail();
    test_case_4_middle_tail();
    test_case_5_same_tail();
    // test_case_6_random();
  endtask
endmodule

//========================================================================
// SSSeqAge_test
//========================================================================

module SSSeqAge_test;
  SSSeqAgeTestSuite #(1)     suite_1();
  SSSeqAgeTestSuite #(2,  6) suite_2();
  SSSeqAgeTestSuite #(3,  8) suite_3();
  SSSeqAgeTestSuite #(4, 32) suite_4();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();
    if ((s <= 0) || (s == 2)) suite_2.run_test_suite();
    if ((s <= 0) || (s == 3)) suite_3.run_test_suite();
    if ((s <= 0) || (s == 4)) suite_4.run_test_suite();

    test_bench_end();
  end
endmodule
