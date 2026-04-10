//========================================================================
// BlimpV11_beq_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"
`include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"

module BlimpV11TestSuite_beq #( `BLIMPV11_SUITE_PARAMS );
  `BLIMPV11_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/beq_test_cases.v"
  `BLIMPV11_SUITE_RUN(beq)
endmodule

module BlimpV11_beq_test;
  `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_beq
  `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
endmodule
