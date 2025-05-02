//========================================================================
// SquashUnitL1_test.v
//========================================================================
// A testbench for our squash unit

`include "hw/squash/SquashUnitL1.v"
`include "intf/CommitNotif.v"
`include "intf/SquashNotif.v"
`include "test/fl/TestPub.v"
`include "test/fl/TestSub.v"
`include "test/TestUtils.v"

import TestEnv::*;

//========================================================================
// SquashUnitL1TestSuite
//========================================================================
// A test suite for the squash unit

module SquashUnitL1TestSuite #(
  parameter p_suite_num    = 0,
  parameter p_num_arb      = 2,
  parameter p_seq_num_bits = 5
);

  //verilator lint_off UNUSEDSIGNAL
  string suite_name = $sformatf("%0d: SquashUnitL1TestSuite_%0d_%0d", 
                                p_suite_num, p_num_arb, p_seq_num_bits);
  //verilator lint_on UNUSEDSIGNAL

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_arb [p_num_arb]();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_gnt ();

  CommitNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) commit_notif ();

  SquashUnitL1 #(
    .p_num_arb      (p_num_arb),
    .p_seq_num_bits (p_seq_num_bits)
  ) dut (
    .arb    (squash_arb),
    .gnt    (squash_gnt),
    .commit (commit_notif),
    .*
  );

  //----------------------------------------------------------------------
  // Arbitraters
  //----------------------------------------------------------------------

  typedef struct packed {
    logic [p_seq_num_bits-1:0] seq_num;
    logic               [31:0] target;
  } t_squash_msg;

  t_squash_msg squash_arb_msgs[p_num_arb];

  genvar i;
  generate
    for( i = 0; i < p_num_arb; i = i + 1 ) begin
      assign squash_arb[i].seq_num = squash_arb_msgs[i].seq_num;
      assign squash_arb[i].target  = squash_arb_msgs[i].target;
    end
  endgenerate

  generate
    for( i = 0; i < p_num_arb; i = i + 1 ) begin: squash_arb_pubs
      TestPub #( t_squash_msg ) squash_arb_pub (
        .msg (squash_arb_msgs[i]),
        .val (squash_arb[i].val),
        .*
      );
    end
  endgenerate

  t_squash_msg msgs_to_send     [p_num_arb];
  logic        msgs_to_send_val [p_num_arb];

  generate
    for( i = 0; i < p_num_arb; i = i + 1 ) begin
      always @( posedge clk ) begin
        #1;
        if (msgs_to_send_val[i]) begin
          squash_arb_pubs[i].squash_arb_pub.pub(
            msgs_to_send[i]
          );
        end
        
        // verilator lint_off BLKSEQ
        msgs_to_send_val[i] = 1'b0;
        // verilator lint_on BLKSEQ
      end

      initial begin
        msgs_to_send_val[i] = 1'b0;
      end
    end
  endgenerate

  t_squash_msg squash_msg;

  task pub(
    // verilator lint_off UNUSEDSIGNAL
    input int                        arb_num,
    // verilator lint_on UNUSEDSIGNAL

    input logic [p_seq_num_bits-1:0] seq_num,
    input logic               [31:0] target
  );
    squash_msg.seq_num = seq_num;
    squash_msg.target  = target;

    msgs_to_send[arb_num]     = squash_msg;
    msgs_to_send_val[arb_num] = 1'b1;

    wait(msgs_to_send_val[arb_num] == 1'b0);
  endtask

  //----------------------------------------------------------------------
  // Granted squash
  //----------------------------------------------------------------------

  t_squash_msg gnt_squash_msg;

  assign gnt_squash_msg.seq_num = squash_gnt.seq_num;
  assign gnt_squash_msg.target  = squash_gnt.target;

  TestSub #( t_squash_msg ) squash_gnt_sub (
    .msg (gnt_squash_msg),
    .val (squash_gnt.val),
    .*
  );

  t_squash_msg msg_to_sub;

  task sub (
    input logic [p_seq_num_bits-1:0] seq_num,
    input logic               [31:0] target
  );
    msg_to_sub.seq_num = seq_num;
    msg_to_sub.target  = target;

    squash_gnt_sub.sub( msg_to_sub );
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
  // Linetracing
  //----------------------------------------------------------------------

  string arb_traces [p_num_arb-1:0];
  generate
    for( i = 0; i < p_num_arb; i = i + 1 ) begin
      // verilator lint_off BLKSEQ
      always @( posedge clk ) begin
        #2;
        arb_traces[i] = squash_arb_pubs[i].squash_arb_pub.trace( t.trace_level );
      end
      // verilator lint_on BLKSEQ
    end
  endgenerate

  // Need to store other traces, to be aligned with X_Istream traces
  string trace;
  string dut_trace;
  string gnt_trace;
  string commit_trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    dut_trace    = dut.trace( t.trace_level );
    gnt_trace    = squash_gnt_sub.trace( t.trace_level );
    commit_trace = commit_pub.trace( t.trace_level );

    // Wait until X_Istream traces are ready
    #1;
    trace = "";

    for( int j = 0; j < p_num_arb; j++ ) begin
      if( j > 0 )
        trace = {trace, " "};
      trace = {trace, arb_traces[j]};
    end
    trace = {trace, " | "};
    trace = {trace, dut_trace};
    trace = {trace, " | "};
    trace = {trace, gnt_trace};
    trace = {trace, " | "};
    trace = {trace, commit_trace};
    
    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // test_case_1_basic
  //----------------------------------------------------------------------

  logic [p_seq_num_bits-1:0] basic_rand_seq_num;
  logic               [31:0] basic_rand_target;

  task test_case_1_basic();
    t.test_case_begin( "test_case_1_basic" );
    if( !t.run_test ) return;

    for( int i = 0; i < p_num_arb; i = i + 1 ) begin
      basic_rand_seq_num = p_seq_num_bits'($urandom());
      basic_rand_target  =             32'($urandom());
      // Give a valid squash to the ith arbiter
      fork
        pub( i, basic_rand_seq_num, basic_rand_target );
        sub(    basic_rand_seq_num, basic_rand_target );
      join
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_2_random
  //----------------------------------------------------------------------

  // logic [p_seq_num_bits-1:0] exp_seq_num;
  // logic               [31:0] exp_target;
  // logic                      exp_val;

  // // Use a SeqAge to tell the intended target
  // SeqAge #(
  //   .p_seq_num_bits (p_seq_num_bits)
  // ) seq_age (
  //   .commit (commit_notif),
  //   .*
  // );

  // task test_case_2_random();
  //   t.test_case_begin( "test_case_2_random" );
  //   if( !t.run_test ) return;

  //   for( int i = 0; i < 30; i = i + 1 ) begin
  //     commit( p_seq_num_bits'( $urandom() ) );
  //     exp_val = 1'b0;

  //     for( int j = 0; j < p_num_arb; j = j + 1 ) begin
  //       // Use automatic to keep track across loops
  //       automatic int                        k            = j;
  //       automatic logic               [31:0] rand_target  =             32'( $urandom() );
  //       automatic logic                      rand_val     =              1'( $urandom() );

  //       automatic logic [p_seq_num_bits-1:0] rand_seq_num;

  //       do begin
  //         rand_seq_num = p_seq_num_bits'( $urandom() );
  //       end while( rand_seq_num == exp_seq_num ); // Don't have ties

  //       if( rand_val ) begin
  //         fork
  //           pub( k, rand_seq_num, rand_target );
  //         join_none

  //         if( !exp_val ) begin
  //           exp_seq_num = rand_seq_num;
  //           exp_target  = rand_target;
  //           exp_val     = 1'b1;
  //         end else begin
  //           // Only expect it if it's older
  //           if( seq_age.is_older( rand_seq_num, exp_seq_num ) ) begin
  //             exp_seq_num = rand_seq_num;
  //             exp_target  = rand_target;
  //           end
  //         end
  //       end
  //     end

  //     if( exp_val ) begin
  //       fork
  //         sub( exp_seq_num, exp_target );
  //       join_none
  //     end
  //     wait fork;
  //   end

  //   t.test_case_end();
  // endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_1_basic();
    // test_case_2_random();
  endtask
endmodule

//========================================================================
// SquashUnitL1_test
//========================================================================

module SquashUnitL1_test;
  SquashUnitL1TestSuite #(1)        suite_1();
  SquashUnitL1TestSuite #(2,  4, 5) suite_2();
  SquashUnitL1TestSuite #(3,  1, 3) suite_3();
  SquashUnitL1TestSuite #(4,  8, 4) suite_4();
  SquashUnitL1TestSuite #(5,  5, 6) suite_5();
  SquashUnitL1TestSuite #(5, 20, 6) suite_6();

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
