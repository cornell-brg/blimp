//========================================================================
// SSRenameTableL3_test.v
//========================================================================
// A testbench for our multi rename table

`include "hw/decode_issue/SSRenameTableL3.v"
`include "intf/CommitNotif.v"
`include "intf/CompleteNotif.v"
`include "test/fl/TestCaller.v"
`include "test/fl/TestMPub.v"
`include "test/TestUtils.v"

import TestEnv::*;

//========================================================================
// SSRenameTableL3TestSuite
//========================================================================
// A test suite for the rename table

module SSRenameTableL3TestSuite #(
  parameter p_suite_num        = 0,
  parameter p_num_phys_regs    = 36,
  parameter p_num_lookup_ports = 2,
  parameter p_num_fe_lanes     = 2,
  parameter p_num_be_lanes     = 2
);

  localparam p_phys_addr_bits = $clog2( p_num_phys_regs );

  string suite_name = $sformatf("%0d: SSRenameTableL3TestSuite_%0d", 
                                p_suite_num, p_num_phys_regs);
  
  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  logic                  [4:0] dut_alloc_areg  [p_num_fe_lanes];
  logic [p_phys_addr_bits-1:0] dut_alloc_preg  [p_num_fe_lanes];
  logic [p_phys_addr_bits-1:0] dut_alloc_ppreg [p_num_fe_lanes];
  logic                        dut_alloc_en    [p_num_fe_lanes];
  logic                        dut_alloc_rdy   [p_num_fe_lanes];

  logic                  [4:0] dut_lookup_new_inst_areg [p_num_fe_lanes][2];
  logic                        dut_lookup_new_inst_en   [p_num_fe_lanes][2];
  logic [p_phys_addr_bits-1:0] dut_lookup_new_inst_preg [p_num_fe_lanes][2];

  logic [p_phys_addr_bits-1:0] dut_lookup_iq_preg    [p_num_lookup_ports][2];
  logic                        dut_lookup_iq_en      [p_num_lookup_ports][2];
  logic                        dut_lookup_iq_pending [p_num_lookup_ports][2];

  CompleteNotif #(
    .p_phys_addr_bits (p_phys_addr_bits)
  ) complete_notif [p_num_be_lanes] ();

  CommitNotif #(
    .p_phys_addr_bits (p_phys_addr_bits)
  ) commit_notif [p_num_be_lanes] ();

  SSRenameTableL3 #(
    .p_num_phys_regs    (p_num_phys_regs),
    .p_num_lookup_ports (p_num_lookup_ports),
    .p_num_fe_lanes     (p_num_fe_lanes),
    .p_num_be_lanes     (p_num_be_lanes)
  ) dut (
    .alloc_areg  (dut_alloc_areg),
    .alloc_preg  (dut_alloc_preg),
    .alloc_ppreg (dut_alloc_ppreg),
    .alloc_en    (dut_alloc_en),
    .alloc_rdy   (dut_alloc_rdy),

    .lookup_new_inst_areg (dut_lookup_new_inst_areg),
    .lookup_new_inst_en   (dut_lookup_new_inst_en),
    .lookup_new_inst_preg (dut_lookup_new_inst_preg),

    .lookup_iq_preg    (dut_lookup_iq_preg),
    .lookup_iq_en      (dut_lookup_iq_en),
    .lookup_iq_pending (dut_lookup_iq_pending),

    .complete    (complete_notif),
    .commit      (commit_notif),
    .*
  );

  //----------------------------------------------------------------------
  // Allocation
  //----------------------------------------------------------------------

  typedef logic [4:0] t_alloc_call_msg;

  typedef struct packed {
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
  } t_alloc_ret_msg;

  t_alloc_ret_msg alloc_ret_msg [p_num_fe_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: ALLOC_PORT
      assign alloc_ret_msg[i].preg  = dut_alloc_preg[i];
      assign alloc_ret_msg[i].ppreg = dut_alloc_ppreg[i];

      TestCaller #(
        .t_call_msg (t_alloc_call_msg),
        .t_ret_msg  (t_alloc_ret_msg)
      ) alloc_caller (
        .call_msg (dut_alloc_areg[i]),
        .ret_msg  (alloc_ret_msg[i]),
        .en       (dut_alloc_en[i]),
        .rdy      (dut_alloc_rdy[i]),
        .*
      );
    end
  endgenerate

  t_alloc_ret_msg msgs_from_alloc      [p_num_fe_lanes];
  logic     [4:0] msgs_from_alloc_areg [p_num_fe_lanes];
  logic           msgs_from_alloc_val  [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin
      always @( posedge clk ) begin
        #1;
        if( msgs_from_alloc_val[i] ) begin
          ALLOC_PORT[i].alloc_caller.call(
            msgs_from_alloc_areg[i],
            msgs_from_alloc[i]
          );
        end

        // verilator lint_off BLKSEQ
        msgs_from_alloc_val[i] = 1'b0;
        // verilator lint_on BLKSEQ
      end

      initial begin
        msgs_from_alloc_val[i] = 1'b0;
      end
    end
  endgenerate

  t_alloc_ret_msg alloc_task_msg [p_num_fe_lanes];

  task alloc(
    input logic                  [4:0] areg  [p_num_fe_lanes],
    input logic [p_phys_addr_bits-1:0] preg  [p_num_fe_lanes],
    input logic [p_phys_addr_bits-1:0] ppreg [p_num_fe_lanes],
    input logic                        valid [p_num_fe_lanes]
  );
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      automatic int jj = j;
      fork
        begin
          alloc_task_msg[jj].preg  = preg[jj];
          alloc_task_msg[jj].ppreg = ppreg[jj];
          msgs_from_alloc_areg[jj] = areg[jj];
          msgs_from_alloc[jj]      = alloc_task_msg[jj];
          msgs_from_alloc_val[jj]  = valid[jj];
          while(msgs_from_alloc_val[jj])
            #1;
        end
      join_none
    end
    wait fork;
  endtask

  //----------------------------------------------------------------------
  // Lookup new inst source registers
  //----------------------------------------------------------------------

  typedef logic [4:0] t_lookup_new_inst_call_msg;
  typedef struct packed {
    logic [p_phys_addr_bits-1:0] preg;
  } t_new_inst_lookup_ret_msg;

  t_new_inst_lookup_ret_msg lookup_new_inst_ret_msg [p_num_fe_lanes][2];
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: LOOKUP_NEW_INST_PORT
      assign lookup_new_inst_ret_msg[i][0].preg = dut_lookup_new_inst_preg[i][0];
      assign lookup_new_inst_ret_msg[i][1].preg = dut_lookup_new_inst_preg[i][1];

      TestCaller #(
        .t_call_msg (t_lookup_new_inst_call_msg),
        .t_ret_msg  (t_new_inst_lookup_ret_msg)
      ) lookup_new_inst_caller_0 (
        .call_msg (dut_lookup_new_inst_areg[i][0]),
        .ret_msg  (lookup_new_inst_ret_msg[i][0]),
        .en       (dut_lookup_new_inst_en[i][0]),
        .rdy      (1'b1),
        .*
      );

      TestCaller #(
        .t_call_msg (t_lookup_new_inst_call_msg),
        .t_ret_msg  (t_new_inst_lookup_ret_msg)
      ) lookup_new_inst_caller_1 (
        .call_msg (dut_lookup_new_inst_areg[i][1]),
        .ret_msg  (lookup_new_inst_ret_msg[i][1]),
        .en       (dut_lookup_new_inst_en[i][1]),
        .rdy      (1'b1),
        .*
      );
    end
  endgenerate

  t_new_inst_lookup_ret_msg msg_from_new_inst_lookup      [p_num_fe_lanes][2];
  logic               [4:0] msg_from_new_inst_lookup_areg [p_num_fe_lanes][2];
  logic                     msg_from_new_inst_lookup_val  [p_num_fe_lanes][2];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin
      always @( posedge clk ) begin
        #1;
        fork
          if( msg_from_new_inst_lookup_val[i][0] ) begin
            LOOKUP_NEW_INST_PORT[i].lookup_new_inst_caller_0.call( 
              msg_from_new_inst_lookup_areg[i][0],
              msg_from_new_inst_lookup[i][0]
            );
          end
          if( msg_from_new_inst_lookup_val[i][1] ) begin
            LOOKUP_NEW_INST_PORT[i].lookup_new_inst_caller_1.call( 
              msg_from_new_inst_lookup_areg[i][1],
              msg_from_new_inst_lookup[i][1]
            );
          end
        join

        // verilator lint_off BLKSEQ
        msg_from_new_inst_lookup_val[i][0] = 1'b0;
        msg_from_new_inst_lookup_val[i][1] = 1'b0;
        // verilator lint_on BLKSEQ
      end

      initial begin
        msg_from_new_inst_lookup_val[i][0] = 1'b0;
        msg_from_new_inst_lookup_val[i][1] = 1'b0;
      end
    end
  endgenerate

  t_new_inst_lookup_ret_msg lookup_new_inst_task_msg [p_num_fe_lanes][2];

  task lookup_new_inst_srcs(
    input logic                  [4:0] lookup_areg [p_num_fe_lanes][2],
    input logic [p_phys_addr_bits-1:0] lookup_preg [p_num_fe_lanes][2],
    input logic                        valid       [p_num_fe_lanes][2]
  );
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      automatic int jj = j;
      fork
        begin
          lookup_new_inst_task_msg[jj][0]  = lookup_preg[jj][0];
          lookup_new_inst_task_msg[jj][1]  = lookup_preg[jj][1];
          msg_from_new_inst_lookup_areg[jj][0] = lookup_areg[jj][0];
          msg_from_new_inst_lookup_areg[jj][1] = lookup_areg[jj][1];
          msg_from_new_inst_lookup[jj][0]      = lookup_new_inst_task_msg[jj][0];
          msg_from_new_inst_lookup[jj][1]      = lookup_new_inst_task_msg[jj][1];
          msg_from_new_inst_lookup_val[jj][0]  = valid[jj][0];
          msg_from_new_inst_lookup_val[jj][1]  = valid[jj][1];
          while ( msg_from_new_inst_lookup_val[jj][0] || msg_from_new_inst_lookup_val[jj][1] ) begin
            #1;
          end
        end
      join_none
    end
    wait fork;
  endtask
  
  //----------------------------------------------------------------------
  // Lookup IQ inst source registers
  //----------------------------------------------------------------------

  typedef logic [p_phys_addr_bits-1:0] t_lookup_iq_call_msg;
  typedef struct packed {
    logic pending;
  } t_lookup_iq_ret_msg;

  t_lookup_iq_ret_msg lookup_iq_ret_msg [p_num_lookup_ports][2];

  generate
    for( i = 0; i < p_num_lookup_ports; i++ ) begin: LOOKUP_IQ_PORT
      assign lookup_iq_ret_msg[i][0].pending = dut_lookup_iq_pending[i][0];
      assign lookup_iq_ret_msg[i][1].pending = dut_lookup_iq_pending[i][1];

      TestCaller #(
        .t_call_msg (t_lookup_iq_call_msg),
        .t_ret_msg  (t_lookup_iq_ret_msg)
      ) lookup_iq_caller_0 (
        .call_msg (dut_lookup_iq_preg[i][0]),
        .ret_msg  (lookup_iq_ret_msg[i][0]),
        .en       (dut_lookup_iq_en[i][0]),
        .rdy      (1'b1),
        .*
      );

      TestCaller #(
        .t_call_msg (t_lookup_iq_call_msg),
        .t_ret_msg  (t_lookup_iq_ret_msg)
      ) lookup_iq_caller_1 (
        .call_msg (dut_lookup_iq_preg[i][1]),
        .ret_msg  (lookup_iq_ret_msg[i][1]),
        .en       (dut_lookup_iq_en[i][1]),
        .rdy      (1'b1),
        .*
      );
    end
  endgenerate

  t_lookup_iq_ret_msg          msg_from_lookup_iq      [p_num_lookup_ports][2];
  logic [p_phys_addr_bits-1:0] msg_from_lookup_iq_preg [p_num_lookup_ports][2];
  logic                        msg_from_lookup_iq_val  [p_num_lookup_ports][2];

  generate
    for( i = 0; i < p_num_lookup_ports; i++ ) begin
      always @( posedge clk ) begin
        #1;
        if( msg_from_lookup_iq_val[i][0] ) begin
          LOOKUP_IQ_PORT[i].lookup_iq_caller_0.call( 
            msg_from_lookup_iq_preg[i][0],
            msg_from_lookup_iq[i][0]
          );
        end
        if( msg_from_lookup_iq_val[i][1] ) begin
          LOOKUP_IQ_PORT[i].lookup_iq_caller_1.call( 
            msg_from_lookup_iq_preg[i][1],
            msg_from_lookup_iq[i][1]
          );
        end

        // verilator lint_off BLKSEQ
        msg_from_lookup_iq_val[i][0] = 1'b0;
        msg_from_lookup_iq_val[i][1] = 1'b0;
        // verilator lint_on BLKSEQ
      end

      initial begin
        msg_from_lookup_iq_val[i][0] = 1'b0;
        msg_from_lookup_iq_val[i][1] = 1'b0;
      end
    end
  endgenerate

  t_lookup_iq_ret_msg lookup_iq_src_task_msg [p_num_lookup_ports][2];

  task lookup_iq_srcs(
    input logic [p_phys_addr_bits-1:0] lookup_preg [p_num_lookup_ports][2],
    input logic                        pending     [p_num_lookup_ports][2],
    input logic                        valid       [p_num_lookup_ports][2]
  );
    for( int j = 0; j < p_num_lookup_ports; j++ ) begin
      automatic int jj = j;
      fork
        begin
          lookup_iq_src_task_msg[jj][0]  = pending[jj][0];
          lookup_iq_src_task_msg[jj][1]  = pending[jj][1];
          msg_from_lookup_iq_preg[jj][0] = lookup_preg[jj][0];
          msg_from_lookup_iq_preg[jj][1] = lookup_preg[jj][1];
          msg_from_lookup_iq[jj][0]      = lookup_iq_src_task_msg[jj][0];
          msg_from_lookup_iq[jj][1]      = lookup_iq_src_task_msg[jj][1];
          msg_from_lookup_iq_val[jj][0]  = valid[jj][0];
          msg_from_lookup_iq_val[jj][1]  = valid[jj][1];
          while ( msg_from_lookup_iq_val[jj][0] || msg_from_lookup_iq_val[jj][1] ) begin
            #1;
          end
        end
      join_none
      wait fork;
    end
  endtask

  //----------------------------------------------------------------------
  // Complete
  //----------------------------------------------------------------------

  typedef logic [p_phys_addr_bits-1:0] t_complete_msg;

  t_complete_msg complete_msg     [p_num_be_lanes];
  logic          complete_msg_val [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign complete_notif[i].preg  = complete_msg[i];
      assign complete_notif[i].waddr = 'x;
      assign complete_notif[i].wdata = 'x;
      assign complete_notif[i].wen   = 'x;
      assign complete_notif[i].val   = complete_msg_val[i];
    end
  endgenerate

  logic  [4:0] unused_complete_waddr [p_num_be_lanes];
  logic [31:0] unused_complete_wdata [p_num_be_lanes];
  logic        unused_complete_wen   [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign unused_complete_waddr[i] = complete_notif[i].waddr;
      assign unused_complete_wdata[i] = complete_notif[i].wdata;
      assign unused_complete_wen[i]   = complete_notif[i].wen;
    end
  endgenerate

  TestMPub #(
    .t_msg      (t_complete_msg),
    .p_num_msgs (p_num_be_lanes)
  ) complete_pub (
    .msg (complete_msg),
    .val (complete_msg_val),
    .*
  );

  t_complete_msg msg_to_complete_pub     [p_num_be_lanes];
  logic          msg_to_complete_pub_val [p_num_be_lanes];

  task complete(
    input t_complete_msg preg [p_num_be_lanes],
    input logic          val  [p_num_be_lanes]
  );
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      msg_to_complete_pub[j]     = preg[j];
      msg_to_complete_pub_val[j] = val[j];
    end

    complete_pub.pub( msg_to_complete_pub, msg_to_complete_pub_val );
  endtask

  //----------------------------------------------------------------------
  // Commit
  //----------------------------------------------------------------------

  typedef logic [p_phys_addr_bits-1:0] t_commit_msg;

  t_commit_msg commit_msg     [p_num_be_lanes];
  logic        commit_msg_val [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign commit_notif[i].ppreg = commit_msg[i];
      assign commit_notif[i].pc    = 'x;
      assign commit_notif[i].waddr = 'x;
      assign commit_notif[i].wdata = 'x;
      assign commit_notif[i].wen   = 'x;
      assign commit_notif[i].val   = commit_msg_val[i];
    end
  endgenerate

  logic [31:0] unused_commit_pc    [p_num_be_lanes];
  logic  [4:0] unused_commit_waddr [p_num_be_lanes];
  logic [31:0] unused_commit_wdata [p_num_be_lanes];
  logic        unused_commit_wen   [p_num_be_lanes];

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
  ) commit_pub (
    .msg (commit_msg),
    .val (commit_msg_val),
    .*
  );

  t_commit_msg msg_to_commit_pub     [p_num_be_lanes];
  logic        msg_to_commit_pub_val [p_num_be_lanes];

  task commit(
    input t_commit_msg ppreg [p_num_be_lanes],
    input logic        val   [p_num_be_lanes]
  );
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      msg_to_commit_pub[j]     = ppreg[j];
      msg_to_commit_pub_val[j] = val[j];
    end

    commit_pub.pub( msg_to_commit_pub, msg_to_commit_pub_val );
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    trace = "";

    // trace = {trace, dut.trace( t.trace_level )};
    // trace = {trace, " | "};
    // trace = {trace, alloc_caller.trace( t.trace_level )};
    // trace = {trace, " | "};
    // trace = {trace, lookup_caller[0].trace( t.trace_level )};
    // trace = {trace, " | "};
    // trace = {trace, lookup_caller[1].trace( t.trace_level )};
    // trace = {trace, " | "};
    // trace = {trace, complete_pub.trace( t.trace_level )};
    // trace = {trace, " | "};
    // trace = {trace, commit_pub.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // test_case_1_single_lane_allocate_lookup
  //----------------------------------------------------------------------

  task test_case_1_single_lane_allocate_lookup();
    automatic int urandom_res;

    logic                  [4:0] alloc_areg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes];
    logic                        alloc_valid [p_num_fe_lanes];

    logic                  [4:0] lookup_areg  [p_num_fe_lanes][2];
    logic [p_phys_addr_bits-1:0] lookup_preg  [p_num_fe_lanes][2];
    logic                        lookup_valid [p_num_fe_lanes][2];

    t.test_case_begin( "test_case_1_single_lane_allocate_lookup" );
    if( !t.run_test ) return;

    for( int i = 0; i < p_num_fe_lanes; i++ ) begin

      // Only allocate on lane 0 for this test
      alloc_areg[i]  = i == 0 ? 5'(3) : 5'(0);
      alloc_preg[i]  = i == 0 ? p_phys_addr_bits'(32) : p_phys_addr_bits'(0);
      alloc_ppreg[i] = i == 0 ? p_phys_addr_bits'(3) : p_phys_addr_bits'(0);
      alloc_valid[i] = i == 0;

      // Only lookup on lane 0 for this test
      for( int j = 0; j < 2; j++ ) begin
        lookup_areg[i][j]  = i == 0 ? 5'(2) : 5'(0);
        lookup_preg[i][j]  = i == 0 ? p_phys_addr_bits'(2) : p_phys_addr_bits'(0);
        lookup_valid[i][j] = i == 0;
      end
    end

    fork
      alloc(
        alloc_areg, 
        alloc_preg, 
        alloc_ppreg, 
        alloc_valid
      );

      lookup_new_inst_srcs(
        lookup_areg, 
        lookup_preg, 
        lookup_valid
      );
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_2_all_lane_allocate_lookup_no_overlap
  //----------------------------------------------------------------------

  task test_case_2_all_lane_allocate_lookup_no_overlap();
    automatic int urandom_res;

    logic                  [4:0] alloc_areg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes];
    logic                        alloc_valid [p_num_fe_lanes];

    logic                  [4:0] lookup_areg  [p_num_fe_lanes][2];
    logic [p_phys_addr_bits-1:0] lookup_preg  [p_num_fe_lanes][2];
    logic                        lookup_valid [p_num_fe_lanes][2];

    t.test_case_begin( "test_case_2_all_lane_allocate_lookup_no_overlap" );
    if( !t.run_test ) return;

    for( int i = 0; i < p_num_fe_lanes; i++ ) begin

      alloc_areg[i]  = 5'(i + 1);
      alloc_preg[i]  = p_phys_addr_bits'(i + 32);
      alloc_ppreg[i] = p_phys_addr_bits'(i + 1);
      alloc_valid[i] = 1'b1;

      for( int j = 0; j < 2; j++ ) begin
        lookup_areg[i][j]  = 5'(p_num_fe_lanes + (i * 2) + j + 1);
        lookup_preg[i][j]  = p_phys_addr_bits'(p_num_fe_lanes + (i * 2) + j + 1);
        lookup_valid[i][j] = 1'b1;
      end
    end

    fork
      alloc(
        alloc_areg, 
        alloc_preg, 
        alloc_ppreg, 
        alloc_valid
      );

      lookup_new_inst_srcs(
        lookup_areg, 
        lookup_preg, 
        lookup_valid
      );
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_3_all_lane_allocate_lookup_with_overlap
  //----------------------------------------------------------------------

  task test_case_3_all_lane_allocate_lookup_with_overlap();
    automatic int urandom_res;

    logic                  [4:0] alloc_areg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes];
    logic                        alloc_valid [p_num_fe_lanes];

    logic                  [4:0] lookup_areg  [p_num_fe_lanes][2];
    logic [p_phys_addr_bits-1:0] lookup_preg  [p_num_fe_lanes][2];
    logic                        lookup_valid [p_num_fe_lanes][2];

    t.test_case_begin( "test_case_3_all_lane_allocate_lookup_with_overlap" );
    if( !t.run_test ) return;

    // Only do test if more than one fe lane
    if( p_num_fe_lanes > 1 ) begin
      for( int i = 0; i < p_num_fe_lanes; i++ ) begin

        // First lane allocates a register that the second lane looks up to
        // create an overlap scenario
        // add x1 x2 x3
        // add x5 x1 x1
        if( i < 2 ) begin
          alloc_areg[i]  = i == 0 ? 5'(1) : 5'(5);
          alloc_preg[i]  = p_phys_addr_bits'(i + 32);
          alloc_ppreg[i] = i == 0 ? p_phys_addr_bits'(1) : p_phys_addr_bits'(5);
          alloc_valid[i] = 1'b1;

          lookup_areg[i][0]  = i == 0 ? 5'(2) : 5'(1);
          lookup_preg[i][0]  = i == 0 ? p_phys_addr_bits'(2) : p_phys_addr_bits'(32);
          lookup_valid[i][0] = 1'b1;

          lookup_areg[i][1]  = i == 0 ? 5'(3) : 5'(1);
          lookup_preg[i][1]  = i == 0 ? p_phys_addr_bits'(3) : p_phys_addr_bits'(32);
          lookup_valid[i][1] = 1'b1;
        end else begin
          alloc_areg[i]  = 5'(0);
          alloc_preg[i]  = p_phys_addr_bits'(0);
          alloc_ppreg[i] = p_phys_addr_bits'(0);
          alloc_valid[i] = 1'b0;
          
          for( int j = 0; j < 2; j++ ) begin
            lookup_areg[i][j]  = 5'(0);
            lookup_preg[i][j]  = p_phys_addr_bits'(0);
            lookup_valid[i][j] = 1'b0;
          end
        end
      end

      fork
        alloc(
          alloc_areg, 
          alloc_preg, 
          alloc_ppreg, 
          alloc_valid
        );

        lookup_new_inst_srcs(
          lookup_areg, 
          lookup_preg, 
          lookup_valid
        );
      join
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_4_some_lane_allocate_lookup_with_overlap
  //----------------------------------------------------------------------

  task test_case_4_some_lane_allocate_lookup_with_overlap();
    automatic int urandom_res;

    logic                  [4:0] alloc_areg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes];
    logic                        alloc_valid [p_num_fe_lanes];

    logic                  [4:0] lookup_areg  [p_num_fe_lanes][2];
    logic [p_phys_addr_bits-1:0] lookup_preg  [p_num_fe_lanes][2];
    logic                        lookup_valid [p_num_fe_lanes][2];

    t.test_case_begin( "test_case_4_some_lane_allocate_lookup_with_overlap" );
    if( !t.run_test ) return;

    // Only do test if more than two fe lanes
    if( p_num_fe_lanes > 2 ) begin
      for( int i = 0; i < p_num_fe_lanes; i++ ) begin

        // First lane allocates a register that the second lane looks up to
        // create an overlap scenario
        // add x3 x0 x1
        // add x1 x2 x3
        // add x5 x1 x1
        // invalid
        if( i == 0 ) begin
          alloc_areg[i] = 5'(3);
          alloc_preg[i] = p_phys_addr_bits'(32);
          alloc_ppreg[i] = p_phys_addr_bits'(3);
          alloc_valid[i] = 1'b1;

          lookup_areg[i][0]  = 5'(0);
          lookup_preg[i][0]  = p_phys_addr_bits'(0);
          lookup_valid[i][0] = 1'b1;

          lookup_areg[i][1]  = 5'(1);
          lookup_preg[i][1]  = p_phys_addr_bits'(1);
          lookup_valid[i][1] = 1'b1;
        end else if( i == 1 ) begin
          alloc_areg[i]  = 5'(1);
          alloc_preg[i]  = p_phys_addr_bits'(33);
          alloc_ppreg[i] = p_phys_addr_bits'(1);
          alloc_valid[i] = 1'b1;

          lookup_areg[i][0]  = 5'(2);
          lookup_preg[i][0]  = p_phys_addr_bits'(2);
          lookup_valid[i][0] = 1'b1;

          lookup_areg[i][1]  = 5'(3);
          lookup_preg[i][1]  = p_phys_addr_bits'(32);
          lookup_valid[i][1] = 1'b1;
        end else if( i == 2) begin
          alloc_areg[i]  = 5'(5);
          alloc_preg[i]  = p_phys_addr_bits'(34);
          alloc_ppreg[i] = p_phys_addr_bits'(5);
          alloc_valid[i] = 1'b1;

          lookup_areg[i][0]  = 5'(1);
          lookup_preg[i][0]  = p_phys_addr_bits'(33);
          lookup_valid[i][0] = 1'b1;

          lookup_areg[i][1]  = 5'(1);
          lookup_preg[i][1]  = p_phys_addr_bits'(33);
          lookup_valid[i][1] = 1'b1;
        end else begin
          alloc_areg[i]  = 5'(0);
          alloc_preg[i]  = p_phys_addr_bits'(0);
          alloc_ppreg[i] = p_phys_addr_bits'(0);
          alloc_valid[i] = 1'b0;
          
          for( int j = 0; j < 2; j++ ) begin
            lookup_areg[i][j]  = 5'(0);
            lookup_preg[i][j]  = p_phys_addr_bits'(0);
            lookup_valid[i][j] = 1'b0;
          end
        end
      end

      fork
        alloc(
          alloc_areg, 
          alloc_preg, 
          alloc_ppreg, 
          alloc_valid
        );

        lookup_new_inst_srcs(
          lookup_areg, 
          lookup_preg, 
          lookup_valid
        );
      join
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_5_iq_lookup
  //----------------------------------------------------------------------

  task test_case_5_iq_lookup();
    logic                  [4:0] alloc_areg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes];
    logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes];
    logic                        alloc_valid [p_num_fe_lanes];

    logic [p_phys_addr_bits-1:0] iq_lookup_preg [p_num_lookup_ports][2];
    logic                        iq_pending     [p_num_lookup_ports][2];
    logic                        iq_valid       [p_num_lookup_ports][2];

    t_complete_msg compl_preg [p_num_be_lanes];
    logic          compl_val  [p_num_be_lanes];

    t.test_case_begin( "test_case_5_iq_lookup" );
    if( !t.run_test ) return;

    // ---- Verify initial state: pregs are not pending ----
    for( int j = 0; j < p_num_lookup_ports; j++ ) begin
      iq_lookup_preg[j][0] = p_phys_addr_bits'(j * 2 + 1);
      iq_lookup_preg[j][1] = p_phys_addr_bits'(j * 2 + 2);
      iq_pending[j][0]     = 1'b0;
      iq_pending[j][1]     = 1'b0;
      iq_valid[j][0]       = 1'b1;
      iq_valid[j][1]       = 1'b1;
    end
    lookup_iq_srcs( iq_lookup_preg, iq_pending, iq_valid );

    // ---- Allocate areg 1 on lane 0: areg 1 -> preg 32 (pending) ----
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      alloc_areg[i]  = i == 0 ? 5'd1 : 5'd0;
      alloc_preg[i]  = i == 0 ? p_phys_addr_bits'(32) : p_phys_addr_bits'(0);
      alloc_ppreg[i] = i == 0 ? p_phys_addr_bits'(1) : p_phys_addr_bits'(0);
      alloc_valid[i] = i == 0;
    end
    alloc( alloc_areg, alloc_preg, alloc_ppreg, alloc_valid );

    // ---- Look up preg 32 (pending) and preg 0 (never pending) on all ports ----
    for( int j = 0; j < p_num_lookup_ports; j++ ) begin
      iq_lookup_preg[j][0] = p_phys_addr_bits'(32);
      iq_lookup_preg[j][1] = p_phys_addr_bits'(0);
      iq_pending[j][0]     = 1'b1;
      iq_pending[j][1]     = 1'b0;
      iq_valid[j][0]       = 1'b1;
      iq_valid[j][1]       = 1'b1;
    end
    lookup_iq_srcs( iq_lookup_preg, iq_pending, iq_valid );

    // ---- Look up preg 32 (pending) and preg 2 (not pending) on all ports ----
    for( int j = 0; j < p_num_lookup_ports; j++ ) begin
      iq_lookup_preg[j][0] = p_phys_addr_bits'(32);
      iq_lookup_preg[j][1] = p_phys_addr_bits'(2);
      iq_pending[j][0]     = 1'b1;
      iq_pending[j][1]     = 1'b0;
      iq_valid[j][0]       = 1'b1;
      iq_valid[j][1]       = 1'b1;
    end
    lookup_iq_srcs( iq_lookup_preg, iq_pending, iq_valid );

    // ---- Complete preg 32 ----
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      compl_preg[j] = j == 0 ? p_phys_addr_bits'(32) : 'x;
      compl_val[j]  = j == 0;
    end
    complete( compl_preg, compl_val );

    // ---- Look up preg 32 (no longer pending) and preg 2 (not pending) ----
    for( int j = 0; j < p_num_lookup_ports; j++ ) begin
      iq_lookup_preg[j][0] = p_phys_addr_bits'(32);
      iq_lookup_preg[j][1] = p_phys_addr_bits'(2);
      iq_pending[j][0]     = 1'b0;
      iq_pending[j][1]     = 1'b0;
      iq_valid[j][0]       = 1'b1;
      iq_valid[j][1]       = 1'b1;
    end
    lookup_iq_srcs( iq_lookup_preg, iq_pending, iq_valid );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_1_single_lane_allocate_lookup();
    test_case_2_all_lane_allocate_lookup_no_overlap();
    test_case_3_all_lane_allocate_lookup_with_overlap();
    test_case_4_some_lane_allocate_lookup_with_overlap();
    test_case_5_iq_lookup();
  endtask
