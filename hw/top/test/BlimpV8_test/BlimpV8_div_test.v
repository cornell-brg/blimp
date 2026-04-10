//========================================================================
// BlimpV8_div_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_div #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/div_test_cases.v"
  `BLIMPV8_SUITE_RUN(div)
endmodule

module BlimpV8_div_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_div
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
