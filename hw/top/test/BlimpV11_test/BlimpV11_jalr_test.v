//========================================================================
// BlimpV11_jalr_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_jalr #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/jalr_test_cases.v"
  `include "hw/top/test/test_cases/golden/jalr_test_cases.v"
  `BLIMPV11_SUITE_RUN(jalr, run_golden_jalr_tests();)
endmodule

module BlimpV11_jalr_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_jalr
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
