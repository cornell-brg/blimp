//========================================================================
// BlimpV11_mixed_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_mixed #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/mixed_test_cases.v"
  `include "hw/top/test/test_cases/golden/mixed_test_cases.v"
  `BLIMPV11_SUITE_RUN(mixed, run_golden_mixed_tests();)
endmodule

module BlimpV11_mixed_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_mixed
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
