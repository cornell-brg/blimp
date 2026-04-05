//========================================================================
// BlimpV8_add_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_add #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/add_test_cases.v"
  `include "hw/top/test/test_cases/golden/add_test_cases.v"
  `BLIMPV8_SUITE_RUN(add, run_golden_add_tests();)
endmodule

module BlimpV8_add_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_add
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
