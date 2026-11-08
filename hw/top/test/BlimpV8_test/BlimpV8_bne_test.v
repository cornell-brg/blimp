//========================================================================
// BlimpV8_bne_test.v
//========================================================================

`include "hw/top/test/BlimpV8TestHarness.v"

module BlimpV8TestSuite_bne #(
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

  integer seed = 32'hDEADBEEF;

  `include "hw/top/test/test_cases/directed/bne_test_cases.v"
  `include "hw/top/test/test_cases/randomized/bne_test_cases.v"
  `include "hw/top/test/test_cases/golden/bne_test_cases.v"
  task automatic run_test_suite();
    // declare locals before any statements (required by many SV tools)
    int _run_rand;

    h.t.test_suite_begin( suite_name );
    run_directed_bne_tests();
    run_golden_bne_tests();

    // Control randomized tests via plusarg: +run_randomized=0 or +run_randomized=1
    _run_rand = 1; // default: run randomized
    if ($value$plusargs("run_randomized=%d", _run_rand)) begin
      // plusarg provided; _run_rand now holds it
    end
    if (_run_rand != 0) begin
      run_randomized_bne_tests();
    end
  endtask
endmodule

module BlimpV8_bne_test;
  BlimpV8TestSuite_bne #(1)                 suite_1();
  BlimpV8TestSuite_bne #(2, 8, 5, 36, 1, 1) suite_2();
  BlimpV8TestSuite_bne #(3, 4, 3, 33, 1, 1) suite_3();
  BlimpV8TestSuite_bne #(4,32, 4, 50, 3, 1) suite_4();
  BlimpV8TestSuite_bne #(5, 2, 2, 48, 1, 3) suite_5();
  BlimpV8TestSuite_bne #(6, 4, 6, 42, 3, 3) suite_6();
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
