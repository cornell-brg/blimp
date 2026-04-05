//========================================================================
// BlimpV8_sll_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_sll #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/sll_test_cases.v"
  `BLIMPV8_SUITE_RUN(sll)
endmodule

module BlimpV8_sll_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_sll
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
