//========================================================================
// BlimpV11_lw_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_lw #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/lw_test_cases.v"
  `include "hw/top/test/test_cases/golden/lw_test_cases.v"
  `BLIMPV11_SUITE_RUN(lw, run_golden_lw_tests();)
endmodule

module BlimpV11_lw_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_lw
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
