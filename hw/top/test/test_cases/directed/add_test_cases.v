//========================================================================
// add_test_cases
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_directed_add_1_basic
//------------------------------------------------------------------------

task test_case_directed_add_1_basic();
  h.t.test_case_begin( "test_case_directed_add_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1, x0, 2"  );
  h.asm( 'h204, "addi x2, x0, 3"  );
  h.asm( 'h208, "add  x3, x1, x2" );

  // Check each executed instruction

  h.check_trace( 'h200, 1, 'h0000_0002, 1 ); // addi x1, x0, 2
  h.check_trace( 'h204, 2, 'h0000_0003, 1 ); // addi x2, x0, 3
  h.check_trace( 'h208, 3, 'h0000_0005, 1 ); // add  x3, x1, x2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_add_2_x0
//------------------------------------------------------------------------

task test_case_directed_add_2_x0();
  h.t.test_case_begin( "test_case_directed_add_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1, x0, 1"  );
  h.asm( 'h204, "addi x2, x0, 2"  );
  h.asm( 'h208, "add  x0, x0, x0" );
  h.asm( 'h20c, "add  x0, x0, x1" );
  h.asm( 'h210, "add  x0, x2, x0" );
  h.asm( 'h214, "add  x3, x0, x1" );
  h.asm( 'h218, "add  x4, x2, x0" );

  // Check each executed instruction

  h.check_trace( 'h200,  1, 'h01, 1 ); // addi x1, x0, 1
  h.check_trace( 'h204,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h208, 'x, 'x,   0 ); // add  x0, x0, x0
  h.check_trace( 'h20c, 'x, 'x,   0 ); // add  x0, x0, x1
  h.check_trace( 'h210, 'x, 'x,   0 ); // add  x0, x2, x0
  h.check_trace( 'h214,  3, 'h01, 1 ); // add  x3, x0, x1
  h.check_trace( 'h218,  4, 'h02, 1 ); // add  x4, x2, x0


  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_add_3_pos
//------------------------------------------------------------------------

task test_case_directed_add_3_pos();
  h.t.test_case_begin( "test_case_directed_add_3_pos" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1,  x0,  1"    ); // x1 = 1
  h.asm( 'h204, "addi x2,  x0,  2"    ); // x2 = 2
  h.asm( 'h208, "addi x3,  x0,  3"    ); // x3 = 3
  h.asm( 'h20c, "addi x4,  x0,  4"    ); // x4 = 4

  h.asm( 'h210, "add  x5,  x1,  x2"   ); // x5 = 3
  h.asm( 'h214, "add  x6,  x2,  x3"   ); // x6 = 5
  h.asm( 'h218, "add  x7,  x3,  x4"   ); // x7 = 7

  h.asm( 'h21c, "addi x1,  x0,  2001" ); // x1 = 2001
  h.asm( 'h220, "addi x2,  x0,  2002" ); // x2 = 2002
  h.asm( 'h224, "addi x3,  x0,  2003" ); // x3 = 2003
  h.asm( 'h228, "addi x4,  x0,  2004" ); // x4 = 2004

  h.asm( 'h22c, "add  x5,  x1,  x2"   ); // x5 = 4003
  h.asm( 'h230, "add  x6,  x2,  x3"   ); // x6 = 4005
  h.asm( 'h234, "add  x7,  x3,  x4"   ); // x7 = 4007

  // Check each executed instruction

  h.check_trace( 'h200, 1, 1,    1 ); // addi x1,  x0,  1
  h.check_trace( 'h204, 2, 2,    1 ); // addi x2,  x0,  2
  h.check_trace( 'h208, 3, 3,    1 ); // addi x3,  x0,  3
  h.check_trace( 'h20c, 4, 4,    1 ); // addi x4,  x0,  4

  h.check_trace( 'h210, 5, 3,    1 ); // add  x5,  x1,  x2
  h.check_trace( 'h214, 6, 5,    1 ); // add  x6,  x2,  x3
  h.check_trace( 'h218, 7, 7,    1 ); // add  x7,  x3,  x4

  h.check_trace( 'h21c, 1, 2001, 1 ); // addi x1,  x0,  2001
  h.check_trace( 'h220, 2, 2002, 1 ); // addi x2,  x0,  2002
  h.check_trace( 'h224, 3, 2003, 1 ); // addi x3,  x0,  2003
  h.check_trace( 'h228, 4, 2004, 1 ); // addi x4,  x0,  2004

  h.check_trace( 'h22c, 5, 4003, 1 ); // add  x5,  x1,  x2
  h.check_trace( 'h230, 6, 4005, 1 ); // add  x6,  x2,  x3
  h.check_trace( 'h234, 7, 4007, 1 ); // add  x7,  x3,  x4

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_add_4_neg
//------------------------------------------------------------------------

task test_case_directed_add_4_neg();
  h.t.test_case_begin( "test_case_directed_add_4_neg" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1,  x0,  -1"    );
  h.asm( 'h204, "addi x2,  x0,  -2"    );
  h.asm( 'h208, "addi x3,  x0,  -3"    );
  h.asm( 'h20c, "addi x4,  x0,  -4"    );

  h.asm( 'h210, "add  x5,  x1,  x2"    );
  h.asm( 'h214, "add  x6,  x2,  x3"    );
  h.asm( 'h218, "add  x7,  x3,  x4"    );

  h.asm( 'h21c, "addi x1,  x0,  -2001" );
  h.asm( 'h220, "addi x2,  x0,  -2002" );
  h.asm( 'h224, "addi x3,  x0,  -2003" );
  h.asm( 'h228, "addi x4,  x0,  -2004" );

  h.asm( 'h22c, "add  x5,  x1,  x2"    );
  h.asm( 'h230, "add  x6,  x2,  x3"    );
  h.asm( 'h234, "add  x7,  x3,  x4"    );

  // Check each executed instruction

  h.check_trace( 'h200, 1, -1,    1 ); // addi x1,  x0,  -1
  h.check_trace( 'h204, 2, -2,    1 ); // addi x2,  x0,  -2
  h.check_trace( 'h208, 3, -3,    1 ); // addi x3,  x0,  -3
  h.check_trace( 'h20c, 4, -4,    1 ); // addi x4,  x0,  -4

  h.check_trace( 'h210, 5, -3,    1 ); // add  x5,  x1,  x2
  h.check_trace( 'h214, 6, -5,    1 ); // add  x6,  x2,  x3
  h.check_trace( 'h218, 7, -7,    1 ); // add  x7,  x3,  x4

  h.check_trace( 'h21c, 1, -2001, 1 ); // addi x1,  x0,  -2001
  h.check_trace( 'h220, 2, -2002, 1 ); // addi x2,  x0,  -2002
  h.check_trace( 'h224, 3, -2003, 1 ); // addi x3,  x0,  -2003
  h.check_trace( 'h228, 4, -2004, 1 ); // addi x4,  x0,  -2004

  h.check_trace( 'h22c, 5, -4003, 1 ); // add  x5,  x1,  x2
  h.check_trace( 'h230, 6, -4005, 1 ); // add  x6,  x2,  x3
  h.check_trace( 'h234, 7, -4007, 1 ); // add  x7,  x3,  x4

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_add_5_overflow
//------------------------------------------------------------------------

task test_case_directed_add_5_overflow();
  h.t.test_case_begin( "test_case_directed_add_5_overflow" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1,  x0,  0xfff" );
  h.asm( 'h204, "addi x2,  x0,  1"     );
  h.asm( 'h208, "add  x3,  x1,  x2"    );

  // Check each executed instruction

  h.check_trace( 'h200, 1, 'hffff_ffff, 1 ); // addi x1,  x0,  0xfff
  h.check_trace( 'h204, 2, 'h0000_0001, 1 ); // addi x2,  x0,  1
  h.check_trace( 'h208, 3, 'h0000_0000, 1 ); // addi x3,  x1,  x2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_instruction_tests
//------------------------------------------------------------------------

task run_directed_add_tests();
  test_case_directed_add_1_basic();
  test_case_directed_add_2_x0();
  test_case_directed_add_3_pos();
  test_case_directed_add_4_neg();
  test_case_directed_add_5_overflow();
endtask
