//========================================================================
// slti_test_cases
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_slti_1_basic
//------------------------------------------------------------------------

task test_case_directed_slti_1_basic();
  h.t.test_case_begin( "test_case_directed_slti_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 4"  );
  h.asm( 'h004, "slti x2, x1, 5" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0004, 1 ); // addi x1, x0, 4
  h.check_trace( 'h004, 2, 'h0000_0001, 1 ); // slti x3, x1, 5

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_slti_2_x0
//------------------------------------------------------------------------

task test_case_directed_slti_2_x0();
  h.t.test_case_begin( "test_case_directed_slti_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x2, x0, 2"  );
  h.asm( 'h004, "slti x0, x0, 0" );
  h.asm( 'h008, "slti x0, x0, 1" );
  h.asm( 'h00c, "slti x0, x2, 0" );
  h.asm( 'h010, "slti x3, x0, 1" );
  h.asm( 'h014, "slti x4, x2, 0" );

  // Check each executed instruction

  h.check_trace( 'h000,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h004, 'x, 'x,   0 ); // slti x0, x0, 0
  h.check_trace( 'h008, 'x, 'x,   0 ); // slti x0, x0, 1
  h.check_trace( 'h00c, 'x, 'x,   0 ); // slti x0, x2, 0
  h.check_trace( 'h010,  3, 'h01, 1 ); // slti x3, x0, 1
  h.check_trace( 'h014,  4, 'h00, 1 ); // slti x4, x2, 0


  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_slti_3_neg
//------------------------------------------------------------------------

task test_case_directed_slti_3_sign();
  h.t.test_case_begin( "test_case_directed_slti_3_sign" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  -1"    );
  h.asm( 'h004, "addi x2,  x0,  1"     );
  h.asm( 'h008, "addi x3,  x0,  0x800" );

  h.asm( 'h00c, "slti x4,  x1,  1"     );
  h.asm( 'h010, "slti x5,  x2,  0x800" );
  h.asm( 'h014, "slti x6,  x3,  -1"    );
  h.asm( 'h018, "slti x7,  x1,  0"     );
  h.asm( 'h01c, "slti x8,  x1,  -1"    );
  h.asm( 'h020, "slti x9,  x0,  0"     );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'hffff_ffff,    1 ); // addi x1,  x0,  -1
  h.check_trace( 'h004, 2, 'h0000_0001,    1 ); // addi x2,  x0,  1
  h.check_trace( 'h008, 3, 'hffff_f800,    1 ); // addi x3,  x0,  0x800

  h.check_trace( 'h00c, 4, 'h0000_0001,    1 ); // slti x4,  x1,  1
  h.check_trace( 'h010, 5, 'h0000_0000,    1 ); // slti x5,  x2,  0x800
  h.check_trace( 'h014, 6, 'h0000_0001,    1 ); // slti x6,  x3,  -1
  h.check_trace( 'h018, 7, 'h0000_0001,    1 ); // slti x7,  x1,  0
  h.check_trace( 'h01c, 8, 'h0000_0000,    1 ); // slti x8,  x1,  -1
  h.check_trace( 'h020, 9, 'h0000_0000,    1 ); // slti x9,  x0,  0

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_slti_tests
//------------------------------------------------------------------------

task run_directed_slti_tests();
  test_case_directed_slti_1_basic();
  test_case_directed_slti_2_x0();
  test_case_directed_slti_3_sign();
endtask
