//========================================================================
// BlimpV8_lw_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_lw #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/lw_test_cases.v"
  `include "hw/top/test/test_cases/golden/lw_test_cases.v"
  `BLIMPV8_SUITE_RUN(lw, run_golden_lw_tests();)
endmodule

module BlimpV8_lw_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_lw
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
