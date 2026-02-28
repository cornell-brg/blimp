//========================================================================
// SeqNumGenL5_test.v
//========================================================================
// A testbench for testing the superscalar sequence number generator

`include "hw/fetch/SeqNumGenL5.v"
`include "intf/CommitNotif.v"
`include "intf/SquashNotif.v"
`include "test/TestUtils.v"
`include "test/fl/TestOstream.v"
`include "test/fl/TestPub.v"
`include "test/fl/TestMPub.v"

import TestEnv::*;

//========================================================================
// SeqNumGenL5TestSuite
//========================================================================
// A test suite for a particular parametrization of the sequence number
// generator

module SeqNumGenL5TestSuite #(
  parameter p_suite_num        = 0,
  parameter p_seq_num_bits     = 5,
  parameter p_reclaim_width    = 2,
  parameter p_alloc_intv_delay = 0,
  parameter p_num_fe_lanes     = 2,
  parameter p_num_be_lanes     = 2
);

  string suite_name = $sformatf("%0d: SeqNumGenL5TestSuite_%0d_%0d_%0d_%0dfe_%0dbe",
                                p_suite_num, p_seq_num_bits,
                                p_reclaim_width, p_alloc_intv_delay,
                                p_num_fe_lanes, p_num_be_lanes);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  // verilator lint_off UNUSED
  logic clk, rst;
  // verilator lint_on UNUSED

  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  localparam p_num_seq_nums = 2 ** p_seq_num_bits;

  logic [p_seq_num_bits-1:0] alloc_seq_num [p_num_fe_lanes];
  logic                      alloc_val     [p_num_fe_lanes];
  logic                      alloc_rdy     [p_num_fe_lanes];

  CommitNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) commit_notif [p_num_be_lanes] ();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_notif();

  SeqNumGenL5 #(
    .p_seq_num_bits  (p_seq_num_bits),
    .p_reclaim_width (p_reclaim_width),
    .p_num_fe_lanes  (p_num_fe_lanes),
    .p_num_be_lanes  (p_num_be_lanes)
  ) dut (
    .commit (commit_notif),
    .squash (squash_notif),
    .*
  );

  //----------------------------------------------------------------------
  // FL Allocator
  //----------------------------------------------------------------------

  typedef struct packed {
    logic [p_seq_num_bits-1:0] seq_num;
  } t_alloc_msg;

  t_alloc_msg alloc_msg [p_num_fe_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin
      assign alloc_msg[i].seq_num = alloc_seq_num[i];
    end
  endgenerate

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: alloc_OStreams
      TestOstream #(
        t_alloc_msg,
        p_alloc_intv_delay
      ) alloc_Ostream (
        .msg (alloc_msg[i]),
        .val (alloc_val[i]),
        .rdy (alloc_rdy[i]),
        .*
      );
    end
  endgenerate

  t_alloc_msg alloc_msgs_to_recv     [p_num_fe_lanes];
  logic       alloc_msgs_to_recv_val [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin
      always @( posedge clk ) begin
        #1;
        if (alloc_msgs_to_recv_val[i]) begin
          alloc_OStreams[i].alloc_Ostream.recv(
            alloc_msgs_to_recv[i]
          );
        end

        // verilator lint_off BLKSEQ
        alloc_msgs_to_recv_val[i] = 1'b0;
        // verilator lint_on BLKSEQ
      end

      initial begin
        alloc_msgs_to_recv_val[i] = 1'b0;
      end
    end
  endgenerate

  t_alloc_msg pipe_msg [p_num_fe_lanes];

  task recv_seq_alloc(
    input logic [p_seq_num_bits-1:0] seq_num [p_num_fe_lanes],
    input logic                      valid   [p_num_fe_lanes]
  );
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      automatic int jj = j;
      fork
        begin
          pipe_msg[jj].seq_num       = seq_num[jj];
          alloc_msgs_to_recv[jj]     = pipe_msg[jj];
          alloc_msgs_to_recv_val[jj] = valid[jj];
          while(alloc_msgs_to_recv_val[jj])
            #1;
        end
      join_none
    end
    wait fork;
  endtask

  //----------------------------------------------------------------------
  // Sequence Number Freer (Commit)
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
  } t_commit_msg;

  t_commit_msg commit_msg     [p_num_be_lanes];
  logic        commit_msg_val [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign commit_notif[i].pc      = commit_msg[i].pc;
      assign commit_notif[i].seq_num = commit_msg[i].seq_num;
      assign commit_notif[i].waddr   = commit_msg[i].waddr;
      assign commit_notif[i].wdata   = commit_msg[i].wdata;
      assign commit_notif[i].wen     = commit_msg[i].wen;
      assign commit_notif[i].val     = commit_msg_val[i];
    end
  endgenerate

  logic                 [31:0] unused_commit_pc    [p_num_be_lanes];
  logic                  [4:0] unused_commit_waddr [p_num_be_lanes];
  logic                 [31:0] unused_commit_wdata [p_num_be_lanes];
  logic                        unused_commit_wen   [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign unused_commit_pc[i]    = commit_notif[i].pc;
      assign unused_commit_waddr[i] = commit_notif[i].waddr;
      assign unused_commit_wdata[i] = commit_notif[i].wdata;
      assign unused_commit_wen[i]   = commit_notif[i].wen;
    end
  endgenerate

  TestMPub #(
    .t_msg      (t_commit_msg),
    .p_num_msgs (p_num_be_lanes)
  ) free_pub (
    .msg (commit_msg),
    .val (commit_msg_val),
    .*
  );

  t_commit_msg msg_to_commit     [p_num_be_lanes];
  logic        msg_to_commit_val [p_num_be_lanes];

  task seq_free(
    input logic [p_seq_num_bits-1:0] seq_num       [p_num_be_lanes],
    input logic                      seq_num_valid [p_num_be_lanes]
  );
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      msg_to_commit[j].seq_num = seq_num[j];
      msg_to_commit[j].pc      = '0;
      msg_to_commit[j].waddr   = '0;
      msg_to_commit[j].wdata   = '0;
      msg_to_commit[j].wen     = '0;
      msg_to_commit_val[j]     = seq_num_valid[j];
    end

    free_pub.pub( msg_to_commit, msg_to_commit_val );
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

  task squash(
    input logic [p_seq_num_bits-1:0] seq_num
  );
    t_squash_msg m;
    m.seq_num = seq_num;
    m.target  = 'x;

    squash_pub.pub( m );
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    trace = "";

    // trace = {trace, alloc_Ostream.trace( t.trace_level )};
    // trace = {trace, " | "};
    // trace = {trace, dut.trace( t.trace_level )};
    // trace = {trace, " | "};
    // trace = {trace, free_pub_0.trace( t.trace_level )};
    // trace = {trace, " "};
    // trace = {trace, free_pub_1.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // check_allocated
  //----------------------------------------------------------------------
  // White-box testing the number of allocated entries

  task check_allocated ( input int num_allocated );
    `CHECK_EQ( int'(dut.entries_allocated), num_allocated );
  endtask

  //----------------------------------------------------------------------
  // Include test cases
  //----------------------------------------------------------------------

  `include "hw/fetch/test/seq_num_test_cases/l5_basic_test_cases.v"
  `include "hw/fetch/test/seq_num_test_cases/l5_squash_test_cases.v"

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    run_basic_test_cases();
    run_squash_test_cases();
  endtask
endmodule

//========================================================================
// SeqNumGenL5_test
//========================================================================

module SeqNumGenL5_test;
  //                     suite  seq   reclm delay fe  be
  //                     num    bits  width       lns lns
  SeqNumGenL5TestSuite #(1, 5, 2, 0, 2, 2) suite_1();
  SeqNumGenL5TestSuite #(2, 6, 2, 0, 1, 1) suite_2();
  SeqNumGenL5TestSuite #(3, 8, 2, 0, 4, 2) suite_3();
  SeqNumGenL5TestSuite #(4, 8, 4, 0, 2, 4) suite_4();
  SeqNumGenL5TestSuite #(5, 8, 4, 0, 4, 4) suite_5();
  // TODO: test when very few sequence numbers are available but many lanes

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();
    if ((s <= 0) || (s == 2)) suite_2.run_test_suite();
    if ((s <= 0) || (s == 3)) suite_3.run_test_suite();
    if ((s <= 0) || (s == 4)) suite_4.run_test_suite();
    if ((s <= 0) || (s == 5)) suite_5.run_test_suite();

    test_bench_end();
  end
endmodule
