//========================================================================
// BlimpV11_test_suites.vh
//========================================================================
// Shared macros and test suite instantiation template for BlimpV11 tests.
//
// Usage (with golden tests):
//
//   `include "hw/top/test/BlimpV11TestHarness.v"
//   `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
//
//   module BlimpV11TestSuite_add #( `BLIMPV11_SUITE_PARAMS );
//     `BLIMPV11_SUITE_HARNESS
//     `include "hw/top/test/test_cases/directed/add_test_cases.v"
//     `include "hw/top/test/test_cases/golden/add_test_cases.v"
//     `BLIMPV11_SUITE_RUN(add, run_golden_add_tests();)
//   endmodule
//
//   module BlimpV11_add_test;
//     `define BLIMPV11_SUITE_MODULE BlimpV11TestSuite_add
//     `include "hw/top/test/BlimpV11_test/BlimpV11_test_suites.vh"
//   endmodule
//
// Usage (directed tests only):
//
//   module BlimpV11TestSuite_fence #( `BLIMPV11_SUITE_PARAMS );
//     `BLIMPV11_SUITE_HARNESS
//     `include "hw/top/test/test_cases/directed/fence_test_cases.v"
//     `BLIMPV11_SUITE_RUN(fence)
//   endmodule

`ifndef _BLIMPV11_TEST_SUITES_VH
`define _BLIMPV11_TEST_SUITES_VH

//----------------------------------------------------------------------
// Suite Module Parameters
//----------------------------------------------------------------------

// verilator lint_off DECLFILENAME

`define BLIMPV11_SUITE_PARAMS \
  parameter p_suite_num              = 0,  \
  parameter p_opaq_bits              = 8,  \
  parameter p_seq_num_bits           = 5,  \
  parameter p_num_phys_regs          = 36, \
  parameter p_num_be_lanes           = 2,  \
  parameter p_iq_depth               = 4,  \
  parameter p_reclaim_width          = p_num_be_lanes, \
  parameter p_max_in_flight          = 8,  \
  parameter p_mem_send_intv_delay    = 1,  \
  parameter p_mem_recv_intv_delay    = 1,  \
  parameter p_num_fe_lanes           = 2,  \
  parameter p_f_intf_fifo_depth      = 4,  \
  parameter p_f_intf_fifo_bypass     = 0,  \
  parameter p_x_intf_fifo_depth      = 4,  \
  parameter p_x_intf_fifo_bypass     = 0,  \
  parameter p_alu_d_intf_fifo_depth  = 4,  \
  parameter p_mul_d_intf_fifo_depth  = 4,  \
  parameter p_mem_d_intf_fifo_depth  = 4,  \
  parameter p_mem_d_intf_fifo_bypass = 0,  \
  parameter p_num_pipes              = 8,  \
  parameter p_all_iq_in_order        = 0,  \
  parameter [p_num_fe_lanes*8-1:0] p_sim_f2d_bp = '0, \
  parameter [p_num_pipes*8-1:0]    p_sim_d2x_bp = '0, \
  parameter [p_num_pipes*8-1:0]    p_sim_x2w_bp = '0

//----------------------------------------------------------------------
// Suite Harness Instantiation
//----------------------------------------------------------------------

`define BLIMPV11_SUITE_HARNESS \
  string suite_name = $sformatf("%0d: BlimpV11TestSuite_%0d_%0d_%0d_%0d_%0d_%0d_%0d_%0d", \
                                p_suite_num, \
                                p_opaq_bits, p_seq_num_bits, p_num_phys_regs, p_num_be_lanes, p_iq_depth, \
                                p_mem_send_intv_delay, p_mem_recv_intv_delay, \
                                p_num_fe_lanes); \
  BlimpV11TestHarness #( \
    .p_opaq_bits              (p_opaq_bits), \
    .p_seq_num_bits           (p_seq_num_bits), \
    .p_num_phys_regs          (p_num_phys_regs), \
    .p_num_be_lanes           (p_num_be_lanes), \
    .p_iq_depth               (p_iq_depth), \
    .p_reclaim_width          (p_reclaim_width), \
    .p_max_in_flight          (p_max_in_flight), \
    .p_mem_send_intv_delay    (p_mem_send_intv_delay), \
    .p_mem_recv_intv_delay    (p_mem_recv_intv_delay), \
    .p_num_fe_lanes           (p_num_fe_lanes), \
    .p_f_intf_fifo_depth      (p_f_intf_fifo_depth), \
    .p_f_intf_fifo_bypass     (p_f_intf_fifo_bypass), \
    .p_x_intf_fifo_depth      (p_x_intf_fifo_depth), \
    .p_x_intf_fifo_bypass     (p_x_intf_fifo_bypass), \
    .p_alu_d_intf_fifo_depth  (p_alu_d_intf_fifo_depth), \
    .p_mul_d_intf_fifo_depth  (p_mul_d_intf_fifo_depth), \
    .p_mem_d_intf_fifo_depth  (p_mem_d_intf_fifo_depth), \
    .p_mem_d_intf_fifo_bypass (p_mem_d_intf_fifo_bypass), \
    .p_num_pipes              (p_num_pipes), \
    .p_all_iq_in_order        (p_all_iq_in_order), \
    .p_sim_f2d_bp             (p_sim_f2d_bp), \
    .p_sim_d2x_bp             (p_sim_d2x_bp), \
    .p_sim_x2w_bp             (p_sim_x2w_bp) \
  ) h();

