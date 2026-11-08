//========================================================================
// lw_test_cases.v
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_golden_lw_1_regs
//------------------------------------------------------------------------

task test_case_golden_lw_1_regs();
  h.t.test_case_begin( "test_case_golden_lw_1_regs" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x100" );
  h.asm( 'h004, "addi x2,  x0, 0x104" );
  h.asm( 'h008, "addi x3,  x0, 0x108" );
  h.asm( 'h00c, "addi x4,  x0, 0x10c" );

  h.asm( 'h010, "addi x28, x0, 0x110" );
  h.asm( 'h014, "addi x29, x0, 0x114" );
  h.asm( 'h018, "addi x30, x0, 0x118" );
  h.asm( 'h01c, "addi x31, x0, 0x11c" );

  h.asm( 'h020, "lw   x5, 0(x1)"     );
  h.asm( 'h024, "lw   x6, 0(x2)"     );
  h.asm( 'h028, "lw   x7, 0(x3)"     );
  h.asm( 'h02c, "lw   x8, 0(x4)"     );

  h.asm( 'h030, "lw   x5, 0(x28)"    );
  h.asm( 'h034, "lw   x6, 0(x29)"    );
  h.asm( 'h038, "lw   x7, 0(x30)"    );
  h.asm( 'h03c, "lw   x8, 0(x31)"    );

  // Write h.data into memory

  h.data( 'h100, 'h0101_0101 );
  h.data( 'h104, 'h0202_0202 );
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
// test_case_golden_lw_2_deps
//------------------------------------------------------------------------

task test_case_golden_lw_2_deps();
  h.t.test_case_begin( "test_case_golden_lw_2_deps" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x100" );
  h.asm( 'h004, "lw   x2,  0(x1)"     );
  h.asm( 'h008, "addi x3,  x2, 1"     );

  h.asm( 'h00c, "addi x1,  x0, 0x104" );
  h.asm( 'h010, "lw   x2,  0(x1)"     );
  h.asm( 'h014, "lw   x3,  0(x2)"     );
  h.asm( 'h018, "lw   x4,  0(x3)"     );
  h.asm( 'h01c, "addi x5,  x4, 1"     );

  // Write h.data into memory

  h.data( 'h100, 'h0000_2000 );
  h.data( 'h104, 'h0000_0108 );
  h.data( 'h108, 'h0000_010c );
  h.data( 'h10c, 'h0000_3000 );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_lw_3_mix
//------------------------------------------------------------------------

task test_case_golden_lw_3_mix();
  h.t.test_case_begin( "test_case_golden_lw_3_mix" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x100" );
  h.asm( 'h004, "addi x2,  x0, 0x110" );
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

  // Write h.data into memory

  h.data( 'h100, 1 );
  h.data( 'h104, 2 );
  h.data( 'h108, 3 );

  h.data( 'h110, 5 );
  h.data( 'h114, 6 );
  h.data( 'h118, 7 );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_golden_lw_tests
//------------------------------------------------------------------------

task run_golden_lw_tests();
  test_case_golden_lw_1_regs();
  test_case_golden_lw_2_deps();
  test_case_golden_lw_3_mix();
endtask
