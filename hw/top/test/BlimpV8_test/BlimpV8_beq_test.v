//========================================================================
// BlimpV8_beq_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_beq #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/beq_test_cases.v"
  `BLIMPV8_SUITE_RUN(beq)
endmodule

module BlimpV8_beq_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_beq
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
