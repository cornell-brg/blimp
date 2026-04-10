//========================================================================
// BlimpV11_bne_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_bne #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/bne_test_cases.v"
  `include "hw/top/test/test_cases/golden/bne_test_cases.v"
  `BLIMPV11_SUITE_RUN(bne, run_golden_bne_tests();)
endmodule

module BlimpV11_bne_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_bne
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
