//========================================================================
// BlimpV11_add_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_add #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/add_test_cases.v"
  `include "hw/top/test/test_cases/golden/add_test_cases.v"
  `BLIMPV11_SUITE_RUN(add, run_golden_add_tests();)
endmodule

module BlimpV11_add_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_add
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
