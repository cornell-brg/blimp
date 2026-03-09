//========================================================================
// RRArb_test.v
//========================================================================
// A testbench for our parametrized round-robin arbiter

`include "test/TestUtils.v"
`include "hw/common/MRRArb.v"
`include "hw/common/test/coverage/MRRArbCoverage.v"

import TestEnv::*;

//========================================================================
// MRRArbTestSuite
//========================================================================
// A test suite for a particular parametrization of the arbiter

module MRRArbTestSuite #(
  parameter p_suite_num = 0,
  parameter p_width = 4,
  parameter p_max_m = 4
);
  string suite_name = $sformatf("%0d: MRRArbTestSuite_%0d_%0d", 
                                p_suite_num, p_width, p_max_m);

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

  logic                     dut_en;
  logic [$clog2(p_max_m):0] dut_m;
  logic [p_width-1:0]       dut_req;
  logic [p_width-1:0]       dut_gnt;

  MRRArb #(
    .p_width (p_width),
    .p_max_m (p_max_m)
  ) DUT (
    .clk (clk),
    .rst (rst),
    .en  (dut_en),
    .m   (dut_m),
    .req (dut_req),
    .gnt (dut_gnt)
  );

  //----------------------------------------------------------------------
  // Setup for functional coverage
  //----------------------------------------------------------------------

  MRRArbCoverage #(
    .p_width (p_width),
    .p_max_m (p_max_m)
  ) func_coverage (
    .clk      (clk),
    .rst      (rst),
    .en       (dut_en),
    .m        (dut_m),
    .req      (dut_req),
    .gnt      (dut_gnt),
    .head_ptr (DUT.head_ptr)
  );

  //----------------------------------------------------------------------
  // check
  //----------------------------------------------------------------------
  // All tasks start at #1 after the rising edge of the clock. So we
  // write the inputs #1 after the rising edge, and check the outputs #1
  // before the next rising edge.

  task check (
    input logic                     en,
    input logic [$clog2(p_max_m):0] m,
    input logic [p_width-1:0]       req,
    input logic [p_width-1:0]       gnt
  );
    if ( !t.failed ) begin
      dut_req = req;
      dut_m   = m;
      dut_en  = en;

      #8;

      if ( t.verbose ) begin
        $display( "%3d: en=%b, m=%d, %b > %b", t.cycles,
                  dut_en, dut_m, dut_req, dut_gnt );
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

    //     en m in                    out
    check( 1, 1, p_width'('b0000), p_width'('b0000) );
    check( 1, 1, p_width'('b0001), p_width'('b0001) );
    check( 1, 1, p_width'('b0010), p_width'('b0010) );
    check( 1, 1, p_width'('b0011), p_width'('b0001) );
    if( p_width > 1 ) begin
      check( 1, 1, p_width'('b0011), p_width'('b0010) );
      check( 1, 2, p_width'('b0011), p_width'('b0011) );
      check( 1, 2, p_width'('b0111), p_width'('b0101) );
      check( 1, 2, p_width'('b0111), p_width'('b0110) );
      check( 1, 3, p_width'('b0111), p_width'('b0111) );
      check( 1, 3, p_width'('b0111), p_width'('b0111) );
      check( 1, 3, p_width'('b1111), p_width'('b1011) );
      check( 1, 3, p_width'('b1111), p_width'('b1101) );
      check( 1, 3, p_width'('b1111), p_width'('b1110) );
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_2_enable
  //----------------------------------------------------------------------

  task test_case_2_enable();
    t.test_case_begin( "test_case_2_enable" );
    if( !t.run_test ) return;

    //     en m in                    out
    check( 1, 1, p_width'('b0000), p_width'('b0000) );
    check( 1, 1, p_width'('b0001), p_width'('b0001) );
    check( 1, 1, p_width'('b0010), p_width'('b0010) );
    check( 1, 1, p_width'('b0011), p_width'('b0001) );
    
    check( 0, 1, p_width'('b0000), p_width'('b0000) );
    check( 0, 1, p_width'('b0001), p_width'('b0000) );
    check( 0, 1, p_width'('b0010), p_width'('b0000) );
    check( 0, 1, p_width'('b0011), p_width'('b0000) );
    check( 0, 1, p_width'('b1000), p_width'('b0000) );
    check( 0, 1, p_width'('b1111), p_width'('b0000) );
    check( 0, 1, p_width'('b0101), p_width'('b0000) );
    check( 0, 1, p_width'('b1010), p_width'('b0000) );

    check( 0, 2, p_width'('b0000), p_width'('b0000) );
    check( 1, 2, p_width'('b0000), p_width'('b0000) );
    check( 0, 2, p_width'('b0001), p_width'('b0000) );
    check( 1, 2, p_width'('b0001), p_width'('b0001) );
    check( 0, 2, p_width'('b0010), p_width'('b0000) );
    check( 1, 2, p_width'('b0010), p_width'('b0010) );
    check( 0, 2, p_width'('b0011), p_width'('b0000) );
    check( 1, 2, p_width'('b0011), p_width'('b0011) );
    check( 0, 2, p_width'('b1000), p_width'('b0000) );
    check( 1, 2, p_width'('b1000), p_width'('b1000) );
    check( 0, 2, p_width'('b1111), p_width'('b0000) );
    check( 1, 2, p_width'('b1111), p_width'('b0011) );
    check( 0, 2, p_width'('b0101), p_width'('b0000) );
    check( 1, 2, p_width'('b0101), p_width'('b0101) );
    check( 0, 2, p_width'('b1010), p_width'('b0000) );
    check( 1, 2, p_width'('b1010), p_width'('b1010) );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_3_no_grant
  //----------------------------------------------------------------------

  task test_case_3_no_grant();
    t.test_case_begin( "test_case_3_no_grant" );
    if( !t.run_test ) return;

    //     en m in                    out
    check( 1, 1, p_width'('b0000), p_width'('b0000) );
    check( 1, 1, p_width'('b0000), p_width'('b0000) );
    check( 1, 1, p_width'('b0001), p_width'('b0001) );
    check( 1, 1, p_width'('b0001), p_width'('b0001) );
    check( 1, 1, p_width'('b0000), p_width'('b0000) );
    check( 1, 2, p_width'('b0000), p_width'('b0000) );
    check( 1, 2, p_width'('b0000), p_width'('b0000) );
    check( 1, 3, p_width'('b0000), p_width'('b0000) );
    check( 1, 3, p_width'('b0000), p_width'('b0000) );
    check( 1, 4, p_width'('b0000), p_width'('b0000) );
    check( 1, 4, p_width'('b0000), p_width'('b0000) );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_4_edge_cases_m
  //----------------------------------------------------------------------

  task test_case_4_edge_cases_m();
    t.test_case_begin( "test_case_4_edge_cases_m" );
    if( !t.run_test ) return;

    //     en       m in                    out
    check( 1,       0, p_width'('b0000), p_width'('b0000) );
    check( 1,       0, p_width'('b0101), p_width'('b0000) );
    check( 1,       0, p_width'('b1010), p_width'('b0000) );
    check( 1,       0, p_width'('b1111), p_width'('b0000) );
    
    check( 1, p_max_m, p_width'('b0000), p_width'('b0000) );
    check( 1, p_max_m, p_width'('b0101), p_width'('b0101) );
    check( 1, p_max_m, p_width'('b1010), p_width'('b1010) );
    check( 1, p_max_m, p_width'('b1111), p_width'('b1111) );
    
    check( 1,      '1, p_width'('b0000), p_width'('b0000) );
    check( 1,      '1, p_width'('b0101), p_width'('b0101) );
    check( 1,      '1, p_width'('b1010), p_width'('b1010) );
    check( 1,      '1, p_width'('b1111), p_width'('b1111) );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_5_max_num_req_gnt
  //----------------------------------------------------------------------

  logic [$clog2(p_max_m):0] temp_m;
  logic [p_width-1:0]       exp_gnt;

  int   head_idx, scan_idx, next_head_idx;

  task test_case_5_max_num_req_gnt();
    t.test_case_begin( "test_case_5_max_num_req_gnt" );
    if( !t.run_test ) return;

    head_idx = 0;

    for( int i = 0; i < 20; i = i + 1 ) begin

      // Determine the expected output
      temp_m        = p_max_m;
      exp_gnt       = '0;
      next_head_idx = head_idx;

      for ( scan_idx = head_idx; scan_idx < p_width; scan_idx++ ) begin
        if ( temp_m > 0 ) begin
          exp_gnt[scan_idx] = 1'b1;
          temp_m = temp_m - 1;
          if ( (scan_idx+1) == p_width )
            next_head_idx = 0;
          else
            next_head_idx = scan_idx + 1;
        end
      end

      for ( scan_idx = 0; scan_idx < head_idx; scan_idx++ ) begin
        if ( temp_m > 0 ) begin
          exp_gnt[scan_idx] = 1'b1;
          temp_m = temp_m - 1;
          next_head_idx = scan_idx + 1;
        end
      end

      // Check that outputs match corresponding inputs
      //     en       m in   out
      check( 1, p_max_m, '1, exp_gnt );

      // Update the index of the head pointer
      head_idx = next_head_idx;
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_6_oscillate
  //----------------------------------------------------------------------

  task test_case_6_oscillate();
    t.test_case_begin( "test_case_6_oscillate" );
    if( !t.run_test ) return;

    //     en m in                    out
    check( 1, 1, p_width'('b0000), p_width'('b0000) );
    check( 1, 1, p_width'('b0001), p_width'('b0001) );

    check( 1, 1, p_width'('b0011), p_width'('b0010) );
    check( 1, 1, p_width'('b0011), p_width'('b0001) );

    check( 1, 1, p_width'('b0111), p_width'('b0010) );
    check( 1, 1, p_width'('b0111), p_width'('b0100) );
    check( 1, 1, p_width'('b0111), p_width'('b0001) );
    check( 1, 1, p_width'('b1111), p_width'('b0010) );
    check( 1, 1, p_width'('b1111), p_width'('b0100) );
    check( 1, 1, p_width'('b1111), p_width'('b1000) );
    check( 1, 1, p_width'('b1111), p_width'('b0001) );

    check( 1, 1, p_width'('b1110), p_width'('b0010) );
    check( 1, 1, p_width'('b1110), p_width'('b0100) );
    check( 1, 1, p_width'('b1110), p_width'('b1000) );

    check( 1, 1, p_width'('b1100), p_width'('b0100) );
    check( 1, 1, p_width'('b1100), p_width'('b1000) );

    check( 1, 1, p_width'('b1000), p_width'('b1000) );
    check( 1, 1, p_width'('b1000), p_width'('b1000) );

    check( 1, 2, p_width'('b0000), p_width'('b0000) );
    check( 1, 2, p_width'('b0001), p_width'('b0001) );

    check( 1, 2, p_width'('b0011), p_width'('b0011) );
    check( 1, 2, p_width'('b0011), p_width'('b0011) );

    check( 1, 2, p_width'('b0111), p_width'('b0110) );
    check( 1, 2, p_width'('b0111), p_width'('b0011) );
    check( 1, 2, p_width'('b0111), p_width'('b0101) );
    check( 1, 2, p_width'('b1111), p_width'('b0110) );
    check( 1, 2, p_width'('b1111), p_width'('b1001) );
    check( 1, 2, p_width'('b1111), p_width'('b0110) );
    check( 1, 2, p_width'('b1111), p_width'('b1001) );

    check( 1, 2, p_width'('b1110), p_width'('b0110) );
    check( 1, 2, p_width'('b1110), p_width'('b1010) );
    check( 1, 2, p_width'('b1110), p_width'('b1100) );

    check( 1, 2, p_width'('b1100), p_width'('b1100) );
    check( 1, 2, p_width'('b1100), p_width'('b1100) );

    check( 1, 2, p_width'('b1000), p_width'('b1000) );
    check( 1, 2, p_width'('b1000), p_width'('b1000) );
    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_7_enable_random
  //----------------------------------------------------------------------

  logic                     rand_en;
  logic [$clog2(p_max_m):0] rand_m;
  logic [p_width-1:0]       rand_req;

  task test_case_7_enable_random();
    t.test_case_begin( "test_case_7_enable_random" );
    if( !t.run_test ) return;

    head_idx = 0;

    for( int i = 0; i < 200; i = i + 1 ) begin

      // Generate random input values
      rand_en  = 1'( $urandom() );
      rand_m   = ($clog2(p_max_m)+1)'( $urandom() );
      rand_req = p_width'( $urandom() );

      // Determine the expected output
      temp_m        = (rand_m > p_max_m) ? p_max_m : rand_m;
      exp_gnt       = '0;
      next_head_idx = head_idx;

      if ( rand_en ) begin
        for ( scan_idx = head_idx; scan_idx < p_width; scan_idx++ ) begin
          if ( rand_req[scan_idx] && (temp_m > 0) ) begin
            exp_gnt[scan_idx] = 1'b1;
            temp_m = temp_m - 1;
            if ( (scan_idx+1) == p_width )
              next_head_idx = 0;
            else
              next_head_idx = scan_idx + 1;
          end
        end

        for ( scan_idx = 0; scan_idx < head_idx; scan_idx++ ) begin
          if ( rand_req[scan_idx] && (temp_m > 0) ) begin
            exp_gnt[scan_idx] = 1'b1;
            temp_m = temp_m - 1;
            next_head_idx = scan_idx + 1;
          end
        end
      end

      // Check that outputs match corresponding inputs
      check( rand_en, rand_m, rand_req, exp_gnt );

      // Update the index of the head pointer
      head_idx = next_head_idx;
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_8_random
  //----------------------------------------------------------------------

  task test_case_8_random();
    t.test_case_begin( "test_case_8_random" );
    if( !t.run_test ) return;

    head_idx = 0;

    for( int i = 0; i < 200; i = i + 1 ) begin

      // Generate random input values
      rand_m   = ($clog2(p_max_m)+1)'( $urandom() );
      rand_req = p_width'( $urandom() );

      // Determine the expected output
      temp_m        = (rand_m > p_max_m) ? p_max_m : rand_m;
      exp_gnt       = '0;
      next_head_idx = head_idx;

      for ( scan_idx = head_idx; scan_idx < p_width; scan_idx++ ) begin
        if ( rand_req[scan_idx] && (temp_m > 0) ) begin
          exp_gnt[scan_idx] = 1'b1;
          temp_m = temp_m - 1;
          if ( (scan_idx+1) == p_width )
            next_head_idx = 0;
          else
            next_head_idx = scan_idx + 1;
        end
      end

      for ( scan_idx = 0; scan_idx < head_idx; scan_idx++ ) begin
        if ( rand_req[scan_idx] && (temp_m > 0) ) begin
          exp_gnt[scan_idx] = 1'b1;
          temp_m = temp_m - 1;
          next_head_idx = scan_idx + 1;
        end
      end

      // Check that outputs match corresponding inputs
      check( 1'b1, rand_m, rand_req, exp_gnt );

      // Update the index of the head pointer
      head_idx = next_head_idx;
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

                      test_case_1_basic();
                      test_case_2_enable();
                      test_case_3_no_grant();
                      test_case_4_edge_cases_m();
                      test_case_5_max_num_req_gnt();
    if (p_width >= 4) test_case_6_oscillate();
                      test_case_7_enable_random();
                      test_case_8_random();

  endtask
endmodule

//========================================================================
// MRRArb_test
//========================================================================

module MRRArb_test;
  MRRArbTestSuite #(1)          suite_1();
  MRRArbTestSuite #(2,  8)      suite_2();
  MRRArbTestSuite #(3,  32,  8) suite_3();
  MRRArbTestSuite #(4,  1)      suite_4();

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
