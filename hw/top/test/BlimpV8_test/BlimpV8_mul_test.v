//========================================================================
// BlimpV8_mul_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_mul #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/mul_test_cases.v"
  `include "hw/top/test/test_cases/golden/mul_test_cases.v"
  `BLIMPV8_SUITE_RUN(mul, run_golden_mul_tests();)
endmodule

module BlimpV8_mul_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_mul
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
