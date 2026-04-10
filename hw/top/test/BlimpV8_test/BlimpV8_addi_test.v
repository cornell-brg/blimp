//========================================================================
// BlimpV8_addi_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_addi #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/addi_test_cases.v"
  `include "hw/top/test/test_cases/golden/addi_test_cases.v"
  `BLIMPV8_SUITE_RUN(addi, run_golden_addi_tests();)
endmodule

module BlimpV8_addi_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_addi
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
