//========================================================================
// BlimpV8_jalr_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_jalr #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/jalr_test_cases.v"
  `include "hw/top/test/test_cases/golden/jalr_test_cases.v"
  `BLIMPV8_SUITE_RUN(jalr, run_golden_jalr_tests();)
endmodule

module BlimpV8_jalr_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_jalr
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
