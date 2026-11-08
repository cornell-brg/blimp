//========================================================================
// BlimpV3_every_test.v
//========================================================================

`include "hw/top/test/BlimpV3TestHarness.v"

module BlimpV3_every_test;
  BlimpV3TestHarness #(
    .p_opaq_bits           (8),
    .p_seq_num_bits        (5),
    .p_num_phys_regs       (36),
    .p_mem_send_intv_delay (1),
    .p_mem_recv_intv_delay (1)
  ) h();

  `include "hw/top/test/test_cases/directed/add_test_cases.v"
  `include "hw/top/test/test_cases/directed/addi_test_cases.v"
  `include "hw/top/test/test_cases/directed/mul_test_cases.v"

  `include "hw/top/test/test_cases/golden/add_test_cases.v"
  `include "hw/top/test/test_cases/golden/addi_test_cases.v"
  `include "hw/top/test/test_cases/golden/mul_test_cases.v"

  integer seed = 32'hC252C252;

  `include "hw/top/test/test_cases/randomized/add_test_cases.v"
  `include "hw/top/test/test_cases/randomized/addi_test_cases.v"

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) run_directed_add_tests();
    if ((s <= 0) || (s == 2)) run_directed_addi_tests();
    if ((s <= 0) || (s == 3)) run_directed_mul_tests();

    if ((s <= 0) || (s == 4)) run_golden_add_tests();
    if ((s <= 0) || (s == 5)) run_golden_addi_tests();
    if ((s <= 0) || (s == 6)) run_golden_mul_tests();

    if ((s <= 0) || (s == 7)) run_randomized_add_tests();
    if ((s <= 0) || (s == 8)) run_randomized_addi_tests();

    test_bench_end();
  end
endmodule
