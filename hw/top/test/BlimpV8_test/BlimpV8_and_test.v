//========================================================================
// BlimpV8_and_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_and #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/and_test_cases.v"
  `BLIMPV8_SUITE_RUN(and)
endmodule

module BlimpV8_and_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_and
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
