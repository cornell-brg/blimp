//========================================================================
// BlimpV11_sw_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_sw #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/sw_test_cases.v"
  `include "hw/top/test/test_cases/golden/sw_test_cases.v"
  `BLIMPV11_SUITE_RUN(sw, run_golden_sw_tests();)
endmodule

module BlimpV11_sw_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_sw
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
