//========================================================================
// IssueQueueInOrder_test.v
//========================================================================
// A testbench for our IssueQueueInOrder

`include "hw/decode_issue/IssueQueueInOrder.v"
`include "test/fl/TestCaller.v"
`include "test/fl/TestOstream.v"
`include "test/fl/TestMPub.v"
`include "test/TestUtils.v"
`include "test/FLTestUtils.v"

import TestEnv::*;
import UArch::*;

//========================================================================
// IssueQueueInOrderTestSuite
//========================================================================
// A test suite for the IssueQueueInOrder

module IssueQueueInOrderTestSuite #(
  parameter p_suite_num    = 0,
  parameter p_depth        = 4,
  parameter p_num_regs     = 36,
  parameter p_seq_num_bits = 5,
  parameter p_num_lanes    = 2
);

  localparam p_addr_bits       = $clog2( p_num_regs );
  localparam p_entry_bits      = $clog2( p_depth );
  localparam p_phys_addr_bits  = p_addr_bits;
  localparam p_num_be_lanes    = p_num_lanes;
  localparam p_X_recv_intv_delay = 0;
  
  string suite_name = $sformatf("%0d: IssueQueueInOrderTestSuite_%d_%0d_%0d_%0d", 
                                p_suite_num, p_depth, p_num_regs, p_seq_num_bits, p_num_lanes);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  logic [31:0]               dut_ins_msg_pc;
  logic [p_addr_bits-1:0]    dut_ins_msg_preg [2];
  rv_uop                     dut_ins_msg_decoder_uop;
  logic [4:0]                dut_ins_msg_decoder_waddr;
  logic [31:0]               dut_ins_msg_imm;
  logic                      dut_ins_msg_decoder_op2_sel;
  logic                      dut_ins_msg_decoder_op3_sel;
  logic [p_seq_num_bits-1:0] dut_ins_msg_seq_num;
  logic [p_addr_bits-1:0]    dut_ins_msg_alloc_preg;
  logic [p_addr_bits-1:0]    dut_ins_msg_alloc_ppreg;
  logic                      dut_ins_en;
  logic                      dut_ins_rdy;
  logic [p_entry_bits:0]     dut_avail_slots;

  D__XIntf #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_addr_bits)
  ) Ex ();

  logic [p_addr_bits-1:0] dut_rt_lookup_preg    [2];
  logic                   dut_rt_lookup_pending [2];
  logic                   dut_rt_lookup_en      [2];

  logic [p_addr_bits-1:0]  dut_rf_raddr [2];
  logic [31:0]             dut_rf_rdata [2];

  CompleteNotif #(
    .p_phys_addr_bits (p_addr_bits)
  ) complete_notif [p_num_be_lanes] ();

  IssueQueueInOrder #(
    .p_depth        (p_depth),
    .p_num_regs     (p_num_regs),
    .p_seq_num_bits (p_seq_num_bits),
    .p_num_be_lanes (p_num_lanes)
  ) dut (
    .clk     (clk),
    .rst     (rst),

    .ins_msg_pc               (dut_ins_msg_pc),
    .ins_msg_preg             (dut_ins_msg_preg),
    .ins_msg_decoder_uop      (dut_ins_msg_decoder_uop),
    .ins_msg_decoder_waddr    (dut_ins_msg_decoder_waddr),
    .ins_msg_imm              (dut_ins_msg_imm),
    .ins_msg_decoder_op2_sel  (dut_ins_msg_decoder_op2_sel),
    .ins_msg_decoder_op3_sel  (dut_ins_msg_decoder_op3_sel),
    .ins_msg_seq_num          (dut_ins_msg_seq_num),
    .ins_msg_alloc_preg       (dut_ins_msg_alloc_preg),
    .ins_msg_alloc_ppreg      (dut_ins_msg_alloc_ppreg),
    .ins_en                   (dut_ins_en),
    .ins_rdy                  (dut_ins_rdy),
    .avail_slots              (dut_avail_slots),

    .Ex                       (Ex),

    .rt_lookup_preg           (dut_rt_lookup_preg),
    .rt_lookup_pending        (dut_rt_lookup_pending),
    .rt_lookup_en             (dut_rt_lookup_en),

    .rf_raddr                 (dut_rf_raddr),
    .rf_rdata                 (dut_rf_rdata),

    .complete                 (complete_notif)
  );

  //----------------------------------------------------------------------
  // Insertion
  //----------------------------------------------------------------------

  // Veri..ator does not like unpacked arrays in structs, we need to use
  // the TestMCaller instead of TestCaller for compatibility
   typedef struct packed {
    logic [31:0]               pc;
    logic [p_addr_bits-1:0]    preg0;
    logic [p_addr_bits-1:0]    preg1;
    rv_uop                     decoder_uop;
    logic [4:0]                decoder_waddr;
    logic [31:0]               imm;
    logic                      decoder_op2_sel;
    logic                      decoder_op3_sel;
    logic [p_seq_num_bits-1:0] seq_num;
    logic [p_addr_bits-1:0]    alloc_preg;
    logic [p_addr_bits-1:0]    alloc_ppreg;
   } t_ins_msg;

  t_ins_msg ins_msg;

  assign dut_ins_msg_pc               = ins_msg.pc;
  assign dut_ins_msg_preg[0]          = ins_msg.preg0;
  assign dut_ins_msg_preg[1]          = ins_msg.preg1;
  assign dut_ins_msg_decoder_uop      = ins_msg.decoder_uop;
  assign dut_ins_msg_decoder_waddr    = ins_msg.decoder_waddr;
  assign dut_ins_msg_imm              = ins_msg.imm;
  assign dut_ins_msg_decoder_op2_sel  = ins_msg.decoder_op2_sel;
  assign dut_ins_msg_decoder_op3_sel  = ins_msg.decoder_op3_sel;
  assign dut_ins_msg_seq_num          = ins_msg.seq_num;
  assign dut_ins_msg_alloc_preg       = ins_msg.alloc_preg;
  assign dut_ins_msg_alloc_ppreg      = ins_msg.alloc_ppreg;

  // Unused output message
  logic unused_dut_ins_output;
  assign unused_dut_ins_output = 1'b1;

  TestCaller #(
    .t_call_msg (t_ins_msg),
    .t_ret_msg  (logic)
  ) ins_caller (
    .call_msg (ins_msg),
    .ret_msg  (unused_dut_ins_output),
    .en       (dut_ins_en),
    .rdy      (dut_ins_rdy),
    .*
  );

  t_ins_msg msg_to_send;

  task send(
    logic [31:0]               pc,
    logic [p_addr_bits-1:0]    preg0,
    logic [p_addr_bits-1:0]    preg1,
    rv_uop                     decoder_uop,
    logic [4:0]                decoder_waddr,
    logic [31:0]               imm,
    logic                      decoder_op2_sel,
    logic                      decoder_op3_sel,
    logic [p_seq_num_bits-1:0] seq_num,
    logic [p_addr_bits-1:0]    alloc_preg,
    logic [p_addr_bits-1:0]    alloc_ppreg
  );
    msg_to_send.pc               = pc;
    msg_to_send.preg0            = preg0;
    msg_to_send.preg1            = preg1;
    msg_to_send.decoder_uop      = decoder_uop;
    msg_to_send.decoder_waddr    = decoder_waddr;
    msg_to_send.imm              = imm;
    msg_to_send.decoder_op2_sel  = decoder_op2_sel;
    msg_to_send.decoder_op3_sel  = decoder_op3_sel;
    msg_to_send.seq_num          = seq_num;
    msg_to_send.alloc_preg       = alloc_preg;
    msg_to_send.alloc_ppreg      = alloc_ppreg;

    ins_caller.call(msg_to_send, 1'b1);
  endtask

  //----------------------------------------------------------------------
  // Dequeue
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

  t_d__x_msg d__x_msg;

  assign d__x_msg.pc      = Ex.pc;
  assign d__x_msg.seq_num = Ex.seq_num;
  assign d__x_msg.op1     = Ex.op1;
  assign d__x_msg.op2     = Ex.op2;
  assign d__x_msg.waddr   = Ex.waddr;
  assign d__x_msg.uop     = Ex.uop;
  assign d__x_msg.preg    = Ex.preg;
  assign d__x_msg.ppreg   = Ex.ppreg;

  TestOstream #( t_d__x_msg, p_X_recv_intv_delay ) X_Ostream (
    .msg (d__x_msg),
    .val (Ex.val),
    .rdy (Ex.rdy),
    .*
  );

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

  genvar i;
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
  // Rename Table Blackbox
  //----------------------------------------------------------------------
  // Reference model: tracks pending status for each physical register.
  // Initialized with all regs ready (not pending). The always_comb responds
  // combinationally to whatever preg the DUT is currently looking up.

  logic rt_ref_pending [p_num_regs-1:0];

  initial begin
    for (int i = 0; i < p_num_regs; i++) begin
      rt_ref_pending[i] = 1'b0;
    end
  end

  // Drive pending by indexing the reference table with the DUT's preg
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      dut_rt_lookup_pending[i] = rt_ref_pending[dut_rt_lookup_preg[i]];
    end
  end

  // Set pending status for a single physical register
  task rt_set_pending(
    input logic [p_addr_bits-1:0] preg,
    input logic                   pending
  );
    rt_ref_pending[preg] = pending;
  endtask

  // Reset reference table back to all ready
  task rt_reset();
    for (int i = 0; i < p_num_regs; i++) begin
      rt_ref_pending[i] = 1'b0;
    end
  endtask

  // Check DUT lookup outputs against expected preg/en values.
  // Only checks preg when the corresponding en is expected high.
  task rt_check(
    input logic [p_addr_bits-1:0] exp_preg [2],
    input logic                   exp_en   [2]
  );
    for (int i = 0; i < 2; i++) begin
      `CHECK_EQ(dut_rt_lookup_en[i], exp_en[i]);
      if (exp_en[i]) begin
        `CHECK_EQ(dut_rt_lookup_preg[i], exp_preg[i]);
      end
    end
  endtask

  //----------------------------------------------------------------------
  // Register File Blackbox
  //----------------------------------------------------------------------
  // Reference model: maps each physical register address -> data.
  // Initialized to zero.  Responds combinationally to the DUT's read
  // addresses.

  logic [31:0] rf_ref_rdata [p_num_regs-1:1];

  initial begin
    for (int i = 1; i <= p_num_regs; i++) begin
      rf_ref_rdata[i] = '0;
    end
  end

  // Drive rdata by indexing the reference regfile with the DUT's raddr
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      dut_rf_rdata[i] = rf_ref_rdata[dut_rf_raddr[i]];
    end
  end

  // Set a single register file entry
  task rf_set(
    input logic [p_addr_bits-1:0]  addr,
    input logic [31:0] data
  );
    rf_ref_rdata[addr] = data;
  endtask

  // Reset reference regfile back to all zeros
  task rf_reset();
    for (int i = 1; i <= p_num_regs; i++) begin
      rf_ref_rdata[i] = '0;
    end
  endtask

  // Check DUT register file read addresses against expected values
  task rf_check(
    input logic [p_addr_bits-1:0] exp_raddr [2]
  );
    for (int i = 0; i < 2; i++) begin
      `CHECK_EQ(dut_rf_raddr[i], exp_raddr[i]);
    end
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    trace = "";

    // trace = {trace, ins_caller.trace( t.trace_level )};
    // trace = {trace, " | "};
    // trace = {trace, dut.trace( t.trace_level )};
    // trace = {trace, " | "};
    // trace = {trace, X_Ostream.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // test_case_basic
  //----------------------------------------------------------------------

  task test_case_basic();
    t.test_case_begin( "test_case_basic" );
    if( !t.run_test ) return;

    // -----------------------------------------------------------------
    // Test 1: ADD, both sources ready, op1 and op2 from regfile
    //   rename table: all pregs ready (default)
    //   regfile[3] = 2, regfile[7] = 1
    // -----------------------------------------------------------------

    rf_set( 3, 32'd2 );
    rf_set( 7, 32'd1 );

    fork
      begin
        //        pc      preg0 preg1 uop    waddr imm   op2s op3s seq  preg ppreg
        send( 32'h200, 6'd3, 6'd7, OP_ADD, 5'd5, 32'd0, 1'b0, 1'b0, 5'd0, 6'd8, 6'd3 );
      end
      begin
        X_Ostream.recv( '{
          pc:      32'h200,
          seq_num: 5'd0,
          op1:     32'd2,
          op2:     32'd1,
          waddr:   5'd5,
          preg:    6'd8,
          ppreg:   6'd3,
          uop:     OP_ADD
        } );
      end
    join

    // -----------------------------------------------------------------
    // Test 2: ADD with op2 from immediate (ADDI-like)
    //   op1 = regfile[3] = 2, op2 = imm = 10
    // -----------------------------------------------------------------

    fork
      begin
        send( 32'h204, 6'd3, 6'd0, OP_ADD, 5'd6, 32'd10, 1'b1, 1'b0, 5'd1, 6'd9, 6'd5 );
      end
      begin
        X_Ostream.recv( '{
          pc:      32'h204,
          seq_num: 5'd1,
          op1:     32'd2,
          op2:     32'd10,
          waddr:   5'd6,
          preg:    6'd9,
          ppreg:   6'd5,
          uop:     OP_ADD
        } );
      end
    join

    // -----------------------------------------------------------------
    // Test 3: Source pending, woken by clearing pending in rename table
    //   preg 12 is pending;  regfile[12] = 3
    //   preg  7 is ready;    regfile[7]  = 1
    //   Instruction stalls until pending is cleared.
    // -----------------------------------------------------------------

    rt_set_pending( 6'd12, 1'b1 );
    rf_set( 12, 32'd3 );

    fork
      begin
        send( 32'h208, 6'd12, 6'd7, OP_ADD, 5'd4, 32'd0, 1'b0, 1'b0, 5'd2, 6'd10, 6'd6 );
      end
      begin
        // Wait for insert to land, then clear pending
        repeat( 3 ) @( posedge clk );
        #1;
        rt_set_pending( 6'd12, 1'b0 );
      end
      begin
        X_Ostream.recv( '{
          pc:      32'h208,
          seq_num: 5'd2,
          op1:     32'd3,
          op2:     32'd1,
          waddr:   5'd4,
          preg:    6'd10,
          ppreg:   6'd6,
          uop:     OP_ADD
        } );
      end
    join

    // -----------------------------------------------------------------
    // Test 4: Source pending, woken by clearing pending via completion
    //   preg 12 is pending (re-set);  regfile[12] = 3
    //   Completion on lane 0 for preg 12, then clear pending.
    // -----------------------------------------------------------------

    rt_set_pending( 6'd12, 1'b1 );

    fork
      begin
        send( 32'h20c, 6'd12, 6'd7, OP_ADD, 5'd2, 32'd0, 1'b0, 1'b0, 5'd3, 6'd11, 6'd7 );
      end
      begin
        // Wait for insert, then fire completion for preg 12 and clear pending
        repeat( 3 ) @( posedge clk );
        #1;
        complete(
          '{5'd3,  5'dx},     // seq_num [p_num_be_lanes]
          '{5'd3,  5'dx},     // waddr   [p_num_be_lanes]
          '{32'h0, 32'hx},   // wdata   [p_num_be_lanes]
          '{1'b1,  1'b0},     // wen     [p_num_be_lanes]
          '{6'd12, 6'dx},     // preg    [p_num_be_lanes]
          '{1'b1,  1'b0}      // val     [p_num_be_lanes]
        );
        rt_set_pending( 6'd12, 1'b0 );
      end
      begin
        X_Ostream.recv( '{
          pc:      32'h20c,
          seq_num: 5'd3,
          op1:     32'd3,
          op2:     32'd1,
          waddr:   5'd2,
          preg:    6'd11,
          ppreg:   6'd7,
          uop:     OP_ADD
        } );
      end
    join

    rt_reset();
    rf_reset();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_basic();
  endtask

endmodule

//========================================================================
// IssueQueueInOrder_test
//========================================================================

module IssueQueueInOrder_test;
  IssueQueueInOrderTestSuite #(1) suite_1();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();

    test_bench_end();
  end
endmodule
