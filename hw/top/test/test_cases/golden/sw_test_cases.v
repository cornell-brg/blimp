//========================================================================
// sw_test_cases.v
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_golden_sw_1_regs
//------------------------------------------------------------------------

task test_case_golden_sw_1_regs();
  h.t.test_case_begin( "test_case_golden_sw_1_regs" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x100" );
  h.asm( 'h004, "addi x2,  x0, 0x104" );
  h.asm( 'h008, "addi x3,  x0, 0x108" );
  h.asm( 'h00c, "addi x4,  x0, 0x10c" );

  h.asm( 'h010, "addi x5,  x0, 10" );
  h.asm( 'h014, "addi x6,  x0, 11" );
  h.asm( 'h018, "addi x7,  x0, 12" );
  h.asm( 'h01c, "addi x8,  x0, 13" );

  h.asm( 'h020, "sw   x5, 0(x1)"     );
  h.asm( 'h024, "sw   x6, 0(x2)"     );
  h.asm( 'h028, "sw   x7, 0(x3)"     );
  h.asm( 'h02c, "sw   x8, 0(x4)"     );

  h.asm( 'h030, "lw   x5, 0(x1)"     );
  h.asm( 'h034, "lw   x6, 0(x2)"     );
  h.asm( 'h038, "lw   x7, 0(x3)"     );
  h.asm( 'h03c, "lw   x8, 0(x4)"     );

  h.asm( 'h040, "addi x28, x0, 0x110" );
  h.asm( 'h044, "addi x29, x0, 0x114" );
  h.asm( 'h048, "addi x30, x0, 0x118" );
  h.asm( 'h04c, "addi x31, x0, 0x11c" );

  h.asm( 'h050, "addi x5,  x0, 14" );
  h.asm( 'h054, "addi x6,  x0, 15" );
  h.asm( 'h058, "addi x7,  x0, 16" );
  h.asm( 'h05c, "addi x8,  x0, 17" );

  h.asm( 'h060, "sw   x5, 0(x28)"    );
  h.asm( 'h064, "sw   x6, 0(x29)"    );
  h.asm( 'h068, "sw   x7, 0(x30)"    );
  h.asm( 'h06c, "sw   x8, 0(x31)"    );

  h.asm( 'h070, "lw   x5, 0(x28)"    );
  h.asm( 'h074, "lw   x6, 0(x29)"    );
  h.asm( 'h078, "lw   x7, 0(x30)"    );
  h.asm( 'h07c, "lw   x8, 0(x31)"    );

  // Write h.data into memory

  h.data( 'h100, 'h0101_0101 );
  h.data( 'h104, 'h0202_0002 );
  h.data( 'h108, 'h0303_0303 );
  h.data( 'h10c, 'h0404_0404 );

  h.data( 'h110, 'h0505_0505 );
  h.data( 'h114, 'h0606_0606 );
  h.data( 'h118, 'h0707_0707 );
  h.data( 'h11c, 'h0808_0808 );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_sw_2_mix
//------------------------------------------------------------------------

task test_case_golden_sw_2_mix();
  h.t.test_case_begin( "test_case_golden_sw_2_mix" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x100" );
  h.asm( 'h004, "addi x2,  x0, 0x110" );
  h.asm( 'h008, "addi x3,  x0, 0x120" );
  h.asm( 'h00c, "addi x4,  x0, 0"     );

  h.asm( 'h010, "lw   x5,  0(x1)"     );
  h.asm( 'h014, "lw   x6,  0(x2)"     );
  h.asm( 'h018, "mul  x7,  x5, x6"    );
  h.asm( 'h01c, "add  x4,  x4, x7"    );
  h.asm( 'h020, "sw   x4,  0(x3)"     );
  h.asm( 'h024, "addi x1,  x1, 4"     );
  h.asm( 'h028, "addi x2,  x2, 4"     );
  h.asm( 'h02c, "addi x3,  x3, 4"     );

  h.asm( 'h030, "lw   x5,  0(x1)"     );
  h.asm( 'h034, "lw   x6,  0(x2)"     );
  h.asm( 'h038, "mul  x7,  x5, x6"    );
  h.asm( 'h03c, "add  x4,  x4, x7"    );
  h.asm( 'h040, "sw   x4,  0(x3)"     );
  h.asm( 'h044, "addi x1,  x1, 4"     );
  h.asm( 'h048, "addi x2,  x2, 4"     );
  h.asm( 'h04c, "addi x3,  x3, 4"     );

  h.asm( 'h050, "lw   x5,  0(x1)"     );
  h.asm( 'h054, "lw   x6,  0(x2)"     );
  h.asm( 'h058, "mul  x7,  x5, x6"    );
  h.asm( 'h05c, "add  x4,  x4, x7"    );
  h.asm( 'h060, "sw   x4,  0(x3)"     );
  h.asm( 'h064, "addi x1,  x1, 4"     );
  h.asm( 'h068, "addi x2,  x2, 4"     );
  h.asm( 'h06c, "addi x3,  x3, 4"     );

  h.asm( 'h070, "addi x1,  x0, 0x120" );
  h.asm( 'h074, "lw   x2,  0(x1)"     );
  h.asm( 'h078, "lw   x3,  4(x1)"     );
  h.asm( 'h07c, "lw   x4,  8(x1)"     );

  // Write h.data into memory

  h.data( 'h100, 1 );
  h.data( 'h104, 2 );
  h.data( 'h108, 3 );

  h.data( 'h110, 5 );
  h.data( 'h114, 6 );
  h.data( 'h118, 7 );

  h.data( 'h120, 0 );
  h.data( 'h124, 0 );
  h.data( 'h128, 0 );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_golden_sw_tests
//------------------------------------------------------------------------

task run_golden_sw_tests();
  test_case_golden_sw_1_regs();
  test_case_golden_sw_2_mix();
endtask
