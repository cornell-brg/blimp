//========================================================================
// BlimpV8_test_suites.vh
//========================================================================
// Shared macros and test suite instantiation template for BlimpV8 tests.
//
// Usage (with golden tests):
//
//   `include "hw/top/test/BlimpV8TestHarness.v"
//   `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
//
//   module BlimpV8TestSuite_add #( `BLIMPV8_SUITE_PARAMS );
//     `BLIMPV8_SUITE_HARNESS
//     `include "hw/top/test/test_cases/directed/add_test_cases.v"
//     `include "hw/top/test/test_cases/golden/add_test_cases.v"
//     `BLIMPV8_SUITE_RUN(add, run_golden_add_tests();)
//   endmodule
//
//   module BlimpV8_add_test;
//     `define BLIMPV8_SUITE_MODULE BlimpV8TestSuite_add
//     `include "hw/top/test/BlimpV8_test/BlimpV8_test_suites.vh"
//   endmodule
//
// Usage (directed tests only):
//
//   module BlimpV8TestSuite_fence #( `BLIMPV8_SUITE_PARAMS );
//     `BLIMPV8_SUITE_HARNESS
//     `include "hw/top/test/test_cases/directed/fence_test_cases.v"
//     `BLIMPV8_SUITE_RUN(fence)
//   endmodule

`ifndef _BLIMPV8_TEST_SUITES_VH
`define _BLIMPV8_TEST_SUITES_VH

//----------------------------------------------------------------------
// Suite Module Parameters
//----------------------------------------------------------------------

// verilator lint_off DECLFILENAME

`define BLIMPV8_SUITE_PARAMS \
  parameter p_suite_num              = 0,  \
  parameter p_opaq_bits              = 8,  \
  parameter p_seq_num_bits           = 5,  \
  parameter p_num_phys_regs          = 36, \
  parameter p_reclaim_width          = 2,  \
  parameter p_max_in_flight          = 8,  \
  parameter p_x_intf_fifo_depth      = 1,  \
  parameter p_alu_d_intf_fifo_depth  = 1,  \
  parameter p_mul_d_intf_fifo_depth  = 1,  \
  parameter p_mem_d_intf_fifo_depth  = 1,  \
  parameter p_ctrl_d_intf_fifo_depth = 1,  \
  parameter p_num_alus               = 2,  \
  parameter p_num_muls               = 2,  \
  parameter p_num_ldstrs             = 1,  \
  parameter p_num_pipes              = p_num_alus + p_num_muls + p_num_ldstrs + 1, \
  parameter p_mem_send_intv_delay    = 1,  \
  parameter p_mem_recv_intv_delay    = 1

//----------------------------------------------------------------------
// Suite Harness Instantiation
//----------------------------------------------------------------------

`define BLIMPV8_SUITE_HARNESS \
  string suite_name = $sformatf("%0d: BlimpV8TestSuite_%0d_%0d_%0d_%0d_%0d", \
                                p_suite_num, \
                                p_opaq_bits, p_seq_num_bits, p_num_phys_regs, \
                                p_mem_send_intv_delay, p_mem_recv_intv_delay); \
  BlimpV8TestHarness #( \
    .p_opaq_bits              (p_opaq_bits), \
    .p_seq_num_bits           (p_seq_num_bits), \
    .p_num_phys_regs          (p_num_phys_regs), \
    .p_reclaim_width          (p_reclaim_width), \
    .p_max_in_flight          (p_max_in_flight), \
    .p_x_intf_fifo_depth      (p_x_intf_fifo_depth), \
    .p_alu_d_intf_fifo_depth  (p_alu_d_intf_fifo_depth), \
    .p_mul_d_intf_fifo_depth  (p_mul_d_intf_fifo_depth), \
    .p_mem_d_intf_fifo_depth  (p_mem_d_intf_fifo_depth), \
    .p_ctrl_d_intf_fifo_depth (p_ctrl_d_intf_fifo_depth), \
    .p_num_alus               (p_num_alus), \
    .p_num_muls               (p_num_muls), \
    .p_num_ldstrs             (p_num_ldstrs), \
    .p_num_pipes              (p_num_pipes), \
    .p_mem_send_intv_delay    (p_mem_send_intv_delay), \
    .p_mem_recv_intv_delay    (p_mem_recv_intv_delay) \
  ) h();

//----------------------------------------------------------------------
// Suite Run Task
//----------------------------------------------------------------------
// SUFFIX:      instruction name (e.g. add, bne, fence)
// GOLDEN_CALL: optional golden test call (e.g. run_golden_add_tests();)
//              omit for tests without golden test cases.

