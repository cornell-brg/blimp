//========================================================================
// addi_test_cases.v
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_golden_addi_1_regs
//------------------------------------------------------------------------

task test_case_golden_addi_1_regs();
  h.t.test_case_begin( "test_case_golden_addi_1_regs" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  0x01"   );
  h.asm( 'h004, "addi x2,  x0,  0x02"   );
  h.asm( 'h008, "addi x3,  x0,  0x03"   );
  h.asm( 'h00c, "addi x4,  x0,  0x04"   );

  h.asm( 'h010, "addi x28, x0,  0x05"   );
  h.asm( 'h014, "addi x29, x0,  0x06"   );
  h.asm( 'h018, "addi x30, x0,  0x07"   );
  h.asm( 'h01c, "addi x31, x0,  0x08"   );

  h.asm( 'h020, "addi x5,  x1,  0x09"   );
  h.asm( 'h024, "addi x6,  x2,  0x0a"   );
  h.asm( 'h028, "addi x7,  x3,  0x0b"   );
  h.asm( 'h02c, "addi x8,  x4,  0x0c"   );

  h.asm( 'h030, "addi x24, x28, 0x0d"   );
  h.asm( 'h034, "addi x25, x29, 0x0e"   );
  h.asm( 'h038, "addi x26, x30, 0x0f"   );
  h.asm( 'h03c, "addi x27, x31, 0x10"   );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_addi_2_deps
//------------------------------------------------------------------------

task test_case_golden_addi_2_deps();
  h.t.test_case_begin( "test_case_golden_addi_2_deps" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  0x01"   );
  h.asm( 'h004, "addi x1,  x1,  0x02"   );
  h.asm( 'h008, "addi x1,  x1,  0x03"   );
  h.asm( 'h00c, "addi x1,  x1,  0x04"   );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_golden_addi_tests
//------------------------------------------------------------------------

task run_golden_addi_tests();
  test_case_golden_addi_1_regs();
  test_case_golden_addi_2_deps();
endtask
