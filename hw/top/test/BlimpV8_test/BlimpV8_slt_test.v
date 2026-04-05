//========================================================================
// BlimpV8_slt_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_slt #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/slt_test_cases.v"
  `BLIMPV8_SUITE_RUN(slt)
endmodule

module BlimpV8_slt_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_slt
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
