//========================================================================
// BlimpV8_srai_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_srai #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/srai_test_cases.v"
  `BLIMPV8_SUITE_RUN(srai)
endmodule

module BlimpV8_srai_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_srai
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
