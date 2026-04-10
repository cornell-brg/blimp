//========================================================================
// BlimpV11_divu_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_divu #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/divu_test_cases.v"
  `BLIMPV11_SUITE_RUN(divu)
endmodule

module BlimpV11_divu_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_divu
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
