//========================================================================
// BlimpV11_xor_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_xor #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/xor_test_cases.v"
  `BLIMPV11_SUITE_RUN(xor)
endmodule

module BlimpV11_xor_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_xor
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
