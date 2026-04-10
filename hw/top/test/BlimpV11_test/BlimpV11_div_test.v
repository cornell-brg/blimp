//========================================================================
// BlimpV11_div_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_div #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/div_test_cases.v"
  `BLIMPV11_SUITE_RUN(div)
endmodule

module BlimpV11_div_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_div
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