endmodule

//========================================================================
// SSRenameTableL3_test
//========================================================================

module SSRenameTableL3_test;

  // Defaults (2 fe lanes, 2 be lanes, 2 lookup ports)
  SSRenameTableL3TestSuite #(
    .p_suite_num        (1)
  ) suite_1();

  // 1 fe lane, 1 be lane, 2 lookup ports
  SSRenameTableL3TestSuite #(
    .p_suite_num        (2),
    .p_num_fe_lanes     (1),
    .p_num_be_lanes     (1)
  ) suite_2();

  // 2 fe lanes, 2 be lanes, 4 lookup ports
  SSRenameTableL3TestSuite #(
    .p_suite_num        (3),
    .p_num_lookup_ports (4)
  ) suite_3();

  // 4 fe lanes, 4 be lanes, 4 lookup ports
  SSRenameTableL3TestSuite #(
    .p_suite_num        (4),
    .p_num_fe_lanes     (4),
    .p_num_be_lanes     (4),
    .p_num_lookup_ports (4)
  ) suite_4();

  // 1 fe lane, 4 be lanes, 4 lookup ports
  SSRenameTableL3TestSuite #(
    .p_suite_num        (5),
    .p_num_fe_lanes     (1),
    .p_num_be_lanes     (4),
    .p_num_lookup_ports (4)
  ) suite_5();

  // 4 fe lanes, 1 be lane, 4 lookup ports
  SSRenameTableL3TestSuite #(
    .p_suite_num        (6),
    .p_num_fe_lanes     (4),
    .p_num_be_lanes     (1),
    .p_num_lookup_ports (4)
  ) suite_6();

  // 4 fe lanes, 4 be lanes, 1 lookup port
  SSRenameTableL3TestSuite #(
    .p_suite_num        (7),
    .p_num_fe_lanes     (4),
    .p_num_be_lanes     (4),
    .p_num_lookup_ports (1)
  ) suite_7();

  // 2 fe lanes, 2 be lanes, 4 lookup ports
  SSRenameTableL3TestSuite #(
    .p_suite_num        (8),
    .p_num_lookup_ports (4),
    .p_num_phys_regs    (33)
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
