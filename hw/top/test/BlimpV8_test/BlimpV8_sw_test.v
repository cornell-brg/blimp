//========================================================================
// BlimpV8_sw_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_sw #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/sw_test_cases.v"
  `include "hw/top/test/test_cases/golden/sw_test_cases.v"
  `BLIMPV8_SUITE_RUN(sw, run_golden_sw_tests();)
endmodule

module BlimpV8_sw_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_sw
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
