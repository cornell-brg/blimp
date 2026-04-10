//========================================================================
// SourceSink_test.v
//========================================================================
// A testbench for our TestSource and TestSink

`include "test/fl/TestSource.v"
`include "test/fl/TestSink.v"
`include "test/TestUtils.v"

import TestEnv::*;

//========================================================================
// SourceSinkTestSuite
//========================================================================

module SourceSinkTestSuite #(
  parameter p_suite_num = 0,
  parameter p_ordered = `SINK_ORDERED
);

  //verilator lint_off UNUSEDSIGNAL
  string suite_name = $sformatf("%0d: SourceSinkTestSuite_%0s", p_suite_num, 
                                    (p_ordered ? "ORDERED" : "UNORDERED"));
  //verilator lint_on UNUSEDSIGNAL

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate the source and sink
  //----------------------------------------------------------------------

  logic go;
  initial go = 1'b0;

  logic        val;
  logic        rdy;
  logic [31:0] msg;

  logic src_done;
  logic sink_done;

  TestSource src
  (
    .clk (clk),
    .go  (go),

    .val (val),
    .rdy (rdy),
    .msg (msg),

    .done (src_done)
  );

  TestSink #( 
    .p_ordered (p_ordered)
  ) sink (
    .clk (clk),
    .go  (go),

    .val (val),
    .rdy (rdy),
    .msg (msg),

    .done (sink_done)
  );

  //----------------------------------------------------------------------
  // tb_clear
  //----------------------------------------------------------------------
  // Task that clears the internal message sequence for a new test case

  task automatic tb_clear();
    go = 1'b0;
    src.clear();
    sink.clear();
  endtask

  //----------------------------------------------------------------------
  // add_msg
  //----------------------------------------------------------------------

  task automatic add_msg
  (
    input logic        val_to_add,
    input logic [31:0] msg_to_add
  );
    src.add_send( val_to_add, msg_to_add );
    sink.add_exp( val_to_add, msg_to_add );
  endtask

  //----------------------------------------------------------------------
  // run
  //----------------------------------------------------------------------

  task automatic run();
    @( posedge clk )
    #1;

    go = 1'b1;
    wait( src_done && sink_done );
    go = 1'b0;

    @( posedge clk )
    #1;
  endtask

  //----------------------------------------------------------------------
  // test_case_single_send
  //----------------------------------------------------------------------

  task test_case_single_send();
    t.test_case_begin( "test_case_single_send" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    add_msg( 1'b1, 32'hdead_beef );

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_multi_send
  //----------------------------------------------------------------------

  task test_case_multi_send();
    t.test_case_begin( "test_case_multi_send" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    add_msg( 1'b1, 32'h1111_1111 );
    add_msg( 1'b1, 32'h2222_2222 );
    add_msg( 1'b1, 32'h3333_3333 );
    add_msg( 1'b1, 32'h4444_4444 );

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_many_random
  //----------------------------------------------------------------------

  task test_case_many_random();
    t.test_case_begin( "test_case_many_random" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    for( int i = 0; i < 100; i++ ) begin
      add_msg( 1'b1, $urandom() );
    end

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_val_random
  //----------------------------------------------------------------------

  task test_case_val_random();
    t.test_case_begin( "test_case_val_random" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    for( int i = 0; i < 100; i++ ) begin
      add_msg( 1'( $urandom() ), $urandom() );
    end

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_unordered_random
  //----------------------------------------------------------------------

  logic [31:0] backward_arr [100];

  task test_case_unordered_random();
    t.test_case_begin( "test_case_unordered_random" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    for( int i = 0; i < 100; i++ ) begin
      backward_arr[i] = $urandom();
      src.add_send( 1'b1, backward_arr[i] );
    end

    for( int i = 99; i >= 0; i-- ) begin
      sink.add_exp( 1'b1, backward_arr[i] );
    end

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_unordered_val_random
  //----------------------------------------------------------------------

  logic backward_val_arr [100];

  task test_case_unordered_val_random();
    t.test_case_begin( "test_case_unordered_val_random" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    for( int i = 0; i < 100; i++ ) begin
      backward_val_arr[i] = 1'( $urandom() );
      backward_arr[i] = $urandom();
      src.add_send( backward_val_arr[i], backward_arr[i] );
    end

    for( int i = 99; i >= 0; i-- ) begin
      sink.add_exp( backward_val_arr[i], backward_arr[i] );
    end

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_single_send();
    test_case_multi_send();
    test_case_many_random();
    test_case_val_random();
    if ( p_ordered == `SINK_UNORDERED ) test_case_unordered_random();
    if ( p_ordered == `SINK_UNORDERED ) test_case_unordered_val_random();
  endtask
endmodule

//========================================================================
// SourceSink_test
//========================================================================

module SourceSink_test;
  SourceSinkTestSuite #(1, `SINK_ORDERED)   suite_1();
  SourceSinkTestSuite #(2, `SINK_UNORDERED) suite_2();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();
    if ((s <= 0) || (s == 2)) suite_2.run_test_suite();

    test_bench_end();
  end
endmodule
