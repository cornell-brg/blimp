//========================================================================
// FLTestUtils.v
//========================================================================
// Simplified testing utilities, to be used in FL testers
// Adapted from ECE2300, Cornell University

`ifndef TEST_FL_TEST_UTILS_V
`define TEST_FL_TEST_UTILS_V

`include "test/TestUtils.v"

//========================================================================
// FLTestUtils
//========================================================================

module FLTestUtils
(
  input logic clk,
  input logic rst
);

  // Error count

  // verilator lint_off UNUSEDSIGNAL
  logic failed = 0;
  // verilator lint_on UNUSEDSIGNAL

  // ---------------------------------------------------------------------
  // Filtering Utilities
  // ---------------------------------------------------------------------

  // verilator lint_off UNUSEDSIGNAL
  string filter;
  logic filtered;
  logic verbose;
  // verilator lint_on UNUSEDSIGNAL

  initial begin
    if ( !$value$plusargs( "filter=%s", filter ) )
      filtered = 1'b0;
    else
      filtered = 1'b1;
  end

  initial begin
    if ($test$plusargs ("v"))
      verbose = 1'b1;
    else
      verbose = 1'b0;
  end

  // Always call $urandom with this seed variable to ensure that random
  // test cases are both isolated and reproducible.

  // verilator lint_off UNUSEDSIGNAL
  int seed = 32'hdeadbeef;
  // verilator lint_on UNUSEDSIGNAL

  // Cycle counter with timeout check

  int cycles;

  always @( posedge clk ) begin

    if ( rst )
      cycles <= 0;
    else
      cycles <= cycles + 1;

  end

endmodule

`endif // TEST_FL_TEST_UTILS_V
