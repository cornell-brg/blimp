//========================================================================
// BlimpV8_sp26_debug_test.v
//========================================================================

`include "hw/top/test/BlimpV8_sp26TestHarness.v"

module BlimpV8_sp26TestSuite_debug #(
  parameter p_suite_num           = 0,
  parameter p_opaq_bits           = 8,
  parameter p_seq_num_bits        = 5,
  parameter p_num_phys_regs       = 36,

  parameter p_mem_send_intv_delay = 1,
  parameter p_mem_recv_intv_delay = 1
);
  string suite_name = $sformatf("%0d: BlimpV8_sp26TestSuite_debug_%0d_%0d_%0d_%0d",
                                p_suite_num,
                                p_opaq_bits, p_seq_num_bits,
                                p_mem_send_intv_delay, p_mem_recv_intv_delay);
  BlimpV8_sp26TestHarness #(
    .p_opaq_bits           (p_opaq_bits),
    .p_seq_num_bits        (p_seq_num_bits),
    .p_num_phys_regs       (p_num_phys_regs),
    .p_mem_send_intv_delay (p_mem_send_intv_delay),
    .p_mem_recv_intv_delay (p_mem_recv_intv_delay)
  ) h();

  `include "hw/top/test/test_cases/directed/debug_test_cases.v"

  task automatic run_test_suite();
    h.t.test_suite_begin( suite_name );
    run_directed_debug_tests();
  endtask
endmodule

module BlimpV8_sp26_debug_test;
  BlimpV8_sp26TestSuite_debug #(1)                 suite_1();
  // verilog_lint: waive module-parameter -- project prefers positional params here
  BlimpV8_sp26TestSuite_debug #(2, 8, 4, 33, 1, 1) suite_2();
  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();
    if ((s <= 0) || (s == 2)) suite_2.run_test_suite();

    test_bench_end();
  end
endmodule
