//========================================================================
// BlimpV11_sh_test.v
//========================================================================

`include "hw/top/test/BlimpV11TestHarness.v"

module BlimpV11TestSuite_sh #(
  parameter p_suite_num     = 0,
  parameter p_opaq_bits     = 8,
  parameter p_seq_num_bits  = 5,
  parameter p_num_phys_regs = 36,
  parameter p_num_be_lanes  = 2,
  parameter p_iq_depth      = 4,

  parameter p_mem_send_intv_delay = 1,
  parameter p_mem_recv_intv_delay = 1,

  parameter p_num_fe_lanes        = 2
);
  string suite_name = $sformatf("%0d: BlimpV11TestSuite_%0d_%0d_%0d_%0d_%0d_%0d_%0d_%0d", 
                                p_suite_num,
                                p_opaq_bits, p_seq_num_bits, p_num_phys_regs, p_num_be_lanes, p_iq_depth,
                                p_mem_send_intv_delay, p_mem_recv_intv_delay,
                                p_num_fe_lanes);
  BlimpV11TestHarness #(
    .p_opaq_bits           (p_opaq_bits),
    .p_seq_num_bits        (p_seq_num_bits),
    .p_num_phys_regs       (p_num_phys_regs),
    .p_num_be_lanes        (p_num_be_lanes),
    .p_iq_depth            (p_iq_depth),
    .p_mem_send_intv_delay (p_mem_send_intv_delay),
    .p_mem_recv_intv_delay (p_mem_recv_intv_delay),
    .p_num_fe_lanes        (p_num_fe_lanes)
  ) h();

  `include "hw/top/test/test_cases/directed/sh_test_cases.v"
  task run_test_suite();
    h.t.test_suite_begin( suite_name );
    run_directed_sh_tests();
  endtask
endmodule

module BlimpV11_sh_test;
  BlimpV11TestSuite_sh #(
    .p_suite_num            (1)
  ) suite_1();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (2),
    .p_opaq_bits            (8),
    .p_seq_num_bits         (5),
    .p_num_phys_regs        (36),
    .p_num_be_lanes         (2),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (1),
    .p_mem_recv_intv_delay  (1)
  ) suite_2();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (3),
    .p_opaq_bits            (4),
    .p_seq_num_bits         (3),
    .p_num_phys_regs        (34),
    .p_num_be_lanes         (2),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (1),
    .p_mem_recv_intv_delay  (1)
  ) suite_3();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (4),
    .p_opaq_bits            (32),
    .p_seq_num_bits         (4),
    .p_num_phys_regs        (50),
    .p_num_be_lanes         (2),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (1),
    .p_mem_recv_intv_delay  (1)
  ) suite_4();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (5),
    .p_opaq_bits            (2),
    .p_seq_num_bits         (2),
    .p_num_phys_regs        (48),
    .p_num_be_lanes         (2),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (1),
    .p_mem_recv_intv_delay  (3)
  ) suite_5();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (6),
    .p_opaq_bits            (4),
    .p_seq_num_bits         (6),
    .p_num_phys_regs        (42),
    .p_num_be_lanes         (2),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (3),
    .p_mem_recv_intv_delay  (3)
  ) suite_6();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (7),
    .p_opaq_bits            (8),
    .p_seq_num_bits         (5),
    .p_num_phys_regs        (36),
    .p_num_be_lanes         (2),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (1),
    .p_mem_recv_intv_delay  (1),
    .p_num_fe_lanes         (4)
  ) suite_7();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (8),
    .p_opaq_bits            (8),
    .p_seq_num_bits         (5),
    .p_num_phys_regs        (36),
    .p_num_be_lanes         (4),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (1),
    .p_mem_recv_intv_delay  (1),
    .p_num_fe_lanes         (4)
  ) suite_8();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (9),
    .p_opaq_bits            (8),
    .p_seq_num_bits         (5),
    .p_num_phys_regs        (36),
    .p_num_be_lanes         (4),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (1),
    .p_mem_recv_intv_delay  (1),
    .p_num_fe_lanes         (2)
  ) suite_9();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (10),
    .p_opaq_bits            (8),
    .p_seq_num_bits         (5),
    .p_num_phys_regs        (36),
    .p_num_be_lanes         (4),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (1),
    .p_mem_recv_intv_delay  (1),
    .p_num_fe_lanes         (3)
  ) suite_10();
  BlimpV11TestSuite_sh #(
    .p_suite_num            (11),
    .p_opaq_bits            (8),
    .p_seq_num_bits         (2),
    .p_num_phys_regs        (35),
    .p_num_be_lanes         (4),
    .p_iq_depth             (4),
    .p_mem_send_intv_delay  (1),
    .p_mem_recv_intv_delay  (1),
    .p_num_fe_lanes         (4)
  ) suite_11();
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

    test_bench_end();
  end
endmodule
