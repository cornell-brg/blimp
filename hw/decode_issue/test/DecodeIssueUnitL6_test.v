//========================================================================
// DecodeIssueUnitL6_test.v
//========================================================================
// A testbench for our decode-issue unit with WAW stalling

`include "asm/assemble.v"
`include "defs/UArch.v"
`include "hw/decode_issue/decode_issue_unit_variants/DecodeIssueUnitL6.v"
`include "test/fl/TestPub.v"
`include "test/fl/TestMPub.v"
`include "test/fl/TestSub.v"
`include "test/fl/TestIstream.v"
`include "test/fl/TestOstream.v"

import UArch::*;
import TestEnv::*;

//========================================================================
// DecodeIssueUnitL6TestSuite
//========================================================================
// A test suite for the basic decoder

module DecodeIssueUnitL6TestSuite #(
  parameter p_suite_num     = 0,
  parameter p_num_pipes     = 3,
  parameter p_seq_num_bits  = 5,
  parameter p_num_phys_regs = 36,
  parameter p_num_be_lanes  = 2,

  parameter p_F_send_intv_delay = 0,
  parameter p_X_recv_intv_delay = 0,

  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1}
);

  string suite_name = $sformatf("%0d: DecodeIssueUnitL6TestSuite_%0d_%0d_%0d_%0d_%0d", 
                                p_suite_num, p_num_pipes, p_seq_num_bits, p_num_phys_regs,
                                p_F_send_intv_delay, p_X_recv_intv_delay);

  initial begin
    for( int i = 0; i < p_num_pipes; i = i + 1 ) begin
      suite_name = $sformatf("%s_%h", suite_name, p_pipe_subsets[i]);
    end
  end

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  localparam p_phys_addr_bits = $clog2( p_num_phys_regs );

  F__DIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) F__D_intf();

  D__XIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) D__X_intfs [p_num_pipes-1:0]();

  CompleteNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) complete_notif [p_num_be_lanes] ();

  CommitNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) commit_notif [p_num_be_lanes] ();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_pub_notif();

  SquashNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) squash_sub_notif();

  DecodeIssueUnitL6 #(
    .p_num_pipes     (p_num_pipes),
    .p_num_phys_regs (p_num_phys_regs),
    .p_num_be_lanes  (p_num_be_lanes),
    .p_pipe_subsets  (p_pipe_subsets)
  ) dut (
    .F          (F__D_intf),
    .Ex         (D__X_intfs),
    .complete   (complete_notif),
    .commit     (commit_notif),
    .squash_pub (squash_pub_notif),
    .squash_sub (squash_sub_notif),
    .*
  );

  //----------------------------------------------------------------------
  // FL F Interface
  //----------------------------------------------------------------------

  typedef struct packed {
    logic               [31:0] inst;
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
  } t_f__d_msg;

  t_f__d_msg f__d_msg;

  assign F__D_intf.inst    = f__d_msg.inst;
  assign F__D_intf.pc      = f__d_msg.pc;
  assign F__D_intf.seq_num = f__d_msg.seq_num;

  TestIstream #( t_f__d_msg, p_F_send_intv_delay ) F_Istream (
    .msg (f__d_msg),
    .val (F__D_intf.val),
    .rdy (F__D_intf.rdy),
    .*
  );

  t_f__d_msg msg_to_send;

  task send(
    input logic [31:0]               pc,
    input string                     assembly,
    input logic [p_seq_num_bits-1:0] seq_num
  );
    msg_to_send.inst    = assemble( assembly, pc );
    msg_to_send.pc      = pc;
    msg_to_send.seq_num = seq_num;

    F_Istream.send(msg_to_send);
  endtask

  //----------------------------------------------------------------------
  // FL X Interfaces
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                 [31:0] op1;
    logic                 [31:0] op2;
    logic                  [4:0] waddr;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
    rv_uop                       uop;
  } t_d__x_msg;

  t_d__x_msg d__x_msgs [p_num_pipes];

  genvar i;
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin
      assign d__x_msgs[i].pc      = D__X_intfs[i].pc;
      assign d__x_msgs[i].seq_num = D__X_intfs[i].seq_num;
      assign d__x_msgs[i].op1     = D__X_intfs[i].op1;
      assign d__x_msgs[i].op2     = D__X_intfs[i].op2;
      assign d__x_msgs[i].waddr   = D__X_intfs[i].waddr;
      assign d__x_msgs[i].uop     = D__X_intfs[i].uop;
      assign d__x_msgs[i].preg    = D__X_intfs[i].preg;
      assign d__x_msgs[i].ppreg   = D__X_intfs[i].ppreg;
    end
  endgenerate

  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: X_Ostreams
      TestOstream #( t_d__x_msg, p_X_recv_intv_delay ) X_Ostream (
        .msg (d__x_msgs[i]),
        .val (D__X_intfs[i].val),
        .rdy (D__X_intfs[i].rdy),
        .*
      );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Completion Interface
  //----------------------------------------------------------------------

  typedef struct packed {
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] preg;
  } t_complete_msg;

  t_complete_msg complete_msg     [p_num_be_lanes];
  logic          complete_msg_val [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign complete_notif[i].seq_num = complete_msg[i].seq_num;
      assign complete_notif[i].waddr   = complete_msg[i].waddr;
      assign complete_notif[i].wdata   = complete_msg[i].wdata;
      assign complete_notif[i].wen     = complete_msg[i].wen;
      assign complete_notif[i].preg    = complete_msg[i].preg;
      assign complete_notif[i].val     = complete_msg_val[i];
    end
  endgenerate

  logic [4:0] unused_waddr [p_num_be_lanes];
  generate    
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign unused_waddr[i] = complete_notif[i].waddr;
    end
  endgenerate

  TestMPub #(
    .t_msg    (t_complete_msg),
    .num_msgs (p_num_be_lanes)
  ) complete_pub (
    .msg (complete_msg),
    .val (complete_msg_val),
    .*
  );

  t_complete_msg msg_to_complete_pub     [p_num_be_lanes];
  logic          msg_to_complete_pub_val [p_num_be_lanes];

  task complete(
    input logic   [p_seq_num_bits-1:0] seq_num [p_num_be_lanes],
    input logic                  [4:0] waddr   [p_num_be_lanes],
    input logic                 [31:0] wdata   [p_num_be_lanes],
    input logic                        wen     [p_num_be_lanes],
    input logic [p_phys_addr_bits-1:0] preg    [p_num_be_lanes],
    input logic                        val     [p_num_be_lanes]
  );
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      msg_to_complete_pub[j].seq_num = seq_num[j];
      msg_to_complete_pub[j].waddr   = waddr[j];
      msg_to_complete_pub[j].wdata   = wdata[j];
      msg_to_complete_pub[j].wen     = wen[j];
      msg_to_complete_pub[j].preg    = preg[j];
      msg_to_complete_pub_val[j]     = val[j];
    end

    complete_pub.pub( msg_to_complete_pub, msg_to_complete_pub_val );
  endtask

  //----------------------------------------------------------------------
  // Commit Notification
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] ppreg;
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
      assign commit_notif[i].ppreg   = commit_msg[i].ppreg;
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
    .t_msg    (t_commit_msg),
    .num_msgs (p_num_be_lanes)
  ) commit_pub (
    .msg (commit_msg),
    .val (commit_msg_val),
    .*
  );

  t_commit_msg msg_to_commit_pub     [p_num_be_lanes];
  logic        msg_to_commit_pub_val [p_num_be_lanes];

  task commit(
    input logic                 [31:0] pc      [p_num_be_lanes],
    input logic   [p_seq_num_bits-1:0] seq_num [p_num_be_lanes],
    input logic                  [4:0] waddr   [p_num_be_lanes],
    input logic                 [31:0] wdata   [p_num_be_lanes],
    input logic                        wen     [p_num_be_lanes],
    input logic [p_phys_addr_bits-1:0] ppreg   [p_num_be_lanes],
    input logic                        val     [p_num_be_lanes]
  );
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      msg_to_commit_pub[j].seq_num = seq_num[j];
      msg_to_commit_pub[j].pc      = pc[j];
      msg_to_commit_pub[j].waddr   = waddr[j];
      msg_to_commit_pub[j].wdata   = wdata[j];
      msg_to_commit_pub[j].wen     = wen[j];
      msg_to_commit_pub[j].ppreg   = ppreg[j];
      msg_to_commit_pub_val[j]     = val[j];
    end

    commit_pub.pub( msg_to_commit_pub, msg_to_commit_pub_val );
  endtask

  //----------------------------------------------------------------------
  // Squash Notification
  //----------------------------------------------------------------------

  typedef struct packed {
    logic [p_seq_num_bits-1:0] seq_num;
    logic               [31:0] target;
  } t_squash_msg;

  t_squash_msg squash_pub_msg;

  assign squash_pub_msg.seq_num = squash_pub_notif.seq_num;
  assign squash_pub_msg.target  = squash_pub_notif.target;

  TestSub #( t_squash_msg ) squash_sub (
    .msg (squash_pub_msg),
    .val (squash_pub_notif.val),
    .*
  );

  t_squash_msg msg_from_squash;

  task sub_squash(
    input logic [p_seq_num_bits-1:0] seq_num,
    input logic               [31:0] target
  );
    msg_from_squash.seq_num = seq_num;
    msg_from_squash.target  = target;

    squash_sub.sub( msg_from_squash );
  endtask

  // verilator lint_off UNUSEDSIGNAL
  t_squash_msg squash_sub_msg;
  // verilator lint_on UNUSEDSIGNAL

  assign squash_sub_notif.seq_num = squash_pub_msg.seq_num;
  assign squash_sub_notif.target  = squash_pub_msg.target;

  TestPub #( t_squash_msg ) squash_pub (
    .msg (squash_sub_msg),
    .val (squash_sub_notif.val),
    .*
  );

  t_squash_msg msg_to_squash;

  task pub_squash(
    input logic [p_seq_num_bits-1:0] seq_num,
    input logic               [31:0] target
  );
    msg_to_squash.seq_num = seq_num;
    msg_to_squash.target  = target;

    squash_pub.pub( msg_to_squash );
  endtask

  //----------------------------------------------------------------------
  // Handle giving messages to the correct pipe
  //----------------------------------------------------------------------

  function rv_op_vec vec_of_uop (input rv_uop uop);
    if( uop == OP_ADD  ) return OP_ADD_VEC;
    if( uop == OP_MUL  ) return OP_MUL_VEC;
    if( uop == OP_LW   ) return OP_LW_VEC;
    if( uop == OP_SW   ) return OP_SW_VEC;
    if( uop == OP_JAL  ) return OP_JAL_VEC;
    if( uop == OP_JALR ) return OP_JALR_VEC;
    if( uop == OP_BNE  ) return OP_BNE_VEC;
  endfunction

  t_d__x_msg msgs_to_recv     [p_num_pipes];
  logic      msgs_to_recv_val [p_num_pipes];

  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin
      always @( posedge clk ) begin
        #1;
        if (msgs_to_recv_val[i]) begin
          X_Ostreams[i].X_Ostream.recv(
            msgs_to_recv[i]
          );
        end

        // verilator lint_off BLKSEQ
        msgs_to_recv_val[i] = 1'b0;
        // verilator lint_on BLKSEQ
      end

      initial begin
        msgs_to_recv_val[i] = 1'b0;
      end
    end
  endgenerate

  int        pipe_delays [p_num_pipes];
  int        pipe_found, first_iter;
  t_d__x_msg pipe_msg;

  always @( posedge clk ) begin
    if( rst ) begin
      pipe_delays <= '{default: 0};
    end
  end

  task recv(
    input logic                 [31:0] pc,
    input logic   [p_seq_num_bits-1:0] seq_num,
    input logic                 [31:0] op1,
    input logic                 [31:0] op2,
    input logic                  [4:0] waddr,
    input logic [p_phys_addr_bits-1:0] preg,
    input logic [p_phys_addr_bits-1:0] ppreg,
    input rv_uop                       uop
  );
    // Set message correctly
    pipe_msg.pc      = pc;
    pipe_msg.seq_num = seq_num;
    pipe_msg.op1     = op1;
    pipe_msg.op2     = op2;
    pipe_msg.waddr   = waddr;
    pipe_msg.preg    = preg;
    pipe_msg.ppreg   = ppreg;
    pipe_msg.uop     = uop;

    pipe_found = 0;
    first_iter = 1;
    while( pipe_found == 0 ) begin
      // Decrement all delays
      for( int j = 0; j < p_num_pipes; j = j + 1 ) begin
        if( pipe_delays[j] > 0 ) begin
          if(( first_iter == 1 ) & (p_F_send_intv_delay > 1)) begin
            pipe_delays[j] = pipe_delays[j] - p_F_send_intv_delay;
          end else begin
            pipe_delays[j] = pipe_delays[j] - 1;
          end
          if( pipe_delays[j] < 0 ) pipe_delays[j] = 0;
        end
      end

      if( first_iter == 1 ) first_iter = 0;

      // Find correct pipe
      for( int j = 0; j < p_num_pipes; j = j + 1 ) begin
        if(( (p_pipe_subsets[j] & vec_of_uop(uop)) > 0 ) & ( pipe_delays[j] == 0 )) begin
          msgs_to_recv[j]     = pipe_msg;
          msgs_to_recv_val[j] = 1'b1;

          wait(msgs_to_recv_val[j] == 1'b0);
          pipe_delays[j] = p_X_recv_intv_delay;
          pipe_found = 1;
          break;
        end
      end
    end
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string X_traces [p_num_pipes-1:0];
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin
      // verilator lint_off BLKSEQ
      always @( posedge clk ) begin
        #2;
        X_traces[i] = X_Ostreams[i].X_Ostream.trace( t.trace_level );
      end
      // verilator lint_on BLKSEQ
    end
  endgenerate

  // Need to store other traces, to be aligned with X_Ostream traces
  string trace;
  string F_Istream_trace;
  string dut_trace;
  string complete_trace;
  string commit_trace;
  string squash_trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    F_Istream_trace = F_Istream.trace( t.trace_level );
    dut_trace       = dut.trace( t.trace_level );
    complete_trace  = complete_pub.trace( t.trace_level );
    commit_trace    = commit_pub.trace( t.trace_level );
    squash_trace    = squash_sub.trace( t.trace_level );

    // Wait until X_Ostream traces are ready
    #1;
    trace = "";

    trace = {trace, F_Istream_trace};
    trace = {trace, " | "};
    trace = {trace, dut_trace};
    trace = {trace, " | "};
    for( int j = 0; j < p_num_pipes; j++ ) begin
      if( j > 0 )
        trace = {trace, " "};
      trace = {trace, X_traces[j]};
    end
    trace = {trace, " | "};
    trace = {trace, complete_trace};
    trace = {trace, " | "};
    trace = {trace, commit_trace};
    trace = {trace, " | "};
    trace = {trace, squash_trace};
    
    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Include test cases
  //----------------------------------------------------------------------

  `include "hw/decode_issue/test/test_cases/multi_rename_test_cases.v"

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    run_multi_test_cases();

  endtask
endmodule

//========================================================================
// DecodeIssueUnitL6_test
//========================================================================

module DecodeIssueUnitL6_test;
  DecodeIssueUnitL6TestSuite #(1) suite_1();
  DecodeIssueUnitL6TestSuite #(
    2, 
    2, 
    4, 
    36,
    2,
    0, 
    0, 
    {p_tinyrv1, OP_ADD_VEC}) 
  suite_2();
  DecodeIssueUnitL6TestSuite #(
    3, 
    5, 
    8, 
    36,
    2,
    0, 
    0, 
    {
      p_tinyrv1, 
      p_tinyrv1, 
      p_tinyrv1, 
      p_tinyrv1, 
      OP_MUL_VEC
    }
  ) suite_3();
  DecodeIssueUnitL6TestSuite #(
    4, 
    1, 
    3, 
    40,
    2,
    0, 
    0, 
    {p_tinyrv1}
  ) suite_4();
  DecodeIssueUnitL6TestSuite #(
    5, 
    3, 
    6, 
    60,
    2,
    3, 
    0, 
    {
      p_tinyrv1, 
      p_tinyrv1, 
      p_tinyrv1
    }
  ) suite_5();
  DecodeIssueUnitL6TestSuite #(
    6, 
    3, 
    7, 
    50,
    2,
    0, 
    3, 
    {
      p_tinyrv1, 
      p_tinyrv1, 
      p_tinyrv1
    }
  ) suite_6();
  DecodeIssueUnitL6TestSuite #(
    7, 
    3, 
    3, 
    48,
    2,
    3, 
    3, 
    {
      p_tinyrv1, 
      p_tinyrv1, 
      p_tinyrv1
    }
  ) suite_7();

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

    test_bench_end();
  end
endmodule
