//========================================================================
// WritebackCommitUnitL4_test.v
//========================================================================
// A testbench for our reordering writeback-commit unit with renaming
// and support for multiple superscalar backend lanes

`include "hw/writeback_commit/writeback_commit_unit_variants/WritebackCommitUnitL4.v"
`include "intf/CompleteNotif.v"
`include "intf/X__WIntf.v"
`include "test/TestUtils.v"
`include "test/fl/TestMSource.v"
`include "test/fl/TestMSink.v"

import TestEnv::*;

//========================================================================
// WritebackCommitUnitL4TestSuite
//========================================================================
// A test suite for the reordering writeback-commit unit

module WritebackCommitUnitL4TestSuite #(
  parameter p_suite_num         = 0,
  parameter p_num_pipes         = 1,
  parameter p_seq_num_bits      = 5,
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
  // ) X__W_intfs [p_num_pipes-1:0]();
  ) X__W_intfs [p_num_pipes]();

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
  // X-Pipe Test M Source
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

  logic      x__w_val [p_num_pipes];
  logic      x__w_rdy [p_num_pipes];
  t_x__w_msg x__w_msg [p_num_pipes];

  genvar i;
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin
      assign X__W_intfs[i].pc      = x__w_msg[i].pc;
      assign X__W_intfs[i].seq_num = x__w_msg[i].seq_num;
      assign X__W_intfs[i].waddr   = x__w_msg[i].waddr;
      assign X__W_intfs[i].wdata   = x__w_msg[i].wdata;
      assign X__W_intfs[i].wen     = x__w_msg[i].wen;
      assign X__W_intfs[i].preg    = x__w_msg[i].preg;
      assign X__W_intfs[i].ppreg   = x__w_msg[i].ppreg;
      assign X__W_intfs[i].val     = x__w_val[i];
      assign x__w_rdy[i]           = X__W_intfs[i].rdy;
    end
  endgenerate

  logic go;
  logic x_done;

  TestMSource #(
    .t_msg      (t_x__w_msg),
    .p_num_srcs (p_num_pipes),
    .p_seq_len  (500)
  ) x_src (
    .clk  (clk),
    .go   (go),

    .val  (x__w_val),
    .rdy  (x__w_rdy),
    .msg  (x__w_msg),

    .done (x_done)
  );

  t_x__w_msg pipe_msg [p_num_pipes];

  task enq_send(
    input logic                 [31:0] pc      [p_num_pipes],
    input logic   [p_seq_num_bits-1:0] seq_num [p_num_pipes],
    input logic                  [4:0] waddr   [p_num_pipes],
    input logic                 [31:0] wdata   [p_num_pipes],
    input logic                        wen     [p_num_pipes],
    input logic [p_phys_addr_bits-1:0] preg    [p_num_pipes],
    input logic [p_phys_addr_bits-1:0] ppreg   [p_num_pipes],
    input logic                        val     [p_num_pipes]
  );
    for( int i = 0; i < p_num_pipes; i++ ) begin
      pipe_msg[i].pc      = pc[i];
      pipe_msg[i].seq_num = seq_num[i];
      pipe_msg[i].waddr   = waddr[i];
      pipe_msg[i].wdata   = wdata[i];
      pipe_msg[i].wen     = wen[i];
      pipe_msg[i].preg    = preg[i];
      pipe_msg[i].ppreg   = ppreg[i];
    end

    x_src.add_send( val, pipe_msg );
  endtask

  //----------------------------------------------------------------------
  // Completion Test M Sink
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
  logic          unused_complete_rdy [p_num_be_lanes];

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

  logic complete_done;

  TestMSink #(
    .p_ordered   (`SINK_UNORDERED),
    .t_msg       (t_complete_msg),
    .p_num_sinks (p_num_be_lanes),
    .p_seq_len   (500)
  ) complete_sink (
    .clk  (clk),
    .go   (go),

    .val  (complete_val),
    .rdy  (unused_complete_rdy),
    .msg  (complete_msg),

    .done (complete_done)
  );

  t_complete_msg msg_to_complete_sub [p_num_be_lanes];

  task enq_complete(
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

    complete_sink.add_exp( val, msg_to_complete_sub );
  endtask

  //----------------------------------------------------------------------
  // Commit Test Sink
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
  logic        unused_commit_rdy [p_num_be_lanes];

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

  logic commit_done;

  TestMSink #(
    .p_ordered   (`SINK_ORDERED),
    .t_msg       (t_commit_msg),
    .p_num_sinks (p_num_be_lanes),
    .p_seq_len   (500)
  ) commit_sink (
    .clk  (clk),
    .go   (go),

    .val  (commit_val),
    .rdy  (unused_commit_rdy),
    .msg  (commit_msg),

    .done (commit_done)
  );

  t_commit_msg msg_to_commit_sub [p_num_be_lanes];

  task enq_commit(
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

    commit_sink.add_exp( val, msg_to_commit_sub );
  endtask

  //----------------------------------------------------------------------
  // run
  //----------------------------------------------------------------------

  task automatic run();
    @( posedge clk )
    #1;

    go = 1'b1;
    wait( x_done && complete_done && commit_done );
    go = 1'b0;

    @( posedge clk )
    #1;
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  // TODO: write line tracing here

  //----------------------------------------------------------------------
  // Include test cases
  //----------------------------------------------------------------------

  `include  "hw/writeback_commit/test/test_cases/superscalar_test_cases.v"

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    run_superscalar_test_cases();
  endtask

endmodule

//========================================================================
// WritebackCommitUnitL4_test
//========================================================================

module WritebackCommitUnitL4_test;
  WritebackCommitUnitL4TestSuite #(1, 2)             suite_1();
  WritebackCommitUnitL4TestSuite #(2, 2, 5, 6, 0, 2) suite_2();
  WritebackCommitUnitL4TestSuite #(3, 4, 5, 6, 0, 3) suite_3();
  WritebackCommitUnitL4TestSuite #(4, 6, 5, 6, 0, 4) suite_4();

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
