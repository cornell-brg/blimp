//========================================================================
// jal_test_cases.v
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_golden_jal_1_regs
//------------------------------------------------------------------------

task test_case_golden_jal_1_regs();
  h.t.test_case_begin( "test_case_golden_jal_1_regs" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "jal  x1, 0x208"   ); //
  h.asm( 'h204, "addi x2, x0, 1"   );
  h.asm( 'h208, "addi x3, x0, 2"   ); //

  h.asm( 'h20c, "jal  x2, 0x214"   ); //
  h.asm( 'h210, "addi x3, x0, 3"   );
  h.asm( 'h214, "addi x4, x0, 4"   ); //

  h.asm( 'h218, "jal  x3, 0x220"   ); //
  h.asm( 'h21c, "addi x4, x0, 5"   );
  h.asm( 'h220, "addi x5, x0, 6"   ); //

  h.asm( 'h224, "jal  x4, 0x22c"   );
  h.asm( 'h228, "addi x5, x0, 7"   );
  h.asm( 'h22c, "addi x6, x0, 8"   );

  h.asm( 'h230, "jal  x31, 0x238"   );
  h.asm( 'h234, "addi x30, x0, 9"   );
  h.asm( 'h238, "addi x29, x0, 10"  );

  h.asm( 'h23c, "jal  x30, 0x244"   );
  h.asm( 'h240, "addi x29, x0, 11"  );
  h.asm( 'h244, "addi x28, x0, 12"  );

  h.asm( 'h248, "jal  x29, 0x250"   );
  h.asm( 'h24c, "addi x28, x0, 13"  );
  h.asm( 'h250, "addi x27, x0, 14"  );

  h.asm( 'h254, "jal  x28, 0x25c"   );
  h.asm( 'h258, "addi x27, x0, 15"  );
  h.asm( 'h25c, "addi x26, x0, 16"  );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_jal_2_deps
//------------------------------------------------------------------------

task test_case_golden_jal_2_deps();
  h.t.test_case_begin( "test_case_golden_jal_2_deps" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "jal  x2, 0x208" );
  h.asm( 'h204, "addi x1, x0, 2" );
  h.asm( 'h208, "addi x1, x2, 3" );

  h.asm( 'h20c, "jal  x3, 0x214" );
  h.asm( 'h210, "addi x1, x0, 2" );
  h.asm( 'h214, "addi x1, x3, 7" );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_golden_jal_tests
//------------------------------------------------------------------------

task run_golden_jal_tests();
  test_case_golden_jal_1_regs();
  test_case_golden_jal_2_deps();
endtask
