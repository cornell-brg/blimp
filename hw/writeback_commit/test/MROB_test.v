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

  task test_case_basic();
    t.test_case_begin( "test_case_basic" );
    if( !t.run_test ) return;

    fork
        //    msg                idx        val
      begin
        send( '{'hdeadbeef, 'x}, '{'d0, 'x}, '{'1, '0} );
      end
      begin
        recv( '{'hdeadbeef, 'x}, '{'d0, 'x}, '{'1, '0} );
      end
    join

    fork
        //    msg                        idx          val
      begin
        send( '{'hdeadbeef, 'hfeebdaed}, '{'d1, 'd2}, '{'1, '1} );
      end
      begin
        recv( '{'hdeadbeef, 'hfeebdaed}, '{'d1, 'd2}, '{'1, '1} );
      end
    join

    fork
        //    msg                idx        val
      begin
        send( '{'h01234567, 'x}, '{'d3, 'x}, '{'1, '0} );
      end
      begin
        recv( '{'h01234567, 'x}, '{'d3, 'x}, '{'1, '0} );
      end
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_capacity
  //----------------------------------------------------------------------

  task test_case_capacity();
    t.test_case_begin( "test_case_capacity" );
    if( !t.run_test ) return;

    for( int i = 0; i < p_depth; i = i + 2 ) begin
      send( '{p_msg_bits'(i), p_msg_bits'(i+1)}, '{p_addr_bits'(i), p_addr_bits'(i+1)}, '{1, 1} );
    end

    for( int i = 0; i < p_depth; i = i + 2 ) begin
      recv( '{p_msg_bits'(i), p_msg_bits'(i+1)}, '{p_addr_bits'(i), p_addr_bits'(i+1)}, '{1, 1} );
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_out_of_order
  //----------------------------------------------------------------------

  task test_case_out_of_order();
    t.test_case_begin( "test_case_out_of_order" );
    if( !t.run_test ) return;

    fork
      begin
        //   msg                        idx          val
        send('{'hFFFFFFFF, 'x},         '{'d3, 'x},  '{'1, '0});
        send('{'h87654321, 'x},         '{'d1, 'x},  '{'1, '0});
        send('{'h00000000, 'h12345678}, '{'d2, 'd0}, '{'1, '1});
      end

      begin
        //   msg                        idx          val
        recv('{'h12345678, 'h87654321}, '{'d0, 'd1}, '{'1, '1});
        recv('{'h00000000, 'hFFFFFFFF}, '{'d2, 'd3}, '{'1, '1});
      end
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_wrap_around
  //----------------------------------------------------------------------

  task test_case_wrap_around();
    t.test_case_begin( "test_case_wrap_around" );
    if( !t.run_test ) return;

    //   msg                        idx           val
    send('{'h11111111, 'h22222222}, '{'d0, 'd1},  '{'1, '1});
    send('{'h33333333, 'x},         '{'d2, 'x},   '{'1, '0});
    recv('{'h11111111, 'h22222222}, '{'d0, 'd1},  '{'1, '1});
    recv('{'h33333333, 'x},         '{'d2, 'x},   '{'1, '0});
    send('{'h44444444, 'h55555555}, '{'d3, 'd0},  '{'1, '1});
    recv('{'h44444444, 'h55555555}, '{'d3, 'd0},  '{'1, '1});

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
  MROBTestSuite #(1) suite_1();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();

    test_bench_end();
  end
endmodule