//----------------------------------------------------------------------
// Suite Run Task
//----------------------------------------------------------------------
// SUFFIX:      instruction name (e.g. add, bne, fence)
// GOLDEN_CALL: optional golden test call (e.g. run_golden_add_tests();)
//              omit for tests without golden test cases.

`define BLIMPV11_SUITE_RUN(SUFFIX, GOLDEN_CALL=) \
  task run_test_suite(); \
    h.t.test_suite_begin( suite_name ); \
    run_directed_``SUFFIX``_tests(); \
    GOLDEN_CALL \
  endtask

`endif /* _BLIMPV11_TEST_SUITES_VH */

//======================================================================
// Suite Instantiation Template
//======================================================================
// Included when BLIMPV11_SUITE_MODULE is defined. Instantiates all
// standard test suites and the run block.

`ifdef BLIMPV11_SUITE_MODULE

  // Suite 1: Default (2 FE / 2 BE lanes)
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num (1)
  ) suite_1();

  // Suite 2: Minimal (1 FE / 1 BE lane)
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (2),
    .p_num_fe_lanes (1),
    .p_num_be_lanes (1)
  ) suite_2();

  //----------------------------------------------------------------------
  // Backpressure test suites (4 FE / 4 BE lanes)
  // Note: never put bp on ctrl pipe (pipe 7 in d2x) — causes livelock
  //----------------------------------------------------------------------

  // Suite 3: Uniform F2D backpressure (stall 1 every 3 cycles, all lanes)
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (3),
    .p_num_fe_lanes (4),
    .p_num_be_lanes (4),
    .p_sim_f2d_bp   ({8'd3, 8'd3, 8'd3, 8'd3})
  ) suite_3();

  // Suite 4: Staggered per-lane F2D backpressure (intervals 5,3,7,4)
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (4),
    .p_num_fe_lanes (4),
    .p_num_be_lanes (4),
    .p_sim_f2d_bp   ({8'd5, 8'd3, 8'd7, 8'd4})
  ) suite_4();

  // Suite 5: D2X backpressure on ALU and MUL pipes (not ctrl pipe 7)
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (5),
    .p_num_fe_lanes (4),
    .p_num_be_lanes (4),
    .p_sim_d2x_bp   ({8'd0, 8'd0, 8'd4, 8'd3, 8'd0, 8'd0, 8'd5, 8'd3})
  ) suite_5();

  // Suite 6: X2W backpressure on ALU and MEM pipes
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (6),
    .p_num_fe_lanes (4),
    .p_num_be_lanes (4),
    .p_sim_x2w_bp   ({8'd0, 8'd0, 8'd3, 8'd4, 8'd0, 8'd0, 8'd4, 8'd3})
  ) suite_6();

  // Suite 7: Combined F2D + D2X + X2W backpressure
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (7),
    .p_num_fe_lanes (4),
    .p_num_be_lanes (4),
    .p_sim_f2d_bp   ({8'd5, 8'd3, 8'd7, 8'd4}),
    .p_sim_d2x_bp   ({8'd0, 8'd0, 8'd3, 8'd4, 8'd0, 8'd0, 8'd5, 8'd3}),
    .p_sim_x2w_bp   ({8'd0, 8'd0, 8'd4, 8'd3, 8'd0, 8'd0, 8'd3, 8'd4})
  ) suite_7();

  //----------------------------------------------------------------------
  // Parameter variation test suites
  //----------------------------------------------------------------------

  // Suite 8: Small opaq (4-bit), small seq (3-bit), 34 phys regs
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num     (8),
    .p_opaq_bits     (4),
    .p_seq_num_bits  (3),
    .p_num_phys_regs (34)
  ) suite_8();

  // Suite 9: Large opaq (32-bit), 4-bit seq, 50 phys regs
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num     (9),
    .p_opaq_bits     (32),
    .p_seq_num_bits  (4),
    .p_num_phys_regs (50)
  ) suite_9();

  // Suite 10: Tiny opaq/seq (2/2), 48 phys regs, slow mem recv (3)
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num           (10),
    .p_opaq_bits           (2),
    .p_seq_num_bits        (2),
    .p_num_phys_regs       (48),
    .p_mem_recv_intv_delay (3)
  ) suite_10();

  // Suite 11: 4-bit opaq, 6-bit seq, 42 phys regs, slow mem send/recv (3/3)
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num           (11),
    .p_opaq_bits           (4),
    .p_seq_num_bits        (6),
    .p_num_phys_regs       (42),
    .p_mem_send_intv_delay (3),
    .p_mem_recv_intv_delay (3)
  ) suite_11();

  // Suite 12: 4 FE lanes, 2 BE lanes
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (12),
    .p_num_fe_lanes (4)
  ) suite_12();

  // Suite 13: 4 FE / 4 BE lanes
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (13),
    .p_num_fe_lanes (4),
    .p_num_be_lanes (4)
  ) suite_13();

  // Suite 14: 2 FE / 4 BE lanes
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (14),
    .p_num_be_lanes (4)
  ) suite_14();

  // Suite 15: 3 FE / 4 BE lanes
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num    (15),
    .p_num_fe_lanes (3),
    .p_num_be_lanes (4)
  ) suite_15();

  // Suite 16: 2-bit seq, 35 phys regs, 4 FE / 4 BE lanes
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num     (16),
    .p_seq_num_bits  (2),
    .p_num_phys_regs (35),
    .p_num_fe_lanes  (4),
    .p_num_be_lanes  (4)
  ) suite_16();

  // Suite 17: 2-bit seq, 35 phys regs, 4 FE / 4 BE, all FIFO bypass
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num              (17),
    .p_seq_num_bits           (2),
    .p_num_phys_regs          (35),
    .p_num_fe_lanes           (4),
    .p_num_be_lanes           (4),
    .p_f_intf_fifo_bypass     (1),
    .p_x_intf_fifo_bypass     (1),
    .p_mem_d_intf_fifo_bypass (1)
  ) suite_17();

  //----------------------------------------------------------------------
  // FIFO depth and microarchitectural variation suites
  //----------------------------------------------------------------------

  // Suite 18: Shallow FIFOs (depth=2 for all inter-stage FIFOs)
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num             (18),
    .p_f_intf_fifo_depth     (2),
    .p_x_intf_fifo_depth     (2),
    .p_alu_d_intf_fifo_depth (2),
    .p_mul_d_intf_fifo_depth (2),
    .p_mem_d_intf_fifo_depth (2)
  ) suite_18();

  // Suite 19: Single-entry reclaim width (slower seq num freeing)
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num     (19),
    .p_reclaim_width (1)
  ) suite_19();

  // Suite 20: Low max_in_flight (4), stresses issue queue pressure
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num      (20),
    .p_max_in_flight  (4)
  ) suite_20();

  // Suite 21: Shallow FIFOs (depth=2) + F2D backpressure, 4 FE / 4 BE
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num             (21),
    .p_num_fe_lanes          (4),
    .p_num_be_lanes          (4),
    .p_f_intf_fifo_depth     (2),
    .p_x_intf_fifo_depth     (2),
    .p_alu_d_intf_fifo_depth (2),
    .p_mul_d_intf_fifo_depth (2),
    .p_mem_d_intf_fifo_depth (2),
    .p_sim_f2d_bp            ({8'd4, 8'd3, 8'd5, 8'd4})
  ) suite_21();

  // Suite 22: Combined stress — shallow FIFOs, low max_in_flight, slow
  //           mem, single reclaim, combined backpressure
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num             (22),
    .p_num_fe_lanes          (4),
    .p_num_be_lanes          (4),
    .p_reclaim_width         (1),
    .p_max_in_flight         (4),
    .p_mem_send_intv_delay   (2),
    .p_mem_recv_intv_delay   (2),
    .p_f_intf_fifo_depth     (2),
    .p_x_intf_fifo_depth     (2),
    .p_alu_d_intf_fifo_depth (2),
    .p_mul_d_intf_fifo_depth (2),
    .p_mem_d_intf_fifo_depth (2),
    .p_sim_f2d_bp            ({8'd5, 8'd3, 8'd7, 8'd4}),
    .p_sim_d2x_bp            ({8'd0, 8'd0, 8'd4, 8'd3, 8'd0, 8'd0, 8'd5, 8'd3}),
    .p_sim_x2w_bp            ({8'd0, 8'd0, 8'd3, 8'd4, 8'd0, 8'd0, 8'd4, 8'd3})
  ) suite_22();

  // Suite 23: Deep FIFOs (depth=8), 4 FE / 4 BE, FIFO bypass on F and X
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num             (23),
    .p_num_fe_lanes          (4),
    .p_num_be_lanes          (4),
    .p_f_intf_fifo_depth     (8),
    .p_f_intf_fifo_bypass    (1),
    .p_x_intf_fifo_depth     (8),
    .p_x_intf_fifo_bypass    (1),
    .p_alu_d_intf_fifo_depth (8),
    .p_mul_d_intf_fifo_depth (8),
    .p_mem_d_intf_fifo_depth (8)
  ) suite_23();

  // Suite 24: Minimal depth (1) for F and X FIFOs with bypass, 4 FE / 4 BE
  `BLIMPV11_SUITE_MODULE #(
    .p_suite_num          (24),
    .p_num_fe_lanes       (4),
    .p_num_be_lanes       (4),
    .p_f_intf_fifo_depth  (1),
    .p_f_intf_fifo_bypass (1),
    .p_x_intf_fifo_depth  (1),
    .p_x_intf_fifo_bypass (1)
  ) suite_24();

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
    if ((s <= 0) || (s == 11)) suite_11.run_test_suite();
    if ((s <= 0) || (s == 12)) suite_12.run_test_suite();
    if ((s <= 0) || (s == 13)) suite_13.run_test_suite();
    if ((s <= 0) || (s == 14)) suite_14.run_test_suite();
    if ((s <= 0) || (s == 15)) suite_15.run_test_suite();
    if ((s <= 0) || (s == 16)) suite_16.run_test_suite();
    if ((s <= 0) || (s == 17)) suite_17.run_test_suite();
    if ((s <= 0) || (s == 18)) suite_18.run_test_suite();
    if ((s <= 0) || (s == 19)) suite_19.run_test_suite();
    if ((s <= 0) || (s == 20)) suite_20.run_test_suite();
    if ((s <= 0) || (s == 21)) suite_21.run_test_suite();
    if ((s <= 0) || (s == 22)) suite_22.run_test_suite();
    if ((s <= 0) || (s == 23)) suite_23.run_test_suite();
    if ((s <= 0) || (s == 24)) suite_24.run_test_suite();

    test_bench_end();
  end

`undef BLIMPV11_SUITE_MODULE
`endif
