//========================================================================
// BlimpV8_sp26_lw_test.v
//========================================================================
// Test cases are inlined here (rather than included from
// hw/top/test/test_cases/.../lw_test_cases.v) so that all data writes
// can be moved out of the [0x000, 0x200) range without affecting the
// other test suites that share those files. Instructions still start
// at PC 0x000 to match FetchUnitL3's reset address.

`include "hw/top/test/BlimpV8_sp26TestHarness.v"

module BlimpV8_sp26TestSuite_lw #(
  parameter p_suite_num     = 0,
  parameter p_opaq_bits     = 8,
  parameter p_seq_num_bits  = 5,
  parameter p_num_phys_regs = 36,

  parameter p_mem_send_intv_delay = 1,
  parameter p_mem_recv_intv_delay = 1
);
  string suite_name = $sformatf("%0d: BlimpV8_sp26TestSuite_%0d_%0d_%0d_%0d",
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

  integer seed = 32'hDEADBEEF;

  //----------------------------------------------------------------------
  // Directed tests
  //----------------------------------------------------------------------

  task test_case_directed_lw_1_basic();
    h.t.test_case_begin( "test_case_directed_lw_1_basic" );
    if( !h.t.run_test ) return;
    fl_reset();

    h.asm( 'h000, "addi x1, x0, 0x300" );
    h.asm( 'h004, "lw   x2, 0(x1)"     );

    h.data( 'h300, 'hdead_beef );

    h.check_trace( 'h000, 1, 'h0000_0300, 1 );
    h.check_trace( 'h004, 2, 'hdead_beef, 1 );

    h.t.test_case_end();
  endtask

  task test_case_directed_lw_2_x0();
    h.t.test_case_begin( "test_case_directed_lw_2_x0" );
    if( !h.t.run_test ) return;
    fl_reset();

    h.asm( 'h000, "addi x1, x0, 0x300" );
    h.asm( 'h004, "lw   x0, 0(x1)"     );
    h.asm( 'h008, "lw   x0, 0(x0)"     );

    h.data( 'h300, 'hdead_beef );

    h.check_trace( 'h000, 1,  'h0000_0300, 1 );
    h.check_trace( 'h004, 'x, 'x,          0 );
    h.check_trace( 'h008, 'x, 'x,          0 );

    h.t.test_case_end();
  endtask

  task test_case_directed_lw_3_offset_pos();
    h.t.test_case_begin( "test_case_directed_lw_3_offset_pos" );
    if( !h.t.run_test ) return;
    fl_reset();

    h.asm( 'h000, "addi x1,  x0, 0x300" );
    h.asm( 'h004, "lw   x2,  0(x1)"     );
    h.asm( 'h008, "lw   x3,  4(x1)"     );
    h.asm( 'h00c, "lw   x4,  8(x1)"     );
    h.asm( 'h010, "lw   x5,  12(x1)"    );

    h.data( 'h300, 'h0000_2000 );
    h.data( 'h304, 'h0000_2004 );
    h.data( 'h308, 'h0000_2008 );
    h.data( 'h30c, 'h0000_200c );

    h.check_trace( 'h000, 1, 'h0000_0300, 1 );
    h.check_trace( 'h004, 2, 'h0000_2000, 1 );
    h.check_trace( 'h008, 3, 'h0000_2004, 1 );
    h.check_trace( 'h00c, 4, 'h0000_2008, 1 );
    h.check_trace( 'h010, 5, 'h0000_200c, 1 );

    h.t.test_case_end();
  endtask

  task test_case_directed_lw_4_offset_neg();
    h.t.test_case_begin( "test_case_directed_lw_4_offset_neg" );
    if( !h.t.run_test ) return;
    fl_reset();

    h.asm( 'h000, "addi x1,  x0, 0x30c" );
    h.asm( 'h004, "lw   x2,  0(x1)"     );
    h.asm( 'h008, "lw   x3,  -4(x1)"    );
    h.asm( 'h00c, "lw   x4,  -8(x1)"    );
    h.asm( 'h010, "lw   x5,  -12(x1)"   );

    h.data( 'h300, 'h0000_2000 );
    h.data( 'h304, 'h0000_2004 );
    h.data( 'h308, 'h0000_2008 );
    h.data( 'h30c, 'h0000_200c );

    h.check_trace( 'h000, 1, 'h0000_030c, 1 );
    h.check_trace( 'h004, 2, 'h0000_200c, 1 );
    h.check_trace( 'h008, 3, 'h0000_2008, 1 );
    h.check_trace( 'h00c, 4, 'h0000_2004, 1 );
    h.check_trace( 'h010, 5, 'h0000_2000, 1 );

    h.t.test_case_end();
  endtask

  task test_case_directed_lw_5_chain();
    h.t.test_case_begin( "test_case_directed_lw_5_chain" );
    if( !h.t.run_test ) return;
    fl_reset();

    h.asm( 'h000, "addi x1, x0, 0x300" );
    h.asm( 'h004, "lw   x2, 0(x1)"     );
    h.asm( 'h008, "lw   x3, 0(x2)"     );
    h.asm( 'h00c, "lw   x4, 0(x3)"     );
    h.asm( 'h010, "lw   x5, 0(x4)"     );
    h.asm( 'h014, "lw   x6, 0(x5)"     );
    h.asm( 'h018, "lw   x7, 0(x6)"     );
    h.asm( 'h01c, "lw   x8, 0(x7)"     );
    h.asm( 'h020, "lw   x9, 0(x8)"     );

    h.data( 'h300, 'h310 );
    h.data( 'h310, 'h320 );
    h.data( 'h320, 'h330 );
    h.data( 'h330, 'h340 );
    h.data( 'h340, 'h350 );
    h.data( 'h350, 'h360 );
    h.data( 'h360, 'h370 );
    h.data( 'h370, 'h380 );

    h.check_trace( 'h000, 1, 'h0000_0300, 1 );
    h.check_trace( 'h004, 2, 'h0000_0310, 1 );
    h.check_trace( 'h008, 3, 'h0000_0320, 1 );
    h.check_trace( 'h00c, 4, 'h0000_0330, 1 );
    h.check_trace( 'h010, 5, 'h0000_0340, 1 );
    h.check_trace( 'h014, 6, 'h0000_0350, 1 );
    h.check_trace( 'h018, 7, 'h0000_0360, 1 );
    h.check_trace( 'h01c, 8, 'h0000_0370, 1 );
    h.check_trace( 'h020, 9, 'h0000_0380, 1 );

    h.t.test_case_end();
  endtask

  task test_case_directed_lw_6_two_chain();
    h.t.test_case_begin( "test_case_directed_lw_6_two_chain" );
    if( !h.t.run_test ) return;
    fl_reset();

    h.asm( 'h000, "addi x1, x0, 0x280" );
    h.asm( 'h004, "addi x9, x0, 0x300" );
    h.asm( 'h008, "lw   x2,  0(x1)"    );
    h.asm( 'h00c, "lw   x10, 0(x9)"    );
    h.asm( 'h010, "lw   x3,  0(x2)"    );
    h.asm( 'h014, "lw   x11, 0(x10)"   );
    h.asm( 'h018, "lw   x4,  0(x3)"    );
    h.asm( 'h01c, "lw   x12, 0(x11)"   );
    h.asm( 'h020, "lw   x5,  0(x4)"    );
    h.asm( 'h024, "lw   x13, 0(x12)"   );
    h.asm( 'h028, "lw   x6,  0(x5)"    );
    h.asm( 'h02c, "lw   x14, 0(x13)"   );
    h.asm( 'h030, "lw   x7,  0(x6)"    );
    h.asm( 'h034, "lw   x15, 0(x14)"   );
    h.asm( 'h038, "lw   x8,  0(x7)"    );
    h.asm( 'h03c, "lw   x16, 0(x15)"   );
    h.asm( 'h040, "lw   x9,  0(x8)"    );
    h.asm( 'h044, "lw   x17, 0(x16)"   );

    h.data( 'h280, 'h290 );
    h.data( 'h290, 'h2a0 );
    h.data( 'h2a0, 'h2b0 );
    h.data( 'h2b0, 'h2c0 );
    h.data( 'h2c0, 'h2d0 );
    h.data( 'h2d0, 'h2e0 );
    h.data( 'h2e0, 'h2f0 );
    h.data( 'h2f0, 'h300 );

    h.data( 'h300, 'h310 );
    h.data( 'h310, 'h320 );
    h.data( 'h320, 'h330 );
    h.data( 'h330, 'h340 );
    h.data( 'h340, 'h350 );
    h.data( 'h350, 'h360 );
    h.data( 'h360, 'h370 );
    h.data( 'h370, 'h380 );

    h.check_trace( 'h000, 1,  'h0000_0280, 1 );
    h.check_trace( 'h004, 9,  'h0000_0300, 1 );
    h.check_trace( 'h008, 2,  'h0000_0290, 1 );
    h.check_trace( 'h00c, 10, 'h0000_0310, 1 );
    h.check_trace( 'h010, 3,  'h0000_02a0, 1 );
    h.check_trace( 'h014, 11, 'h0000_0320, 1 );
    h.check_trace( 'h018, 4,  'h0000_02b0, 1 );
    h.check_trace( 'h01c, 12, 'h0000_0330, 1 );
    h.check_trace( 'h020, 5,  'h0000_02c0, 1 );
    h.check_trace( 'h024, 13, 'h0000_0340, 1 );
    h.check_trace( 'h028, 6,  'h0000_02d0, 1 );
    h.check_trace( 'h02c, 14, 'h0000_0350, 1 );
    h.check_trace( 'h030, 7,  'h0000_02e0, 1 );
    h.check_trace( 'h034, 15, 'h0000_0360, 1 );
    h.check_trace( 'h038, 8,  'h0000_02f0, 1 );
    h.check_trace( 'h03c, 16, 'h0000_0370, 1 );
    h.check_trace( 'h040, 9,  'h0000_0300, 1 );
    h.check_trace( 'h044, 17, 'h0000_0380, 1 );

    h.t.test_case_end();
  endtask

  task run_directed_lw_tests();
    test_case_directed_lw_1_basic();
    test_case_directed_lw_2_x0();
    test_case_directed_lw_3_offset_pos();
    test_case_directed_lw_4_offset_neg();
    test_case_directed_lw_5_chain();
    test_case_directed_lw_6_two_chain();
  endtask

  //----------------------------------------------------------------------
  // Golden tests
  //----------------------------------------------------------------------

  task test_case_golden_lw_1_regs();
    h.t.test_case_begin( "test_case_golden_lw_1_regs" );
    if( !h.t.run_test ) return;
    fl_reset();

    h.asm( 'h000, "addi x1,  x0, 0x300" );
    h.asm( 'h004, "addi x2,  x0, 0x304" );
    h.asm( 'h008, "addi x3,  x0, 0x308" );
    h.asm( 'h00c, "addi x4,  x0, 0x30c" );

    h.asm( 'h010, "addi x28, x0, 0x310" );
    h.asm( 'h014, "addi x29, x0, 0x314" );
    h.asm( 'h018, "addi x30, x0, 0x318" );
    h.asm( 'h01c, "addi x31, x0, 0x31c" );

    h.asm( 'h020, "lw   x5, 0(x1)"     );
    h.asm( 'h024, "lw   x6, 0(x2)"     );
    h.asm( 'h028, "lw   x7, 0(x3)"     );
    h.asm( 'h02c, "lw   x8, 0(x4)"     );

    h.asm( 'h030, "lw   x5, 0(x28)"    );
    h.asm( 'h034, "lw   x6, 0(x29)"    );
    h.asm( 'h038, "lw   x7, 0(x30)"    );
    h.asm( 'h03c, "lw   x8, 0(x31)"    );

    h.data( 'h300, 'h0101_0101 );
    h.data( 'h304, 'h0202_0202 );
    h.data( 'h308, 'h0303_0303 );
    h.data( 'h30c, 'h0404_0404 );

    h.data( 'h310, 'h0505_0505 );
    h.data( 'h314, 'h0606_0606 );
    h.data( 'h318, 'h0707_0707 );
    h.data( 'h31c, 'h0808_0808 );

    h.check_traces();

    h.t.test_case_end();
  endtask

  task test_case_golden_lw_2_deps();
    h.t.test_case_begin( "test_case_golden_lw_2_deps" );
    if( !h.t.run_test ) return;
    fl_reset();

    h.asm( 'h000, "addi x1,  x0, 0x300" );
    h.asm( 'h004, "lw   x2,  0(x1)"     );
    h.asm( 'h008, "addi x3,  x2, 1"     );

    h.asm( 'h00c, "addi x1,  x0, 0x304" );
    h.asm( 'h010, "lw   x2,  0(x1)"     );
    h.asm( 'h014, "lw   x3,  0(x2)"     );
    h.asm( 'h018, "lw   x4,  0(x3)"     );
    h.asm( 'h01c, "addi x5,  x4, 1"     );

    h.data( 'h300, 'h0000_2000 );
    h.data( 'h304, 'h0000_0308 );
    h.data( 'h308, 'h0000_030c );
    h.data( 'h30c, 'h0000_3000 );

    h.check_traces();

    h.t.test_case_end();
  endtask

  task test_case_golden_lw_3_mix();
    h.t.test_case_begin( "test_case_golden_lw_3_mix" );
    if( !h.t.run_test ) return;
    fl_reset();

    h.asm( 'h000, "addi x1,  x0, 0x300" );
    h.asm( 'h004, "addi x2,  x0, 0x310" );
    h.asm( 'h008, "addi x3,  x0, 0"     );

    h.asm( 'h00c, "lw   x4,  0(x1)"     );
    h.asm( 'h010, "lw   x5,  0(x2)"     );
    h.asm( 'h014, "mul  x6,  x4, x5"    );
    h.asm( 'h018, "add  x3,  x3, x6"    );
    h.asm( 'h01c, "addi x1,  x1, 4"     );
    h.asm( 'h020, "addi x2,  x2, 4"     );

    h.asm( 'h024, "lw   x4,  0(x1)"     );
    h.asm( 'h028, "lw   x5,  0(x2)"     );
    h.asm( 'h02c, "mul  x6,  x4, x5"    );
    h.asm( 'h030, "add  x3,  x3, x6"    );
    h.asm( 'h034, "addi x1,  x1, 4"     );
    h.asm( 'h038, "addi x2,  x2, 4"     );

    h.asm( 'h03c, "lw   x4,  0(x1)"     );
    h.asm( 'h040, "lw   x5,  0(x2)"     );
    h.asm( 'h044, "mul  x6,  x4, x5"    );
    h.asm( 'h048, "add  x3,  x3, x6"    );
    h.asm( 'h04c, "addi x1,  x1, 4"     );
    h.asm( 'h050, "addi x2,  x2, 4"     );

    h.data( 'h300, 1 );
    h.data( 'h304, 2 );
    h.data( 'h308, 3 );

    h.data( 'h310, 5 );
    h.data( 'h314, 6 );
    h.data( 'h318, 7 );

    h.check_traces();

    h.t.test_case_end();
  endtask

  task run_golden_lw_tests();
    test_case_golden_lw_1_regs();
    test_case_golden_lw_2_deps();
    test_case_golden_lw_3_mix();
  endtask

  //----------------------------------------------------------------------
  // Randomized tests
  //----------------------------------------------------------------------

  task test_case_randomized_lw_1_offset();
    integer offset;
    integer addr;
    integer data;
    integer base_addr;
    integer pc;
    string  inst;
    integer unused;

    h.t.test_case_begin( "test_case_randomized_lw_1_offset" );
    if( !h.t.run_test ) return;
    fl_reset();

    unused = $urandom(seed);

    base_addr = 'h2000;

    h.asm( 'h000, "addi x1, x0, 0x200" );
    h.asm( 'h004, "slli x1, x1, 4"     );

    pc = 'h008;

    for (int i = 0; i < 200; i++) begin

      offset = {{ 21{1'($urandom)}}, 9'($urandom), 2'b0};

      addr = base_addr + offset;

      data = 32'($urandom);

      h.data( addr, data );

      inst = $sformatf("lw x2, %d(x1)", offset);
      h.asm( pc, inst );

      pc = pc + 4;
    end

    h.check_traces();

    h.t.test_case_end();
  endtask

  task test_case_randomized_lw_2_chains();
    integer unused;
    integer pc;
    string  inst;
    integer addr;
    integer data;

    bit select_chain;
    bit select_inst;
    integer reg_fl [9];
    integer rd_idx;
    integer rs1_idx;
    integer rs2_idx;

    integer mem [128];

    integer reg_tr [500];
    integer wdata_tr [500];

    h.t.test_case_begin( "test_case_randomized_lw_2_chains" );
    if( !h.t.run_test ) return;
    fl_reset();

    seed = 32'hC252C252;

    unused = $urandom(seed + 1);

    // Chain bases live at 0x1100..0x1170 (well above the 510-instruction
    // program at 0x000-0x7F4, and outside [0x000, 0x200)). Every initial
    // value (and every mem entry) has bit 12 set, so any AND or LW result
    // also has bit 12 set and the chain stays inside [0x1000, 0x11FC] —
    // i.e., always lands on an address h.data initialized below.
    for (int i = 0; i < 8; i++) begin
      reg_fl[i+1] = 32'h1100 + (i << 4);
    end

    // Initialize memory randomly. mem[i] is stored at (i << 2) + 0x1000,
    // and each entry is masked into [0x1000, 0x11FC] so that following
    // a chain pointer always lands inside the data window.
    for (int i = 0; i < 128; i++) begin
      mem[i] = ($urandom() & 32'h1fc) + 32'h1000;
      h.data( (i << 2) + 32'h1000, mem[i] );
    end

    // Build base = 0x1000 in x9, then derive x1..x8 = 0x1100..0x1170.
    h.asm( 'h000, "addi x9, x0, 0x100" );
    h.asm( 'h004, "slli x9, x9, 4"     );

    h.asm( 'h008, "addi x1, x9, 0x100" );
    h.asm( 'h00c, "addi x2, x9, 0x110" );
    h.asm( 'h010, "addi x3, x9, 0x120" );
    h.asm( 'h014, "addi x4, x9, 0x130" );
    h.asm( 'h018, "addi x5, x9, 0x140" );
    h.asm( 'h01c, "addi x6, x9, 0x150" );
    h.asm( 'h020, "addi x7, x9, 0x160" );
    h.asm( 'h024, "addi x8, x9, 0x170" );

    pc = 'h028;

    for (int i = 0; i < 500; i++) begin
      select_chain = 1'($urandom());
      select_inst  = 1'($urandom());

      if (select_chain == 0) begin
        rd_idx  = {30'b0, 2'($urandom())} + 1;
        rs1_idx = {30'b0, 2'($urandom())} + 1;
        rs2_idx = {30'b0, 2'($urandom())} + 1;
      end
      else begin
        rd_idx  = {30'b01, 2'($urandom())} + 1;
        rs1_idx = {30'b01, 2'($urandom())} + 1;
        rs2_idx = {30'b01, 2'($urandom())} + 1;
      end

      if (select_inst == 0) begin
        // AND (not XOR) so chain values keep bit 12 set and stay in
        // [0x1000, 0x11FC] — XOR cancels bit 12 and bounces the chain
        // outside the data window.
        inst = $sformatf("and x%0d, x%0d, x%0d", rd_idx, rs1_idx, rs2_idx);

        reg_fl[rd_idx] = reg_fl[rs1_idx] & reg_fl[rs2_idx];
      end
      else begin
        addr = reg_fl[rs1_idx];
        data = mem[((addr - 32'h1000) >> 2)];

        inst = $sformatf("lw x%0d, 0(x%0d)", rd_idx, rs1_idx);

        reg_fl[rd_idx] = data;
      end

      reg_tr[i] = rd_idx;
      wdata_tr[i] = reg_fl[rd_idx];

      h.asm(pc, inst);
      pc = pc + 4;
    end

    h.check_traces();

    h.t.test_case_end();
  endtask

  task run_randomized_lw_tests();
    test_case_randomized_lw_1_offset();
    test_case_randomized_lw_2_chains();
  endtask

  task run_test_suite();
    h.t.test_suite_begin( suite_name );
    run_directed_lw_tests();
    run_golden_lw_tests();
    run_randomized_lw_tests();
  endtask
endmodule

module BlimpV8_sp26_lw_test;
  BlimpV8_sp26TestSuite_lw #(1)                 suite_1();
  BlimpV8_sp26TestSuite_lw #(2, 8, 5, 36, 1, 1) suite_2();
  BlimpV8_sp26TestSuite_lw #(3, 4, 3, 33, 1, 1) suite_3();
  BlimpV8_sp26TestSuite_lw #(4,32, 4, 50, 3, 1) suite_4();
  BlimpV8_sp26TestSuite_lw #(5, 2, 2, 48, 1, 3) suite_5();
  BlimpV8_sp26TestSuite_lw #(6, 4, 6, 42, 3, 3) suite_6();
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
