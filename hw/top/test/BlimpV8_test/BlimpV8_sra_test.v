//========================================================================
// BlimpV8_sra_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_sra #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/sra_test_cases.v"
  `BLIMPV8_SUITE_RUN(sra)
endmodule

module BlimpV8_sra_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_sra
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
