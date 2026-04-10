//========================================================================
// BlimpV8_jal_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_jal #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/jal_test_cases.v"
  `include "hw/top/test/test_cases/golden/jal_test_cases.v"
  `BLIMPV8_SUITE_RUN(jal, run_golden_jal_tests();)
endmodule

module BlimpV8_jal_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_jal
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
