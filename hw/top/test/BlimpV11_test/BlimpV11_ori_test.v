//========================================================================
// BlimpV11_ori_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_ori #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/ori_test_cases.v"
  `BLIMPV11_SUITE_RUN(ori)
endmodule

module BlimpV11_ori_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_ori
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
