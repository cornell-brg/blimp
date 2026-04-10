//========================================================================
// BlimpV11_sra_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_sra #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/sra_test_cases.v"
  `BLIMPV11_SUITE_RUN(sra)
endmodule

module BlimpV11_sra_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_sra
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
