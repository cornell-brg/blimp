//========================================================================
// BlimpV8_bne_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_bne #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/bne_test_cases.v"
  `include "hw/top/test/test_cases/golden/bne_test_cases.v"
  `BLIMPV8_SUITE_RUN(bne, run_golden_bne_tests();)
endmodule

module BlimpV8_bne_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_bne
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
