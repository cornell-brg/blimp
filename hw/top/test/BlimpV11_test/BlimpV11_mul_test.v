//========================================================================
// BlimpV11_mul_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_mul #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/mul_test_cases.v"
  `include "hw/top/test/test_cases/golden/mul_test_cases.v"
  `BLIMPV11_SUITE_RUN(mul, run_golden_mul_tests();)
endmodule

module BlimpV11_mul_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_mul
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
