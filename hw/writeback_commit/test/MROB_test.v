//========================================================================
// MROB_test.v
//========================================================================
// A testbench for our MROB

`include "hw/writeback_commit/MROB.v"
`include "test/fl/TestMCaller.v"
`include "test/TestUtils.v"

import TestEnv::*;

//========================================================================
// MROBTestSuite
//========================================================================
// A test suite for the MROB

module MROBTestSuite #(
  parameter p_suite_num = 0,
  parameter p_msg_bits  = 32,
  parameter p_depth     = 4,
  parameter p_num_lanes = 2
);

  localparam p_addr_bits = $clog2( p_depth );
  
  string suite_name = $sformatf("%0d: MROBTestSuite_%d_%0d", 
                                p_suite_num, p_msg_bits, p_depth);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  logic [p_addr_bits-1:0] dut_ins_idx     [p_num_lanes];
  logic [ p_msg_bits-1:0] dut_ins_msg     [p_num_lanes];
  logic                   dut_ins_msg_val [p_num_lanes];
  logic                   dut_ins_rdy;
  logic                   dut_ins_en;
  logic [p_addr_bits:0]   dut_avail_slots;

  logic [p_addr_bits-1:0] dut_deq_idx     [p_num_lanes];
  logic [ p_msg_bits-1:0] dut_deq_msg     [p_num_lanes];
  logic                   dut_deq_msg_val [p_num_lanes];
  logic                   dut_deq_en;
  logic                   dut_deq_rdy;

  MROB #(
    .p_msg_bits  (p_msg_bits),
    .p_depth     (p_depth),
    .p_num_lanes (p_num_lanes)
  ) dut (
    .clk     (clk),
    .rst     (rst),
    
    .ins_idx     (dut_ins_idx),
    .ins_msg     (dut_ins_msg),
    .ins_msg_val (dut_ins_msg_val),
    .ins_en      (dut_ins_en),
    .ins_rdy     (dut_ins_rdy),
    .avail_slots (dut_avail_slots),

    .deq_idx     (dut_deq_idx),
    .deq_msg     (dut_deq_msg),
    .deq_msg_val (dut_deq_msg_val),
    .deq_en      (dut_deq_en),
    .deq_rdy     (dut_deq_rdy)
  );

  //----------------------------------------------------------------------
  // Insertion
  //----------------------------------------------------------------------

  // Veri..ator does not like unpacked arrays in structs, we need to use
  // the TestMCaller instead of TestCaller for compatibility
  typedef struct packed {
    logic [ p_msg_bits-1:0] msg;
    logic [p_addr_bits-1:0] idx;
    logic                   val;
  } t_ins_msg;

  t_ins_msg ins_msg [p_num_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_lanes; i++ ) begin : GEN_INS_MSG
      assign dut_ins_msg[i]     = ins_msg[i].msg;
      assign dut_ins_idx[i]     = ins_msg[i].idx;
      assign dut_ins_msg_val[i] = ins_msg[i].val;
    end
  endgenerate

  // Unused output message
  logic unused_dut_ins_output [p_num_lanes];
  generate
    for( i = 0; i < p_num_lanes; i++ )
      assign unused_dut_ins_output[i] = 1'b1;
  endgenerate

  TestMCaller #(
    .t_call_msg (t_ins_msg),
    .t_ret_msg  (logic),
    .p_num_msgs (p_num_lanes)
  ) ins_caller (
    .call_msg (ins_msg),
    .ret_msg  (unused_dut_ins_output),
    .en       (dut_ins_en),
    .rdy      (dut_ins_rdy),
    .*
  );

  t_ins_msg msg_to_send [p_num_lanes];

  task send(
    logic [ p_msg_bits-1:0] msg [p_num_lanes],
    logic [p_addr_bits-1:0] idx [p_num_lanes],
    logic                   val [p_num_lanes]
  );
    for( int i = 0; i < p_num_lanes; i++ ) begin
      msg_to_send[i].msg = msg[i];
      msg_to_send[i].idx = idx[i];
      msg_to_send[i].val = val[i];
    end

    ins_caller.call(msg_to_send, unused_dut_ins_output, '{default: 1'b0});
  endtask

  //----------------------------------------------------------------------
  // Dequeue
  //----------------------------------------------------------------------

  // Veri..ator does not like unpacked arrays in structs, we need to use
  // the TestMCaller instead of TestCaller for compatibility
  typedef struct packed {
    logic [ p_msg_bits-1:0] msg;
    logic [p_addr_bits-1:0] idx;
    logic                   val;
  } t_deq_msg;

  t_deq_msg deq_msg [p_num_lanes];

  generate
    for( i = 0; i < p_num_lanes; i++ ) begin : GEN_DEQ_MSG
      assign deq_msg[i].msg = dut_deq_msg[i];
      assign deq_msg[i].idx = dut_deq_idx[i];
      assign deq_msg[i].val = dut_deq_msg_val[i];
    end
  endgenerate

  // Unused input message
  logic unused_dut_deq_input [p_num_lanes];

  TestMCaller #(
    .t_call_msg (logic), 
    .t_ret_msg  (t_deq_msg),
    .p_num_msgs (p_num_lanes)
  ) deq_caller (
    .call_msg (unused_dut_deq_input),
    .ret_msg  (deq_msg),
    .en       (dut_deq_en),
    .rdy      (dut_deq_rdy),
    .*
  );

  t_deq_msg msg_to_recv [p_num_lanes];

  task recv(
    input logic [ p_msg_bits-1:0] msg [p_num_lanes],
    input logic [p_addr_bits-1:0] idx [p_num_lanes],
    input logic                   val [p_num_lanes]
  );
    for( int i = 0; i < p_num_lanes; i++ ) begin
      msg_to_recv[i].msg = msg[i];
      msg_to_recv[i].idx = idx[i];
      msg_to_recv[i].val = val[i];
    end

    deq_caller.call('{default: 1'bx}, msg_to_recv, val);
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    trace = "";

    trace = {trace, ins_caller.trace( t.trace_level )};
    trace = {trace, " | "};
    trace = {trace, dut.trace( t.trace_level )};
    trace = {trace, " | "};
    trace = {trace, deq_caller.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // test_case_basic
  //----------------------------------------------------------------------
  // Enqueuing a message to the MROB should also dequeue that message if
  // the indices are in-order

  task test_case_basic();
    t.test_case_begin( "test_case_basic" );
    if( !t.run_test ) return;

    fork
        //    msg                      idx                   val
      begin
        send( '{0:'hdead, default:'x}, '{0:'d0, default:'x}, '{0:'1, default:'0} );
      end
      begin
        recv( '{0:'hdead, default:'x}, '{0:'d0, default:'x}, '{0:'1, default:'0} );
      end
    join

    fork
        //    msg                                idx             val
      begin
        send( '{0:'h1111, 1:'h2222, default:'x}, '{0:'d1, 1:'d2, default:'x}, '{0:'1, 1:'1, default:'0} );
      end
      begin
        recv( '{0:'h1111, 1:'h2222, default:'x}, '{0:'d1, 1:'d2, default:'x}, '{0:'1, 1:'1, default:'0} );
      end
    join

    fork
        //    msg                      idx                   val
      begin
        send( '{0:'h1234, default:'x}, '{0:'d3, default:'x}, '{0:'1, default:'0} );
      end
      begin
        recv( '{0:'h1234, default:'x}, '{0:'d3, default:'x}, '{0:'1, default:'0} );
      end
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_capacity
  //----------------------------------------------------------------------
  // Enqueuing messages (to reach capacity) in-order should yield
  // dequeuing of those messages in the same order

  logic [ p_msg_bits-1:0] test_cap_msg [p_num_lanes];
  logic [p_addr_bits-1:0] test_cap_idx [p_num_lanes];
  logic                   test_cap_val [p_num_lanes];

  task test_case_capacity();
    t.test_case_begin( "test_case_capacity" );
    if( !t.run_test ) return;

    for( int i = 0; i < p_depth; i = i + p_num_lanes ) begin
      // Enqueue using all lanes
      for( int j = 0; j < p_num_lanes; j = j + 1 ) begin
        test_cap_msg[j] = p_msg_bits'(i+j);
        test_cap_idx[j] = p_addr_bits'(i+j);
        // Do not overwrite an instruction that has already been written
        test_cap_val[j] = ( (i+j) < p_depth );
      end
      send( test_cap_msg, test_cap_idx, test_cap_val );
    end

    for( int i = 0; i < p_depth; i = i + p_num_lanes ) begin
      // Dequeue using all lanes
      for( int j = 0; j < p_num_lanes; j = j + 1 ) begin
        test_cap_msg[j] = p_msg_bits'(i+j);
        test_cap_idx[j] = p_addr_bits'(i+j);
        test_cap_val[j] = ( (i+j) < p_depth );
      end
      recv( test_cap_msg, test_cap_idx, test_cap_val );
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_out_of_order
  //----------------------------------------------------------------------
  // Enqueuing a number of messages out-of-order should result with 
  // dequeuing of the same messages in-order

  logic [ p_msg_bits-1:0] test_ooo_enq_msg [4];

  logic [ p_msg_bits-1:0] test_ooo_deq_msg [p_num_lanes];
  logic [p_addr_bits-1:0] test_ooo_deq_idx [p_num_lanes];
  logic                   test_ooo_deq_val [p_num_lanes];

  task test_case_out_of_order();
    t.test_case_begin( "test_case_out_of_order" );
    if( !t.run_test ) return;

    test_ooo_enq_msg[0] = 'h1234;
    test_ooo_enq_msg[1] = 'h8765;
    test_ooo_enq_msg[2] = 'h0000;
    test_ooo_enq_msg[3] = 'hFFFF;

    fork
      begin
        //    msg                                                          idx                          val
        send( '{0:test_ooo_enq_msg[3],                        default:'x}, '{0:'d3,        default:'x}, '{0:'1,       default:'0} );
        send( '{0:test_ooo_enq_msg[1],                        default:'x}, '{0:'d1,        default:'x}, '{0:'1,       default:'0} );
        send( '{0:test_ooo_enq_msg[2], 1:test_ooo_enq_msg[0], default:'x}, '{0:'d2, 1:'d0, default:'x}, '{0:'1, 1:'1, default:'0} );
      end

      begin
        for( int i = 0; i < 4; i = i + p_num_lanes ) begin
          // Must dequeue using all lanes
          for( int j = 0; j < p_num_lanes; j = j + 1 ) begin
            test_ooo_deq_msg[j] = test_ooo_enq_msg[(i+j)%4];
            test_ooo_deq_idx[j] = p_addr_bits'(i+j);
            test_ooo_deq_val[j] = ( (i+j) < 4 );
          end
          recv( test_ooo_deq_msg, test_ooo_deq_idx, test_ooo_deq_val );
        end
      end
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_wrap_around
  //----------------------------------------------------------------------
  // Enqueuing until the dequeue pointer reaches the depth of the MROB
  // should result in the dequeue pointer wrapping back around to the 
  // start

  logic [ p_msg_bits-1:0] test_wrap_msg [p_num_lanes];
  logic [p_addr_bits-1:0] test_wrap_idx [p_num_lanes];
  logic                   test_wrap_val [p_num_lanes];

  logic [p_addr_bits-1:0] lane0_addr;
  logic [p_addr_bits-1:0] lane1_addr;

  task test_case_wrap_around();
    t.test_case_begin( "test_case_wrap_around" );
    if( !t.run_test ) return;

    for( int i = 0; i < 10; i = i + 2 ) begin
      //    msg                                                  idx                                                                        val
      send( '{0:p_msg_bits'(i), 1:p_msg_bits'(i+1), default:'x}, '{0:p_addr_bits'((i)%p_depth), 1:p_addr_bits'((i+1)%p_depth), default:'x}, '{0:1, 1:1, default:0} );
      recv( '{0:p_msg_bits'(i), 1:p_msg_bits'(i+1), default:'x}, '{0:p_addr_bits'((i)%p_depth), 1:p_addr_bits'((i+1)%p_depth), default:'x}, '{0:1, 1:1, default:0} );
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_basic();
    test_case_capacity();
    test_case_out_of_order();
    test_case_wrap_around();
  endtask

endmodule

//========================================================================
// MROB_test
//========================================================================

module MROB_test;
  MROBTestSuite #(1)             suite_1();
  MROBTestSuite #(2, 16)         suite_2();
  MROBTestSuite #(3, 32,  6)     suite_3();
  MROBTestSuite #(4, 32,  8,  3) suite_4();
  MROBTestSuite #(5, 32, 16,  4) suite_5();

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
