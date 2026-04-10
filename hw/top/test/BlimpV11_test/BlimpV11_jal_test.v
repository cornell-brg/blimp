//========================================================================
// BlimpV11_jal_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_jal #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/jal_test_cases.v"
  `include "hw/top/test/test_cases/golden/jal_test_cases.v"
  `BLIMPV11_SUITE_RUN(jal, run_golden_jal_tests();)
endmodule

module BlimpV11_jal_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_jal
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
