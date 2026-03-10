//========================================================================
// BlimpV11_or_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_or #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/or_test_cases.v"
  `BLIMPV11_SUITE_RUN(or)
endmodule

module BlimpV11_or_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_or
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
