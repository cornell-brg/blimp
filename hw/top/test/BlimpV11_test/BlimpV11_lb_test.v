//========================================================================
// BlimpV11_lb_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_lb #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/lb_test_cases.v"
  `BLIMPV11_SUITE_RUN(lb)
endmodule

module BlimpV11_lb_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_lb
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
