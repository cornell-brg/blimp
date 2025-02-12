//========================================================================
// GCD Unit Test Suites
//========================================================================

`include "hw/gcd/GcdUnit.v"
`include "intf/StreamIntf.v"
`include "test/TestUtils.v"
`include "test/fl/TestIstream.v"
`include "test/fl/TestOstream.v"

import TestEnv::*;

//========================================================================
// GcdUnitTestSuite
//========================================================================

module GcdUnitTestSuite #(
  parameter p_suite_num     = 0,
  parameter p_istream_delay = 0,
  parameter p_ostream_delay = 0
);

  //verilator lint_off UNUSEDSIGNAL
  string suite_name = $sformatf("%0d: GcdUnitTestSuite_%0d_%0d", p_suite_num,
                                p_istream_delay, p_ostream_delay);
  //verilator lint_on UNUSEDSIGNAL

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  StreamIntf #(
    .t_msg   (logic[31:0])
  ) istream_intf();

  StreamIntf #(
    .t_msg   (logic[15:0])
  ) ostream_intf();

  hw_gcd_GcdUnit dut (
    .istream (istream_intf),
    .ostream (ostream_intf),
    .*
  );

  //----------------------------------------------------------------------
  // Test modules
  //----------------------------------------------------------------------

  TestIstream #( logic[31:0], p_istream_delay ) istream (
    .dut (istream_intf),
    .*
  );

  function logic[31:0] mk_imsg(
    input logic [15:0] msg_a,
    input logic [15:0] msg_b
  );
    return {msg_a, msg_b};
  endfunction

  TestOstream #( logic[15:0], p_ostream_delay ) ostream (
    .dut (ostream_intf),
    .*
  );

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always_ff @( posedge clk ) begin
    trace = "";

    trace = {trace, istream.trace()};
    trace = {trace, " > "};
    trace = {trace, dut.trace()};
    trace = {trace, " > "};
    trace = {trace, ostream.trace()};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // test_case_1_basic
  //----------------------------------------------------------------------

  task test_case_1_basic();
    t.test_case_begin( "test_case_1_basic" );
    if( !t.run_test ) return;

    fork
      istream.send( mk_imsg( 15, 5 ) );
      ostream.recv( 5 );
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_2_complex
  //----------------------------------------------------------------------

  task test_case_2_complex();
    t.test_case_begin( "test_case_2_complex" );
    if( !t.run_test ) return;

    fork
      begin
        istream.send( mk_imsg(   3,   9 ) );
        istream.send( mk_imsg(   0,   0 ) );
        istream.send( mk_imsg(  27,  15 ) );
        istream.send( mk_imsg(  21,  49 ) );
        istream.send( mk_imsg(  25,  30 ) );
        istream.send( mk_imsg(  19,  27 ) );
        istream.send( mk_imsg(  40,  40 ) );
        istream.send( mk_imsg( 250, 190 ) );
        istream.send( mk_imsg(   5, 250 ) );
      end

      begin
        ostream.recv(  3 );
        ostream.recv(  0 );
        ostream.recv(  3 );
        ostream.recv(  7 );
        ostream.recv(  5 );
        ostream.recv(  1 );
        ostream.recv( 40 );
        ostream.recv( 10 );
        ostream.recv(  5 );
      end
    join

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_3_random
  //----------------------------------------------------------------------

  logic [15:0] rand_a, rand_b;
  logic [15:0] exp_gcd;

  function logic [15:0] gcd(
    input logic [15:0] msg_a,
    input logic [15:0] msg_b
  );
    logic [15:0] a, b, tmp;

    a = msg_a;
    b = msg_b;

    while( 1 ) begin
      if( a < b ) begin
        tmp = a;
        a   = b;
        b   = tmp;
      end else if( b != 0 )
        a = a - b;
      else
        return a;
    end
  endfunction

  task test_case_3_random();
    exp_gcd = gcd(15, 5);
    t.test_case_begin( "test_case_3_random" );
    if( !t.run_test ) return;

    for( int i = 0; i < 20; i = i + 1 ) begin
      rand_a  = 16'($urandom());
      rand_b  = 16'($urandom());
      exp_gcd = gcd( rand_a, rand_b );

      fork
        istream.send( mk_imsg( rand_a, rand_b ) );
        ostream.recv( exp_gcd );
      join
    end

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_1_basic();
    test_case_2_complex();
    test_case_3_random();
  endtask
endmodule

//========================================================================
// GcdUnit_test
//========================================================================

module GcdUnit_test;
  GcdUnitTestSuite #(1, 0, 0) suite_1();
  GcdUnitTestSuite #(2, 3, 0) suite_2();
  GcdUnitTestSuite #(3, 0, 3) suite_3();
  GcdUnitTestSuite #(4, 3, 3) suite_4();

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
