//========================================================================
// DecodeIssueUnitL8_test.v
//========================================================================
// A testbench for our decode-issue unit with WAW stalling



`include "asm/assemble.v"
`include "defs/UArch.v"
`include "hw/decode_issue/decode_issue_unit_variants/DecodeIssueUnitL8.v"
`include "test/fl/TestPub.v"
`include "test/fl/TestMPub.v"
`include "test/fl/TestSub.v"
`include "test/fl/TestIstream.v"
`include "test/fl/TestOstream.v"

import UArch::*;
import TestEnv::*;

//========================================================================
// DecodeIssueUnitL8TestSuite
//========================================================================
// A test suite for the basic decoder

module DecodeIssueUnitL8TestSuite #(
  parameter p_suite_num         = 0,
  parameter p_num_pipes         = 4,
  parameter p_seq_num_bits      = 5,
  parameter p_num_phys_regs     = 36,
  parameter p_iq_depth          = 8,
  parameter p_F_send_intv_delay = 0,
  parameter p_X_recv_intv_delay = 0,
  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1},
  parameter p_num_fe_lanes      = 2,
  parameter p_num_be_lanes      = 2
);

  string suite_name = $sformatf("%0d: DecodeIssueUnitL8TestSuite_%0d_%0d_%0d_%0d_%0d_%0d_%0dfe_%0dbe", 
                                p_suite_num, p_num_pipes, p_seq_num_bits, p_num_phys_regs,
                                p_iq_depth, p_F_send_intv_delay, p_X_recv_intv_delay,
                                p_num_fe_lanes, p_num_be_lanes);

  initial begin
    for( int i = 0; i < p_num_pipes; i++ ) begin
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
  localparam p_pipe_idx_bits = p_num_pipes > 1 ? $clog2(p_num_pipes) : 1;

  F__DIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) F__D_intf [p_num_fe_lanes] ();

  D__XIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) D__X_intfs [p_num_pipes] ();

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

  DecodeIssueUnitL8 #(
    .p_num_pipes     (p_num_pipes),
    .p_num_phys_regs (p_num_phys_regs),
    .p_num_fe_lanes  (p_num_fe_lanes),
    .p_num_be_lanes  (p_num_be_lanes),
    .p_iq_depth      (p_iq_depth),
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
    logic                      insn_valid;
  } t_f__d_msg;

  t_f__d_msg f__d_msg [p_num_fe_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin : F__D_ISTREAMS_GEN 
      assign F__D_intf[i].inst       = f__d_msg[i].inst;
      assign F__D_intf[i].pc         = f__d_msg[i].pc;
      assign F__D_intf[i].seq_num    = f__d_msg[i].seq_num;
      assign F__D_intf[i].insn_valid = f__d_msg[i].insn_valid;

      TestIstream #( 
        t_f__d_msg, 
        p_F_send_intv_delay 
      ) F_Istream (
        .msg (f__d_msg[i]),
        .val (F__D_intf[i].val),
        .rdy (F__D_intf[i].rdy),
        .*
      );
    end
  endgenerate

  t_f__d_msg msgs_to_send     [p_num_fe_lanes];
  logic      msgs_to_send_val [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin
      always @( posedge clk ) begin
        #1;
        if( msgs_to_send_val[i] ) begin
          F__D_ISTREAMS_GEN[i].F_Istream.send(
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

  t_f__d_msg send_task_msg [p_num_fe_lanes];

  task send(
    input logic               [31:0] pc         [p_num_fe_lanes],
    input string                     assembly   [p_num_fe_lanes],
    input logic [p_seq_num_bits-1:0] seq_num    [p_num_fe_lanes],
    input logic                      insn_valid [p_num_fe_lanes],
    input logic                      valid      [p_num_fe_lanes]
  );
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      automatic int jj = j;
      fork
        begin
          send_task_msg[jj].inst       = assemble(assembly[jj], pc[jj]);
          send_task_msg[jj].pc         = pc[jj];
          send_task_msg[jj].seq_num    = seq_num[jj];
          send_task_msg[jj].insn_valid = insn_valid[jj];
          msgs_to_send[jj]             = send_task_msg[jj];
          msgs_to_send_val[jj]         = valid[jj];
          while(msgs_to_send_val[jj])
            #1;
        end
      join_none
    end
    wait fork;
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

  logic                        D__X_intfs_val     [p_num_pipes];
  logic                 [31:0] D__X_intfs_pc      [p_num_pipes];
  logic   [p_seq_num_bits-1:0] D__X_intfs_seq_num [p_num_pipes];
  logic                 [31:0] D__X_intfs_op1     [p_num_pipes];
  logic                 [31:0] D__X_intfs_op2     [p_num_pipes];
  logic                  [4:0] D__X_intfs_waddr   [p_num_pipes];
  logic [p_phys_addr_bits-1:0] D__X_intfs_preg    [p_num_pipes];
  logic [p_phys_addr_bits-1:0] D__X_intfs_ppreg   [p_num_pipes];
  rv_uop                       D__X_intfs_uop     [p_num_pipes];

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin
      assign D__X_intfs_val[i]     = D__X_intfs[i].val;
      assign d__x_msgs[i].pc       = D__X_intfs[i].pc;
      assign D__X_intfs_pc[i]      = D__X_intfs[i].pc;
      assign d__x_msgs[i].seq_num  = D__X_intfs[i].seq_num;
      assign D__X_intfs_seq_num[i] = D__X_intfs[i].seq_num;
      assign d__x_msgs[i].op1      = D__X_intfs[i].op1;
      assign D__X_intfs_op1[i]     = D__X_intfs[i].op1;
      assign d__x_msgs[i].op2      = D__X_intfs[i].op2;
      assign D__X_intfs_op2[i]     = D__X_intfs[i].op2;
      assign d__x_msgs[i].waddr    = D__X_intfs[i].waddr;
      assign D__X_intfs_waddr[i]   = D__X_intfs[i].waddr;
      assign d__x_msgs[i].uop      = D__X_intfs[i].uop;
      assign D__X_intfs_uop[i]     = D__X_intfs[i].uop;
      assign d__x_msgs[i].preg     = D__X_intfs[i].preg;
      assign D__X_intfs_preg[i]    = D__X_intfs[i].preg;
      assign d__x_msgs[i].ppreg    = D__X_intfs[i].ppreg;
      assign D__X_intfs_ppreg[i]   = D__X_intfs[i].ppreg;
    end
  endgenerate

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin: X_Ostreams
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
    .p_num_msgs (p_num_be_lanes)
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
    .p_num_msgs (p_num_be_lanes)
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
    for( i = 0; i < p_num_pipes; i++ ) begin
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
    input rv_uop                       uop,
    input logic [p_pipe_idx_bits-1:0]  expected_pipe
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
        // $display("looking for pipe %0d against pipe %0d with delay %0d", j, expected_pipe, pipe_delays[j]);
        // $display("pipe subset = %b, vec_of_uop = %b, in subset = %b", p_pipe_subsets[j], vec_of_uop(uop), p_pipe_subsets[j] & vec_of_uop(uop));
        if( p_pipe_idx_bits'(j) == expected_pipe & 
          ( (p_pipe_subsets[j] & vec_of_uop(uop)) > 0 ) & ( pipe_delays[j] == 0 )
        ) begin
          // $display("pipe found!");
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

  // string X_traces [p_num_pipes-1:0];
  // generate
  //   for( i = 0; i < p_num_pipes; i++ ) begin
  //     // verilator lint_off BLKSEQ
  //     always @( posedge clk ) begin
  //       #2;
  //       X_traces[i] = X_Ostreams[i].X_Ostream.trace( t.trace_level );
  //     end
  //     // verilator lint_on BLKSEQ
  //   end
  // endgenerate

  // Need to store other traces, to be aligned with X_Ostream traces
  string trace;
  // string F_Istream_trace;
  // string dut_trace;
  // string complete_trace;
  // string commit_trace;
  // string squash_trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    // F_Istream_trace = F_Istream.trace( t.trace_level );
    // dut_trace       = dut.trace( t.trace_level );
    // complete_trace  = complete_pub.trace( t.trace_level );
    // commit_trace    = commit_pub.trace( t.trace_level );
    // squash_trace    = squash_sub.trace( t.trace_level );

    // Wait until X_Ostream traces are ready
    #1;
    trace = "";

    // trace = {trace, F_Istream_trace};
    // trace = {trace, " | "};
    // trace = {trace, dut_trace};
    // trace = {trace, " | "};
    // for( int j = 0; j < p_num_pipes; j++ ) begin
    //   if( j > 0 )
    //     trace = {trace, " "};
    //   trace = {trace, X_traces[j]};
    // end
    // trace = {trace, " | "};
    // trace = {trace, complete_trace};
    // trace = {trace, " | "};
    // trace = {trace, commit_trace};
    // trace = {trace, " | "};
    // trace = {trace, squash_trace};
    
    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Include test cases
  //----------------------------------------------------------------------

  `include "hw/decode_issue/test/test_cases/l8_basic_test_cases.v"

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    run_basic_test_cases();
    // #100;
  endtask
endmodule

//========================================================================
// DecodeIssueUnitL8_test
//========================================================================

module DecodeIssueUnitL8_test;
  DecodeIssueUnitL8TestSuite #(
    .p_suite_num (1)
  ) suite_1();
  DecodeIssueUnitL8TestSuite #(
    .p_suite_num         (2),
    .p_num_pipes         (2),
    .p_seq_num_bits      (4),
    .p_num_phys_regs     (36),
    .p_iq_depth          (8),
    .p_F_send_intv_delay (0),
    .p_X_recv_intv_delay (0),
    .p_pipe_subsets      ({p_tinyrv1, OP_ADD_VEC}),
    .p_num_be_lanes      (2)
  ) suite_2();
  DecodeIssueUnitL8TestSuite #(
    .p_suite_num         (3),
    .p_num_pipes         (5),
    .p_seq_num_bits      (8),
    .p_num_phys_regs     (36),
    .p_iq_depth          (8),
    .p_F_send_intv_delay (0),
    .p_X_recv_intv_delay (0),
    .p_pipe_subsets      ({
      p_tinyrv1,
      p_tinyrv1,
      p_tinyrv1,
      p_tinyrv1,
      OP_MUL_VEC
    }),
    .p_num_be_lanes      (2)
  ) suite_3();
  DecodeIssueUnitL8TestSuite #(
    .p_suite_num         (4),
    .p_num_pipes         (1),
    .p_seq_num_bits      (3),
    .p_num_phys_regs     (40),
    .p_iq_depth          (8),
    .p_F_send_intv_delay (0),
    .p_X_recv_intv_delay (0),
    .p_pipe_subsets      ({p_tinyrv1}),
    .p_num_be_lanes      (2)
  ) suite_4();
  DecodeIssueUnitL8TestSuite #(
    .p_suite_num         (5),
    .p_num_pipes         (3),
    .p_seq_num_bits      (6),
    .p_num_phys_regs     (60),
    .p_iq_depth          (8),
    .p_F_send_intv_delay (3),
    .p_X_recv_intv_delay (0),
    .p_pipe_subsets      ({
      p_tinyrv1,
      p_tinyrv1,
      p_tinyrv1
    }),
    .p_num_be_lanes      (2)
  ) suite_5();
  DecodeIssueUnitL8TestSuite #(
    .p_suite_num         (6),
    .p_num_pipes         (3),
    .p_seq_num_bits      (7),
    .p_num_phys_regs     (50),
    .p_iq_depth          (8),
    .p_F_send_intv_delay (0),
    .p_X_recv_intv_delay (3),
    .p_pipe_subsets      ({
      p_tinyrv1,
      p_tinyrv1,
      p_tinyrv1
    }),
    .p_num_be_lanes      (2)
  ) suite_6();
  DecodeIssueUnitL8TestSuite #(
    .p_suite_num         (7),
    .p_num_pipes         (3),
    .p_seq_num_bits      (3),
    .p_num_phys_regs     (48),
    .p_iq_depth          (8),
    .p_F_send_intv_delay (3),
    .p_X_recv_intv_delay (3),
    .p_pipe_subsets      ({
      p_tinyrv1,
      p_tinyrv1,
      p_tinyrv1
    }),
    .p_num_be_lanes      (2)
  ) suite_7();
  DecodeIssueUnitL8TestSuite #(
    .p_suite_num         (8),
    .p_num_pipes         (3),
    .p_seq_num_bits      (3),
    .p_num_phys_regs     (33),
    .p_iq_depth          (4),
    .p_F_send_intv_delay (3),
    .p_X_recv_intv_delay (3),
    .p_pipe_subsets      ({
      p_tinyrv1,
      p_tinyrv1,
      p_tinyrv1
    }),
    .p_num_be_lanes      (2)
  ) suite_8();

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
