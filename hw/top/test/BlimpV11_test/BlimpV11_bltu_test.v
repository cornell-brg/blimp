//========================================================================
// BlimpV11_bltu_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_bltu #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/bltu_test_cases.v"
  `BLIMPV11_SUITE_RUN(bltu)
endmodule

module BlimpV11_bltu_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_bltu
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
