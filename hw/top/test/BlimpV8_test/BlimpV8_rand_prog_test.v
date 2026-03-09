//========================================================================
// BlimpV8_rand_prog_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"

module BlimpV8TestSuite_rand_prog #(
  parameter p_suite_num     = 0,
  parameter p_opaq_bits     = 8,
  parameter p_seq_num_bits  = 5,
  parameter p_num_phys_regs = 36,

  parameter p_mem_send_intv_delay = 1,
  parameter p_mem_recv_intv_delay = 1
);
  string suite_name = $sformatf("%0d: BlimpV8TestSuite_%0d_%0d_%0d_%0d", 
                                p_suite_num,
                                p_opaq_bits, p_seq_num_bits,
                                p_mem_send_intv_delay, p_mem_recv_intv_delay);
  BlimpV8TestHarness #(
    .p_opaq_bits           (p_opaq_bits),
    .p_seq_num_bits        (p_seq_num_bits),
    .p_num_phys_regs       (p_num_phys_regs),
    .p_mem_send_intv_delay (p_mem_send_intv_delay),
    .p_mem_recv_intv_delay (p_mem_recv_intv_delay)
  ) h();

  `include "hw/top/test/test_cases/rand_prog/basic_test_case.v"
  `include "hw/top/test/test_cases/rand_prog/memory_test_case.v"
  `include "hw/top/test/test_cases/rand_prog/m_ext_test_case.v"
  // `include "hw/top/test/test_cases/rand_prog/control_test_case.v"
  // `include "hw/top/test/test_cases/rand_prog/mixed_test_case.v"
  task run_test_suite();
    h.t.test_suite_begin( suite_name );
    run_rand_prog_basic_test();
    run_rand_prog_memory_test();
    run_rand_prog_m_ext_test();
    // run_rand_prog_control_test();
    // run_rand_prog_mixed_test();
  endtask
endmodule

module BlimpV8_rand_prog_test;
  BlimpV8TestSuite_rand_prog #(1)                 suite_1();
  BlimpV8TestSuite_rand_prog #(2, 8, 5, 36, 1, 1) suite_2();
  BlimpV8TestSuite_rand_prog #(3, 4, 3, 33, 1, 1) suite_3();
  BlimpV8TestSuite_rand_prog #(4,32, 4, 50, 3, 1) suite_4();
  BlimpV8TestSuite_rand_prog #(5, 2, 2, 48, 1, 3) suite_5();
  BlimpV8TestSuite_rand_prog #(6, 4, 6, 42, 3, 3) suite_6();
  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();
    if ((s <= 0) || (s == 2)) suite_2.run_test_suite();
    if ((s <= 0) || (s == 3)) suite_3.run_test_suite();
    if ((s <= 0) || (s == 4)) suite_4.run_test_suite();
    if ((s <= 0) || (s == 5)) suite_5.run_test_suite();
    if ((s <= 0) || (s == 6)) suite_6.run_test_suite();

    test_bench_end();
  end
endmodule
