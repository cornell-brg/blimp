//========================================================================
// BlimpV11_addi_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_addi #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/addi_test_cases.v"
  `include "hw/top/test/test_cases/golden/addi_test_cases.v"
  `BLIMPV11_SUITE_RUN(addi, run_golden_addi_tests();)
endmodule

module BlimpV11_addi_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_addi
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
