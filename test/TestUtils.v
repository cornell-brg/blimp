//========================================================================
// TestUtils.v
//========================================================================
// Testing utilities, to be used in testbenches
// Adapted from ECE2300, Cornell University

`ifndef TEST_TEST_UTILS_V
`define TEST_TEST_UTILS_V

//------------------------------------------------------------------------
// Colors
//------------------------------------------------------------------------

`define RED    "\033[31m"
`define YELLOW "\033[33m"
`define GREEN  "\033[32m"
`define BLUE   "\033[34m"
`define PURPLE "\033[35m"
`define RESET  "\033[0m"

//------------------------------------------------------------------------
// TestStatus
//------------------------------------------------------------------------
// A class to statically track the number of failed tests, acting as a
// way to hold a global variable of failed tests

class TestStatus;
  static int num_failed = 0;

  static task test_fail();
    num_failed += 1;
  endtask
endclass

function int num_failed_tests();
  return TestStatus::num_failed;
endfunction

export "DPI-C" function num_failed_tests;

//------------------------------------------------------------------------
// TestEnv
//------------------------------------------------------------------------

package TestEnv;

  //----------------------------------------------------------------------
  // get_test_suite
  //----------------------------------------------------------------------

  function int get_test_suite();
    if ( !$value$plusargs( "test-suite=%d", get_test_suite ) )
      get_test_suite = 0;
  endfunction

  //----------------------------------------------------------------------
  // test_bench_begin
  //----------------------------------------------------------------------
  // We start with a #1 delay so that all tasks will essentially start at
  // #1 after the rising edge of the clock.
  // test_bench_begin

  task test_bench_begin( string filename );
    $write("\nRunning %s", filename);
    if ( $value$plusargs( "dump-vcd=%s", filename ) ) begin
      $dumpfile(filename);
      $dumpvars();
    end
    #1;
  endtask

  //----------------------------------------------------------------------
  // test_bench_end
  //----------------------------------------------------------------------

  task test_bench_end();
    $write("\n\n");
    $finish;
  endtask
endpackage


//========================================================================
// TestUtils
//========================================================================

module TestUtils
(
  output logic clk,
  output logic rst
);

  // ---------------------------------------------------------------------
  // Clocking
  // ---------------------------------------------------------------------
  
  // verilator lint_off BLKSEQ
  initial clk = 1'b1;
  always #5 clk = ~clk;
  // verilator lint_on BLKSEQ

  // ---------------------------------------------------------------------
  // Error Count
  // ---------------------------------------------------------------------

  // verilator lint_off UNUSEDSIGNAL
  logic failed = 0;
  //verilator lint_on UNUSEDSIGNAL

  // ---------------------------------------------------------------------
  // Filtering Utilities
  // ---------------------------------------------------------------------

  // verilator lint_off UNUSEDSIGNAL
  string select;
  logic select_active;
  logic verbose;
  // verilator lint_on UNUSEDSIGNAL

  initial begin
    select_active = 1'b0;
    if ( $value$plusargs( "select=%s", select ) )
      select_active = 1'b1;
    else if ( $value$plusargs( "s=%s", select ) )
      select_active = 1'b1;
  end

  initial begin
    if ( $test$plusargs ("verbose") )
      verbose = 1'b1;
    else if ( $test$plusargs ("v") )
      verbose = 1'b1;
    else
      verbose = 1'b0;
  end

  function logic contains( input string test_name );
    // Check that the test name contains the filter
    int test_name_len;
    int select_len;

    test_name_len = test_name.len();
    select_len    = select.len();

    for( int i = 0; i < test_name_len; i = i + 1 ) begin
      if( test_name.substr(i, i + select_len - 1) == select )
        return 1'b1;
    end
    return 1'b0;
  endfunction

  // ---------------------------------------------------------------------
  // Random Seeding
  // ---------------------------------------------------------------------

  // Seed random test cases
  int seed = 32'hdeadbeef;
  initial $urandom(seed);

  // ---------------------------------------------------------------------
  // Cycle counter with timeout check
  // ---------------------------------------------------------------------

  int cycles;

  always @( posedge clk ) begin

    if ( rst )
      cycles <= 0;
    else
      cycles <= cycles + 1;

    if ( cycles > 10000 ) begin
      $display( "\nERROR (cycles=%0d): timeout!", cycles );
      TestStatus::test_fail();
      $finish;
    end

  end

  //----------------------------------------------------------------------
  // test_suite_begin
  //----------------------------------------------------------------------

  task test_suite_begin( string suitename );
    $write("\n  %s%s%s", `PURPLE, suitename, `RESET);
  endtask

  //----------------------------------------------------------------------
  // test_case_begin
  //----------------------------------------------------------------------

  // verilator lint_off UNUSEDSIGNAL
  logic run_test;
  logic test_running;
  // verilator lint_on UNUSEDSIGNAL

  initial run_test     = 1'b1;
  initial test_running = 1'b0;

  task test_case_begin( string taskname );
    if( select_active & !contains( taskname ) ) begin
      run_test = 1'b0;
      return;
    end else begin
      run_test = 1'b1;
    end

    $write("\n    %s%s%s ", `BLUE, taskname, `RESET);
    if ( verbose )
      $write("\n");

    seed = 32'hdeadbeef;
    failed = 0;

    rst = 1;
    @( posedge clk );
    @( posedge clk );
    @( posedge clk );
    #1;
    rst = 0;
    test_running = 1'b1;
  endtask

  //----------------------------------------------------------------------
  // test_case_end
  //----------------------------------------------------------------------

  task test_case_end();
    test_running = 1'b0;
  endtask

  //----------------------------------------------------------------------
  // trace
  //----------------------------------------------------------------------

  task trace( string msg_to_trace );
    if( test_running & verbose )
      $display( msg_to_trace );
  endtask

endmodule

//------------------------------------------------------------------------
// CHECK_EQ
//------------------------------------------------------------------------
// Compare two expressions which can be signals or constants. We use the
// XOR operator so that an X in __ref will match 0, 1, or X in __dut, but
// an X in __dut will only match an X in __ref.

`define CHECK_EQ( __dut, __ref )                                        \
  if ( __ref !== ( __ref ^ __dut ^ __ref ) ) begin                      \
    if ( t.verbose )                                              \
      $display( "\n%sERROR%s (cycle=%0d): %s != %s (%b != %b)",         \
                `RED, `RESET, t.cycles, `"__dut`", `"__ref`",           \
                __dut, __ref );                                         \
    else                                                                \
      $write( "%sF%s", `RED, `RESET );                                  \
    t.failed = 1;                                                       \
    TestStatus::test_fail();                                            \
  end                                                                   \
  else begin                                                            \
    if ( !t.verbose )                                              \
      $write( "%s.%s", `GREEN, `RESET );                                \
  end                                                                   \
  if (1)

`endif // TEST_TEST_UTILS_V
