//========================================================================
// BlimpV7_every_test.v
//========================================================================

`include "hw/top/test/BlimpV7TestHarness.v"

module BlimpV7_every_test;
  BlimpV7TestHarness #(
    .p_opaq_bits           (8),
    .p_seq_num_bits        (5),
    .p_num_phys_regs       (36),
    .p_mem_send_intv_delay (1),
    .p_mem_recv_intv_delay (1)
  ) h();

  `include "hw/top/test/test_cases/directed/add_test_cases.v"
  `include "hw/top/test/test_cases/directed/addi_test_cases.v"
  `include "hw/top/test/test_cases/directed/mul_test_cases.v"
  `include "hw/top/test/test_cases/directed/lw_test_cases.v"
  `include "hw/top/test/test_cases/directed/sw_test_cases.v"
  `include "hw/top/test/test_cases/directed/jal_test_cases.v"
  `include "hw/top/test/test_cases/directed/jalr_test_cases.v"
  `include "hw/top/test/test_cases/directed/bne_test_cases.v"

  `include "hw/top/test/test_cases/directed/sub_test_cases.v"
  `include "hw/top/test/test_cases/directed/and_test_cases.v"
  `include "hw/top/test/test_cases/directed/or_test_cases.v"
  `include "hw/top/test/test_cases/directed/xor_test_cases.v"
  `include "hw/top/test/test_cases/directed/slt_test_cases.v"
  `include "hw/top/test/test_cases/directed/sltu_test_cases.v"
  `include "hw/top/test/test_cases/directed/sra_test_cases.v"
  `include "hw/top/test/test_cases/directed/srl_test_cases.v"
  `include "hw/top/test/test_cases/directed/sll_test_cases.v"

  `include "hw/top/test/test_cases/directed/andi_test_cases.v"
  `include "hw/top/test/test_cases/directed/ori_test_cases.v"
  `include "hw/top/test/test_cases/directed/xori_test_cases.v"
  `include "hw/top/test/test_cases/directed/slti_test_cases.v"
  `include "hw/top/test/test_cases/directed/sltiu_test_cases.v"
  `include "hw/top/test/test_cases/directed/srai_test_cases.v"
  `include "hw/top/test/test_cases/directed/srli_test_cases.v"
  `include "hw/top/test/test_cases/directed/slli_test_cases.v"
  `include "hw/top/test/test_cases/directed/lui_test_cases.v"
  `include "hw/top/test/test_cases/directed/auipc_test_cases.v"

  `include "hw/top/test/test_cases/directed/beq_test_cases.v"
  `include "hw/top/test/test_cases/directed/blt_test_cases.v"
  `include "hw/top/test/test_cases/directed/bge_test_cases.v"
  `include "hw/top/test/test_cases/directed/bltu_test_cases.v"
  `include "hw/top/test/test_cases/directed/bgeu_test_cases.v"

  `include "hw/top/test/test_cases/golden/add_test_cases.v"
  `include "hw/top/test/test_cases/golden/addi_test_cases.v"
  `include "hw/top/test/test_cases/golden/bne_test_cases.v"
  `include "hw/top/test/test_cases/golden/jal_test_cases.v"
  `include "hw/top/test/test_cases/golden/jalr_test_cases.v"
  `include "hw/top/test/test_cases/golden/lw_test_cases.v"
  `include "hw/top/test/test_cases/golden/mul_test_cases.v"
  `include "hw/top/test/test_cases/golden/sw_test_cases.v"

  integer seed = 32'hC252C252;

  `include "hw/top/test/test_cases/randomized/add_test_cases.v"
  `include "hw/top/test/test_cases/randomized/addi_test_cases.v"
  `include "hw/top/test/test_cases/randomized/bne_test_cases.v"
  `include "hw/top/test/test_cases/randomized/lw_test_cases.v"

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s ==  1)) run_directed_add_tests();
    if ((s <= 0) || (s ==  2)) run_directed_addi_tests();
    if ((s <= 0) || (s ==  3)) run_directed_mul_tests();
    if ((s <= 0) || (s ==  4)) run_directed_lw_tests();
    if ((s <= 0) || (s ==  5)) run_directed_sw_tests();
    if ((s <= 0) || (s ==  6)) run_directed_jal_tests();
    if ((s <= 0) || (s ==  7)) run_directed_jalr_tests();
    if ((s <= 0) || (s ==  8)) run_directed_bne_tests();

    if ((s <= 0) || (s ==  9)) run_directed_sub_tests();
    if ((s <= 0) || (s == 10)) run_directed_and_tests();
    if ((s <= 0) || (s == 11)) run_directed_or_tests();
    if ((s <= 0) || (s == 12)) run_directed_xor_tests();
    if ((s <= 0) || (s == 13)) run_directed_slt_tests();
    if ((s <= 0) || (s == 14)) run_directed_sltu_tests();
    if ((s <= 0) || (s == 15)) run_directed_sra_tests();
    if ((s <= 0) || (s == 16)) run_directed_srl_tests();
    if ((s <= 0) || (s == 17)) run_directed_sll_tests();

    if ((s <= 0) || (s == 18)) run_directed_andi_tests();
    if ((s <= 0) || (s == 19)) run_directed_ori_tests();
    if ((s <= 0) || (s == 20)) run_directed_xori_tests();
    if ((s <= 0) || (s == 21)) run_directed_slti_tests();
    if ((s <= 0) || (s == 22)) run_directed_sltiu_tests();
    if ((s <= 0) || (s == 23)) run_directed_srai_tests();
    if ((s <= 0) || (s == 24)) run_directed_srli_tests();
    if ((s <= 0) || (s == 25)) run_directed_slli_tests();
    if ((s <= 0) || (s == 26)) run_directed_lui_tests();
    if ((s <= 0) || (s == 27)) run_directed_auipc_tests();

    if ((s <= 0) || (s == 28)) run_directed_beq_tests();
    if ((s <= 0) || (s == 29)) run_directed_blt_tests();
    if ((s <= 0) || (s == 30)) run_directed_bge_tests();
    if ((s <= 0) || (s == 31)) run_directed_bltu_tests();
    if ((s <= 0) || (s == 32)) run_directed_bgeu_tests();

    if ((s <= 0) || (s == 33)) run_golden_add_tests();
    if ((s <= 0) || (s == 34)) run_golden_addi_tests();
    if ((s <= 0) || (s == 35)) run_golden_bne_tests();
    if ((s <= 0) || (s == 36)) run_golden_jal_tests();
    if ((s <= 0) || (s == 37)) run_golden_jalr_tests();
    if ((s <= 0) || (s == 38)) run_golden_lw_tests();
    if ((s <= 0) || (s == 39)) run_golden_mul_tests();
    if ((s <= 0) || (s == 40)) run_golden_sw_tests();

    if ((s <= 0) || (s == 41)) run_randomized_add_tests();
    if ((s <= 0) || (s == 42)) run_randomized_addi_tests();
    if ((s <= 0) || (s == 43)) run_randomized_bne_tests();
    if ((s <= 0) || (s == 44)) run_randomized_lw_tests();

    test_bench_end();
  end
endmodule
