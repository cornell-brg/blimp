//========================================================================
// BlimpV8_sb_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_sb #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/sb_test_cases.v"
  `BLIMPV8_SUITE_RUN(sb)
endmodule

module BlimpV8_sb_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_sb
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
