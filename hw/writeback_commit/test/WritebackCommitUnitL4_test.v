//========================================================================
// WritebackCommitUnitL4_test.v
//========================================================================
// A testbench for our reordering writeback-commit unit with renaming
// and support for multiple superscalar backend lanes

`include "hw/writeback_commit/writeback_commit_unit_variants/WritebackCommitUnitL4.v"
`include "test/fl/TestMSub.v"
`include "test/fl/TestIstream.v"
`include "intf/CompleteNotif.v"
`include "intf/X__WIntf.v"
`include "test/TestUtils.v"

import TestEnv::*;

//========================================================================
// WritebackCommitUnitL4TestSuite
//========================================================================
// A test suite for the reordering writeback-commit unit

module WritebackCommitUnitL4TestSuite #(
  parameter p_suite_num         = 0,
  parameter p_num_pipes         = 1,
  parameter p_seq_num_bits      = 3,
  parameter p_phys_addr_bits    = 6,
  parameter p_X_send_intv_delay = 0,
  parameter p_num_be_lanes      = 2
);

  //verilator lint_off UNUSEDSIGNAL
  string suite_name = $sformatf("%0d: WritebackCommitUnitL4TestSuite_%0d_%0d_%0d_%0d", 
                                p_suite_num, p_num_pipes, p_seq_num_bits,
                                p_X_send_intv_delay, p_num_be_lanes);
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
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) X__W_intfs [p_num_pipes-1:0]();

  CompleteNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) complete_notif [p_num_be_lanes]();

  CommitNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) commit_notif [p_num_be_lanes]();

  WritebackCommitUnitL4 #(
    .p_num_pipes    (p_num_pipes),
    .p_num_be_lanes (p_num_be_lanes)
  ) dut (
    .Ex        (X__W_intfs),
    .complete  (complete_notif),
    .commit    (commit_notif),
    .*
  );

  //----------------------------------------------------------------------
  // FL X Istreams
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
  } t_x__w_msg;

  t_x__w_msg x__w_msgs[p_num_pipes];

  genvar i;
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin
      assign X__W_intfs[i].pc      = x__w_msgs[i].pc;
      assign X__W_intfs[i].seq_num = x__w_msgs[i].seq_num;
      assign X__W_intfs[i].waddr   = x__w_msgs[i].waddr;
      assign X__W_intfs[i].wdata   = x__w_msgs[i].wdata;
      assign X__W_intfs[i].wen     = x__w_msgs[i].wen;
      assign X__W_intfs[i].preg    = x__w_msgs[i].preg;
      assign X__W_intfs[i].ppreg   = x__w_msgs[i].ppreg;
    end
  endgenerate

  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: X_Istreams
      TestIstream #( t_x__w_msg, p_X_send_intv_delay ) X_Istream (
        .msg (x__w_msgs[i]),
        .val (X__W_intfs[i].val),
        .rdy (X__W_intfs[i].rdy),
        .*
      );
    end
  endgenerate

  t_x__w_msg msgs_to_send     [p_num_pipes];
  logic      msgs_to_send_val [p_num_pipes];

  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin
      always @( posedge clk ) begin
        #1;
        if (msgs_to_send_val[i]) begin
          X_Istreams[i].X_Istream.send(
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

  t_x__w_msg pipe_msg;

  task send(
    // verilator lint_off UNUSEDSIGNAL
    input int                        pipe_num,
    // verilator lint_on UNUSEDSIGNAL

    input logic                 [31:0] pc,
    input logic   [p_seq_num_bits-1:0] seq_num,
    input logic                  [4:0] waddr,
    input logic                 [31:0] wdata,
    input logic                        wen,
    input logic [p_phys_addr_bits-1:0] preg,
    input logic [p_phys_addr_bits-1:0] ppreg
  );
    pipe_msg.pc      = pc;
    pipe_msg.seq_num = seq_num;
    pipe_msg.waddr   = waddr;
    pipe_msg.wdata   = wdata;
    pipe_msg.wen     = wen;
    pipe_msg.preg    = preg;
    pipe_msg.ppreg   = ppreg;

    msgs_to_send[pipe_num]     = pipe_msg;
    msgs_to_send_val[pipe_num] = 1'b1;

    wait(msgs_to_send_val[pipe_num] == 1'b0);
  endtask

  //----------------------------------------------------------------------
  // Completion Test Subscriber
  //----------------------------------------------------------------------

  typedef struct packed {
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] preg;
  } t_complete_msg;

  t_complete_msg complete_msg [p_num_be_lanes];
  logic          complete_val [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin
      assign complete_msg[i].seq_num = complete_notif[i].seq_num;
      assign complete_msg[i].waddr   = complete_notif[i].waddr;
      assign complete_msg[i].wdata   = complete_notif[i].wdata;
      assign complete_msg[i].wen     = complete_notif[i].wen;
      assign complete_msg[i].preg    = complete_notif[i].preg;
      assign complete_val[i]         = complete_notif[i].val;
    end
  endgenerate

  TestMSub #(
    .t_msg      (t_complete_msg),
    .p_num_msgs (p_num_be_lanes)
  ) CompleteSub (
    .msg (complete_msg),
    .val (complete_val),
    .*
  );

  t_complete_msg msg_to_complete_sub [p_num_be_lanes];

  task complete_sub(
    input logic   [p_seq_num_bits-1:0] seq_num [p_num_be_lanes],
    input logic                  [4:0] waddr   [p_num_be_lanes],
    input logic                 [31:0] wdata   [p_num_be_lanes],
    input logic                        wen     [p_num_be_lanes],
    input logic [p_phys_addr_bits-1:0] preg    [p_num_be_lanes],
    input logic                        val     [p_num_be_lanes]
  );
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      msg_to_complete_sub[j].seq_num = seq_num[j];
      msg_to_complete_sub[j].waddr   = waddr[j];
      msg_to_complete_sub[j].wdata   = wdata[j];
      msg_to_complete_sub[j].wen     = wen[j];
      msg_to_complete_sub[j].preg    = preg[j];
    end

    CompleteSub.sub( msg_to_complete_sub, val );
  endtask

  //----------------------------------------------------------------------
  // Commit Test Subscriber
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] ppreg;
  } t_commit_msg;

  t_commit_msg commit_msg [p_num_be_lanes];
  logic        commit_val [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin
      assign commit_msg[i].pc      = commit_notif[i].pc;
      assign commit_msg[i].seq_num = commit_notif[i].seq_num;
      assign commit_msg[i].waddr   = commit_notif[i].waddr;
      assign commit_msg[i].wdata   = commit_notif[i].wdata;
      assign commit_msg[i].wen     = commit_notif[i].wen;
      assign commit_msg[i].ppreg   = commit_notif[i].ppreg;
      assign commit_val[i]         = commit_notif[i].val;
    end
  endgenerate

  TestMSub #(
    .t_msg      (t_commit_msg),
    .p_num_msgs (p_num_be_lanes)
  ) CommitSub (
    .msg (commit_msg),
    .val (commit_val),
    .*
  );

  t_commit_msg msg_to_commit_sub [p_num_be_lanes];

  task commit_sub(
    input logic                 [31:0] pc      [p_num_be_lanes],
    input logic   [p_seq_num_bits-1:0] seq_num [p_num_be_lanes],
    input logic                  [4:0] waddr   [p_num_be_lanes],
    input logic                 [31:0] wdata   [p_num_be_lanes],
    input logic                        wen     [p_num_be_lanes],
    input logic [p_phys_addr_bits-1:0] ppreg   [p_num_be_lanes],
    input logic                        val     [p_num_be_lanes]
  );
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      msg_to_commit_sub[j].pc      = pc[j];
      msg_to_commit_sub[j].seq_num = seq_num[j];
      msg_to_commit_sub[j].waddr   = waddr[j];
      msg_to_commit_sub[j].wdata   = wdata[j];
      msg_to_commit_sub[j].wen     = wen[j];
      msg_to_commit_sub[j].ppreg   = ppreg[j];
    end

    CommitSub.sub( msg_to_commit_sub, val );
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  // string X_traces [p_num_pipes-1:0];
  // generate
  //   for( i = 0; i < p_num_pipes; i = i + 1 ) begin
  //     // verilator lint_off BLKSEQ
  //     always @( posedge clk ) begin
  //       #2;
  //       X_traces[i] = X_Istreams[i].X_Istream.trace( t.trace_level );
  //     end
  //     // verilator lint_on BLKSEQ
  //   end
  // endgenerate

  // Need to store other traces, to be aligned with X_Istream traces
  // string trace;
  // // string dut_trace;
  // string CompleteSub_trace;
  // string CommitSub_trace;

  // // verilator lint_off BLKSEQ
  // always @( posedge clk ) begin
  //   #2;
  //   // dut_trace         = dut.trace( t.trace_level );
  //   CompleteSub_trace = CompleteSub.trace( t.trace_level );
  //   CommitSub_trace   = CommitSub.trace( t.trace_level );

  //   // Wait until X_Istream traces are ready
  //   #1;
  //   trace = "";

  //   for( int j = 0; j < p_num_pipes; j++ ) begin
  //     if( j > 0 )
  //       trace = {trace, " "};
  //     trace = {trace, X_traces[j]};
  //   end
  //   // trace = {trace, " | "};
  //   // trace = {trace, dut_trace};
  //   trace = {trace, " | "};
  //   trace = {trace, CompleteSub_trace};
  //   trace = {trace, " - "};
  //   trace = {trace, CommitSub_trace};
    
  //   t.trace( trace );
  // end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Include test cases
  //----------------------------------------------------------------------

  `include "hw/writeback_commit/test/test_cases/multi_test_cases.v"

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    run_multi_test_cases();
  endtask
endmodule

//========================================================================
// WritebackCommitUnitL1_test
//========================================================================

module WritebackCommitUnitL4_test;
  WritebackCommitUnitL4TestSuite #(1, 2) suite_1();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();

    test_bench_end();
  end
endmodule

