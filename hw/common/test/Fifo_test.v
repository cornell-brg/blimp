//========================================================================
// Fifo_test.v
//========================================================================
// A testbench for our general-purpose FIFO

`include "test/TestUtils.v"
`include "hw/common/Fifo.v"

import TestEnv::*;

//========================================================================
// FifoTestSuite
//========================================================================
// A test suite for a particular parametrization of the FIFO

module FifoTestSuite #(
  parameter p_suite_num  = 0,
  parameter p_entry_bits = 32,
  parameter p_depth      = 32
);
  string suite_name = $sformatf("%0d: FifoTestSuite_%d_%0d", p_suite_num,
                                p_entry_bits, p_depth);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  logic                    dut_rst;
  logic                    dut_push;
  logic                    dut_pop;
  logic                    dut_empty;
  logic                    dut_full;
  logic [p_entry_bits-1:0] dut_wdata;
  logic [p_entry_bits-1:0] dut_rdata;

  Fifo #(
    .p_entry_bits (p_entry_bits),
    .p_depth      (p_depth)
  ) DUT (
    .clk   (clk),
    .rst   (rst | dut_rst),
    .clear (1'b0),
    .push  (dut_push),
    .pop   (dut_pop),
    .empty (dut_empty),
    .full  (dut_full),
    .wdata (dut_wdata),
    .rdata (dut_rdata)
  );

  //----------------------------------------------------------------------
  // check
  //----------------------------------------------------------------------
  // All tasks start at #1 after the rising edge of the clock. So we
  // write the inputs #1 after the rising edge, and check the outputs #1
  // before the next rising edge.

  task check (
    input logic                    _rst,
    input logic                    push,
    input logic                    pop,
    input logic                    empty,
    input logic                    full,
    input logic [p_entry_bits-1:0] wdata,
    input logic [p_entry_bits-1:0] rdata,

    input int     check_rdata = 1
  );
    if ( !t.failed ) begin
      dut_rst   = _rst;
      dut_push  = push;
      dut_pop   = pop;
      dut_wdata = wdata;

      #8;

      if ( t.verbose ) begin
        $display( "%3d: %b %b %b %p > %b %b %p", t.cycles,
                  dut_rst, dut_push, dut_pop, dut_wdata, 
                  dut_empty, dut_full, dut_rdata );
      end

      `CHECK_EQ( dut_empty, empty );
      `CHECK_EQ( dut_full,  full  );
      if( check_rdata == 1 )
        `CHECK_EQ( dut_rdata, rdata );

      #2;

    end
  endtask

  //----------------------------------------------------------------------
  // test_case_1_basic
  //----------------------------------------------------------------------

  logic [p_entry_bits-1:0] empty_data;
  assign empty_data = (p_depth == 1) ? p_entry_bits'('hdeadbeef)
                                     : p_entry_bits'('h00000000);

  task test_case_1_basic();
    t.test_case_begin( "test_case_1_basic" );
    if( !t.run_test ) return;

    //     rst push pop empty        full                     wdata                     rdata
    check( 0,  0,   0,  1,              0, p_entry_bits'('h00000000), p_entry_bits'('h00000000) );
    check( 0,  1,   0,  1,              0, p_entry_bits'('hdeadbeef), p_entry_bits'('h00000000) );
    check( 0,  0,   0,  0, (p_depth == 1), p_entry_bits'('h00000000), p_entry_bits'('hdeadbeef) );
    check( 0,  0,   1,  0, (p_depth == 1), p_entry_bits'('h00000000), p_entry_bits'('hdeadbeef) );
    check( 0,  0,   0,  1,              0, p_entry_bits'('h00000000),                empty_data );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_2_full
  //----------------------------------------------------------------------

  task test_case_2_full();
    t.test_case_begin( "test_case_2_full" );
    if( !t.run_test ) return;

    //     rst push pop empty full wdata                      rdata
    check( 0,  1,   0,  1,    0,   p_entry_bits'('h00000000), p_entry_bits'('h00000000) );
    
    for( int i = 1; i < p_depth; i = i + 1 ) begin
      check( 0, 1, 0, 0, 0, p_entry_bits'(i), p_entry_bits'('h00000000) );
    end

    //     rst push pop empty full wdata              rdata
    check( 0,  0,   0,  0,    1,   p_entry_bits'('x), p_entry_bits'('h00000000) );
    check( 0,  0,   1,  0,    1,   p_entry_bits'('x), p_entry_bits'('h00000000) );

    for( int i = 1; i < p_depth; i = i + 1 ) begin
      check( 0, 0, 1, 0, 0, p_entry_bits'('x), p_entry_bits'(i) );
    end

    //     rst push pop empty full wdata              rdata
    check( 0,  0,   0,  1,    0,   p_entry_bits'('x), p_entry_bits'('h00000000) );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_3_random
  //----------------------------------------------------------------------

  logic [p_entry_bits-1:0] fl_queue [$:p_depth];

  logic                    rand_push;
  logic                    rand_pop;
  logic [p_entry_bits-1:0] rand_wdata;
  logic                    exp_empty;
  logic                    exp_full;
  logic [p_entry_bits-1:0] exp_rdata;

  task test_case_3_random();
    t.test_case_begin( "test_case_3_random" );
    if( !t.run_test ) return;

    for( int i = 0; i < 30; i = i + 1 ) begin
      rand_push  = 1'($urandom());
      rand_pop   = 1'($urandom());
      rand_wdata = p_entry_bits'($urandom());

      if( fl_queue.size() == 0       ) rand_pop  = 0;
      if( fl_queue.size() == p_depth ) rand_push = 0;

      exp_empty = ( fl_queue.size() == 0       );
      exp_full  = ( fl_queue.size() == p_depth );
      exp_rdata = ( exp_empty ) ? p_entry_bits'(1'bx) : fl_queue[0];

      check( 0, rand_push, rand_pop, exp_empty, exp_full, 
             rand_wdata, exp_rdata, int'(!exp_empty) );

      if( rand_push ) fl_queue.push_back( rand_wdata );
      if( rand_pop  ) fl_queue.delete(0);
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_1_basic();
    test_case_2_full();
    test_case_3_random();

  endtask
endmodule

//========================================================================
// Fifo_test
//========================================================================

module Fifo_test;
  FifoTestSuite #(1)         suite_1();
  FifoTestSuite #(2,  1, 32) suite_2();
  FifoTestSuite #(3,  8, 2 ) suite_3();
  FifoTestSuite #(3, 17, 1 ) suite_4();

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
