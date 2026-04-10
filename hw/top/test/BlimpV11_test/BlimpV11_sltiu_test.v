//========================================================================
// BlimpV11_sltiu_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_sltiu #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/sltiu_test_cases.v"
  `BLIMPV11_SUITE_RUN(sltiu)
endmodule

module BlimpV11_sltiu_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_sltiu
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
