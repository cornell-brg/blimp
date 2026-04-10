//========================================================================
// BlimpV8_mulhsu_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"
`include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"

module BlimpV8TestSuite_mulhsu #( `BLIMPV8_SUITE_PARAMS );
  `BLIMPV8_SUITE_HARNESS

  `include "hw/top/test/test_cases/directed/mulhsu_test_cases.v"
  `BLIMPV8_SUITE_RUN(mulhsu)
endmodule

module BlimpV8_mulhsu_test;
  `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_mulhsu
  `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
endmodule