`define BLIMPV8_SUITE_RUN(SUFFIX, GOLDEN_CALL=) \
  task run_test_suite(); \
    h.t.test_suite_begin( suite_name ); \
    run_directed_``SUFFIX``_tests(); \
    GOLDEN_CALL \
  endtask

`endif /* _BLIMPV8_TEST_SUITES_VH */

//======================================================================
// Suite Instantiation Template
//======================================================================
// Included when BLIMPV8_SUITE_MODULE is defined. Instantiates all
// standard test suites and the run block.

`ifdef BLIMPV8_SUITE_MODULE

  // Suite 1: Default (2 ALUs, 2 MULs, 1 LDSTR)
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num (1)
  ) suite_1();

  // Suite 2: Minimal (1 ALU, 1 MUL, 1 LDSTR)
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num (2),
    .p_num_alus  (1),
    .p_num_muls  (1)
  ) suite_2();

  //----------------------------------------------------------------------
  // Parameter variation test suites
  //----------------------------------------------------------------------

  // Suite 3: Small opaq (4-bit), small seq (3-bit), 34 phys regs
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num     (3),
    .p_opaq_bits     (4),
    .p_seq_num_bits  (3),
    .p_num_phys_regs (34)
  ) suite_3();

  // Suite 4: Large opaq (32-bit), 4-bit seq, 50 phys regs
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num     (4),
    .p_opaq_bits     (32),
    .p_seq_num_bits  (4),
    .p_num_phys_regs (50)
  ) suite_4();

  // Suite 5: Tiny opaq/seq (2/2), 48 phys regs, slow mem recv (3)
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num           (5),
    .p_opaq_bits           (2),
    .p_seq_num_bits        (2),
    .p_num_phys_regs       (48),
    .p_mem_recv_intv_delay (3)
  ) suite_5();

  // Suite 6: 4-bit opaq, 6-bit seq, 42 phys regs, slow mem send/recv (3/3)
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num           (6),
    .p_opaq_bits           (4),
    .p_seq_num_bits        (6),
    .p_num_phys_regs       (42),
    .p_mem_send_intv_delay (3),
    .p_mem_recv_intv_delay (3)
  ) suite_6();

  //----------------------------------------------------------------------
  // FIFO depth and microarchitectural variation suites
  //----------------------------------------------------------------------

  // Suite 7: Shallow FIFOs (depth=2 for all inter-stage FIFOs)
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num             (7),
    .p_x_intf_fifo_depth     (2),
    .p_alu_d_intf_fifo_depth (2),
    .p_mul_d_intf_fifo_depth (2),
    .p_mem_d_intf_fifo_depth (2)
  ) suite_7();

  // Suite 8: Single-entry reclaim width (slower seq num freeing)
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num     (8),
    .p_reclaim_width (1)
  ) suite_8();

  // Suite 9: Low max_in_flight (4), stresses issue queue pressure
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num     (9),
    .p_max_in_flight (4)
  ) suite_9();

  // Suite 10: Combined stress — shallow FIFOs, low max_in_flight, slow
  //           mem, single reclaim
  `BLIMPV8_SUITE_MODULE #(
    .p_suite_num             (10),
    .p_reclaim_width         (1),
    .p_max_in_flight         (4),
    .p_mem_send_intv_delay   (2),
    .p_mem_recv_intv_delay   (2),
    .p_x_intf_fifo_depth     (2),
    .p_alu_d_intf_fifo_depth (2),
    .p_mul_d_intf_fifo_depth (2),
    .p_mem_d_intf_fifo_depth (2)
  ) suite_10();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s ==  1)) suite_1.run_test_suite();
    if ((s <= 0) || (s ==  2)) suite_2.run_test_suite();
    if ((s <= 0) || (s ==  3)) suite_3.run_test_suite();
    if ((s <= 0) || (s ==  4)) suite_4.run_test_suite();
    if ((s <= 0) || (s ==  5)) suite_5.run_test_suite();
    if ((s <= 0) || (s ==  6)) suite_6.run_test_suite();
    if ((s <= 0) || (s ==  7)) suite_7.run_test_suite();
    if ((s <= 0) || (s ==  8)) suite_8.run_test_suite();
    if ((s <= 0) || (s ==  9)) suite_9.run_test_suite();
    if ((s <= 0) || (s == 10)) suite_10.run_test_suite();

    test_bench_end();
  end

`undef BLIMPV8_SUITE_MODULE
`endif
