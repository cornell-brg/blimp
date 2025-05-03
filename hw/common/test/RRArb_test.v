//========================================================================
// RRArb_test.v
//========================================================================
// A testbench for our parametrized round-robin arbiter

`include "test/TestUtils.v"
`include "hw/common/RRArb.v"

import TestEnv::*;

//========================================================================
// RRArbTestSuite
//========================================================================
// A test suite for a particular parametrization of the arbiter

module RRArbTestSuite #(
  parameter p_suite_num = 0,
  parameter p_width = 4
);
  string suite_name = $sformatf("%0d: RRArbTestSuite_%0d", 
                                p_suite_num, p_width);

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

  logic               dut_en;
  logic [p_width-1:0] dut_req;
  logic [p_width-1:0] dut_gnt;

  RRArb #(
    .p_width (p_width)
  ) DUT (
    .clk (clk),
    .rst (rst),
    .en  (dut_en),
    .req (dut_req),
    .gnt (dut_gnt)
  );

  //----------------------------------------------------------------------
  // check
  //----------------------------------------------------------------------
  // All tasks start at #1 after the rising edge of the clock. So we
  // write the inputs #1 after the rising edge, and check the outputs #1
  // before the next rising edge.

  task check (
    input logic               en,
    input logic [p_width-1:0] req,
    input logic [p_width-1:0] gnt
  );
    if ( !t.failed ) begin
      dut_req = req;
      dut_en  = en;

      #8;

      if ( t.verbose ) begin
        $display( "%3d: %b %b > %b", t.cycles,
                  dut_en, dut_req, dut_gnt );
      end

      `CHECK_EQ( dut_gnt, gnt );

      #2;

    end
  endtask

  //----------------------------------------------------------------------
  // test_case_1_basic
  //----------------------------------------------------------------------

  task test_case_1_basic();
    t.test_case_begin( "test_case_1_basic" );
    if( !t.run_test ) return;

    //     en in                    out
    check( 1, p_width'('b0000), p_width'('b0000) );
    check( 1, p_width'('b0001), p_width'('b0001) );
    check( 1, p_width'('b0010), p_width'('b0010) );
    check( 1, p_width'('b0011), p_width'('b0001) );
    if( p_width > 1 )
      check( 1, p_width'('b0011), p_width'('b0010) );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_2_no_grant
  //----------------------------------------------------------------------

  task test_case_2_no_grant();
    t.test_case_begin( "test_case_2_no_grant" );
    if( !t.run_test ) return;

    //     en in                    out
    check( 1, p_width'('b0000), p_width'('b0000) );
    check( 1, p_width'('b0000), p_width'('b0000) );
    check( 1, p_width'('b0001), p_width'('b0001) );
    check( 1, p_width'('b0001), p_width'('b0001) );
    check( 1, p_width'('b0000), p_width'('b0000) );
    check( 1, p_width'('b0000), p_width'('b0000) );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_3_oscillate
  //----------------------------------------------------------------------

  task test_case_3_oscillate();
    t.test_case_begin( "test_case_3_oscillate" );
    if( !t.run_test ) return;

    //     en in                    out
    check( 1, p_width'('b0000), p_width'('b0000) );
    check( 1, p_width'('b0001), p_width'('b0001) );

    check( 1, p_width'('b0011), p_width'('b0010) );
    check( 1, p_width'('b0011), p_width'('b0001) );

    check( 1, p_width'('b0111), p_width'('b0010) );
    check( 1, p_width'('b0111), p_width'('b0100) );
    check( 1, p_width'('b0111), p_width'('b0001) );

    check( 1, p_width'('b1111), p_width'('b0010) );
    check( 1, p_width'('b1111), p_width'('b0100) );
    check( 1, p_width'('b1111), p_width'('b1000) );
    check( 1, p_width'('b1111), p_width'('b0001) );

    check( 1, p_width'('b1110), p_width'('b0010) );
    check( 1, p_width'('b1110), p_width'('b0100) );
    check( 1, p_width'('b1110), p_width'('b1000) );

    check( 1, p_width'('b1100), p_width'('b0100) );
    check( 1, p_width'('b1100), p_width'('b1000) );

    check( 1, p_width'('b1000), p_width'('b1000) );
    check( 1, p_width'('b1000), p_width'('b1000) );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_4_random
  //----------------------------------------------------------------------

  logic [p_width-1:0] rand_req;
  logic               rand_en;
  logic [p_width-1:0] exp_gnt;
  int prev_gnt_idx, curr_gnt_idx, granted;

  task test_case_4_random();
    t.test_case_begin( "test_case_4_random" );
    if( !t.run_test ) return;
    prev_gnt_idx = p_width;

    for( int i = 0; i < 20; i = i + 1 ) begin
      rand_req = p_width'( $urandom() );
      rand_en  = 1'( $urandom() );
      granted  = 0;
      
      // Check for next highest priority
      for( int j = prev_gnt_idx + 1; j < p_width; j = j + 1 ) begin
        if( rand_req[j] ) begin
          curr_gnt_idx = j;
          granted = 1;
          break;
        end
      end

      // Start from beginning
      if( granted == 0 ) begin
        for( int j = 0; j <= prev_gnt_idx; j = j + 1 ) begin
          if( rand_req[j] ) begin
          curr_gnt_idx = j;
          granted = 1;
          break;
        end
        end
      end

      if( granted == 1 ) begin
        exp_gnt = 1 << curr_gnt_idx;
        if( rand_en )
          prev_gnt_idx = curr_gnt_idx;
      end else begin
        exp_gnt = '0;
        if( rand_en )
          prev_gnt_idx = p_width;
      end

      check( rand_en, rand_req, exp_gnt );
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

                      test_case_1_basic();
                      test_case_2_no_grant();
    if (p_width >= 4) test_case_3_oscillate();
                      test_case_4_random();

  endtask
endmodule

//========================================================================
// RRArb_test
//========================================================================

module RRArb_test;
  RRArbTestSuite #(1)     suite_1();
  RRArbTestSuite #(2,  8) suite_2();
  RRArbTestSuite #(3, 32) suite_3();
  RRArbTestSuite #(4,  1) suite_4();

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
