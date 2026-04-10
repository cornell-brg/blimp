//========================================================================
// MSourceSink_test.v
//========================================================================
// A testbench for our TestMSource and TestMSink

`include "test/fl/TestMSource.v"
`include "test/fl/TestMSink.v"
`include "test/TestUtils.v"

import TestEnv::*;

//========================================================================
// MSourceSinkTestSuite
//========================================================================

module MSourceSinkTestSuite #(
  parameter p_suite_num = 0,
  parameter p_ordered = `SINK_ORDERED,
  parameter p_num_pairs = 2
);

  //verilator lint_off UNUSEDSIGNAL
  string suite_name = $sformatf("%0d: MSourceSinkTestSuite_%0s_%0d", p_suite_num, 
                                    (p_ordered ? "ORDERED" : "UNORDERED"), p_num_pairs);
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

  logic        val [p_num_pairs];
  logic        rdy [p_num_pairs];
  logic [31:0] msg [p_num_pairs];

  logic src_done;
  logic sink_done;

  TestMSource #(
    .p_num_srcs (p_num_pairs)
  ) src (
    .clk (clk),
    .go  (go),

    .val (val),
    .rdy (rdy),
    .msg (msg),

    .done (src_done)
  );

  TestMSink #( 
    .p_ordered   (p_ordered),
    .p_num_sinks (p_num_pairs)
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
    input logic        val_to_add [p_num_pairs],
    input logic [31:0] msg_to_add [p_num_pairs]
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
    add_msg( '{0:1'b1, default:1'b0}, '{0:32'hdead_beef, default:'x} );

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_parallel_send
  //----------------------------------------------------------------------

  logic [31:0] data [p_num_pairs];

  task test_case_parallel_send();
    t.test_case_begin( "test_case_parallel_send" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    for( int i = 0; i < p_num_pairs; i++ ) begin
      data[i] = $urandom();
    end
    add_msg( '{default:1'b1}, data );

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_multi_parallel_send
  //----------------------------------------------------------------------

  task test_case_multi_parallel_send();
    t.test_case_begin( "test_case_multi_parallel_send" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    for( int k = 0; k < 4; k++ ) begin
      for( int i = 0; i < p_num_pairs; i++ ) begin
        data[i] = $urandom();
      end
      add_msg( '{default:1'b1}, data );
    end

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
    for( int k = 0; k < 100; k++ ) begin
      for( int i = 0; i < p_num_pairs; i++ ) begin
        data[i] = $urandom();
      end
      add_msg( '{default:1'b1}, data );
    end

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_val_random
  //----------------------------------------------------------------------

  logic vals [p_num_pairs];

  task test_case_val_random();
    t.test_case_begin( "test_case_val_random" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    for( int k = 0; k < 100; k++ ) begin
      for( int i = 0; i < p_num_pairs; i++ ) begin
        vals[i] = 1'( $urandom() );
        data[i] = $urandom();
      end
      add_msg( vals, data );
    end

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_unordered_random
  //----------------------------------------------------------------------

  logic [31:0] backward_arr [100][p_num_pairs];

  task test_case_unordered_random();
    t.test_case_begin( "test_case_unordered_random" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    for( int k = 0; k < 100; k++ ) begin
      for( int i = 0; i < p_num_pairs; i++ ) begin
        backward_arr[k][i] = $urandom();
      end
      src.add_send( '{default:1'b1}, backward_arr[k] );
    end

    for( int k = 99; k >= 0; k-- ) begin
      sink.add_exp( '{default:1'b1}, backward_arr[k] );
    end

    // Run the test case
    run();

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_unordered_val_random
  //----------------------------------------------------------------------

  logic backward_val_arr [100][p_num_pairs];

  task test_case_unordered_val_random();
    t.test_case_begin( "test_case_unordered_val_random" );
    if( !t.run_test ) return;

    // Reset the testbench for the new test case
    tb_clear();

    // Write the test sequence for the new test case
    for( int k = 0; k < 100; k++ ) begin
      for( int i = 0; i < p_num_pairs; i++ ) begin
        backward_val_arr[k][i] = 1'( $urandom() );
        backward_arr[k][i] = $urandom();
      end
      src.add_send( backward_val_arr[k], backward_arr[k] );
    end

    for( int k = 99; k >= 0; k-- ) begin
      sink.add_exp( backward_val_arr[k], backward_arr[k] );
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
    test_case_parallel_send();
    test_case_multi_parallel_send();
    test_case_many_random();
    test_case_val_random();
    if ( p_ordered == `SINK_UNORDERED ) test_case_unordered_random();
    if ( p_ordered == `SINK_UNORDERED ) test_case_unordered_val_random();
  endtask
endmodule

//========================================================================
// MSourceSink_test
//========================================================================

module MSourceSink_test;
  MSourceSinkTestSuite #(1, `SINK_ORDERED,   2) suite_1();
  MSourceSinkTestSuite #(2, `SINK_ORDERED,   3) suite_2();
  MSourceSinkTestSuite #(3, `SINK_ORDERED,   4) suite_3();
  MSourceSinkTestSuite #(4, `SINK_UNORDERED, 2) suite_4();
  MSourceSinkTestSuite #(5, `SINK_UNORDERED, 3) suite_5();
  MSourceSinkTestSuite #(6, `SINK_UNORDERED, 4) suite_6();

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

    test_bench_end();
  end
endmodule
