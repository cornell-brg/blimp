//========================================================================
// rem_test_cases.v
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_rem_1_basic
//------------------------------------------------------------------------

task test_case_directed_rem_1_basic();
  h.t.test_case_begin( "test_case_directed_rem_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 6"  );
  h.asm( 'h004, "addi x2, x0, 3"  );
  h.asm( 'h008, "rem  x3, x1, x2" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0006, 1 ); // addi x1, x0, 2
  h.check_trace( 'h004, 2, 'h0000_0003, 1 ); // addi x2, x0, 3
  h.check_trace( 'h008, 3, 'h0000_0000, 1 ); // rem  x3, x1, x2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_rem_2_x0
//------------------------------------------------------------------------

task test_case_directed_rem_2_x0();
  h.t.test_case_begin( "test_case_directed_rem_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 1"  );
  h.asm( 'h004, "addi x2, x0, 2"  );
  h.asm( 'h008, "rem  x0, x0, x1" );
  h.asm( 'h00c, "rem  x3, x0, x2" );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h01, 1 ); // addi x1, x0, 1
  h.check_trace( 'h004,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h008, 'x, 'x,   0 ); // rem  x0, x0, x1
  h.check_trace( 'h00c,  3, 'h00, 1 ); // rem  x3, x0, x2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_rem_3_pos
//------------------------------------------------------------------------

task test_case_directed_rem_3_pos();
  h.t.test_case_begin( "test_case_directed_rem_3_pos" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  24"   );
  h.asm( 'h004, "addi x2,  x0,  12"   );
  h.asm( 'h008, "addi x3,  x0,  5"    );
  h.asm( 'h00c, "addi x4,  x0,  2"    );

  h.asm( 'h010, "rem  x5,  x1,  x2"   );
  h.asm( 'h014, "rem  x6,  x2,  x3"   );
  h.asm( 'h018, "rem  x7,  x3,  x4"   );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 24,        1 ); // addi x1,  x0,  24
  h.check_trace( 'h004, 2, 12,        1 ); // addi x2,  x0,  12
  h.check_trace( 'h008, 3, 5,         1 ); // addi x3,  x0,  5
  h.check_trace( 'h00c, 4, 2,         1 ); // addi x4,  x0,  2

  h.check_trace( 'h010, 5, 0,         1 ); // rem  x5,  x1,  x2
  h.check_trace( 'h014, 6, 2,         1 ); // rem  x6,  x2,  x3
  h.check_trace( 'h018, 7, 1,         1 ); // rem  x7,  x3,  x4

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_rem_4_neg
//------------------------------------------------------------------------

task test_case_directed_rem_4_neg();
  h.t.test_case_begin( "test_case_directed_rem_4_neg" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  -48"   );
  h.asm( 'h004, "addi x2,  x0,   11"   );
  h.asm( 'h008, "addi x3,  x0,  -6"    );
  h.asm( 'h00c, "addi x4,  x0,  -4"    );

  h.asm( 'h010, "rem  x5,  x1,  x2"    );
  h.asm( 'h014, "rem  x6,  x2,  x3"    );
  h.asm( 'h018, "rem  x7,  x3,  x4"    );

  // Check each executed instruction

  h.check_trace( 'h000, 1, -48,        1 ); // addi x1,  x0, -48
  h.check_trace( 'h004, 2,  11,        1 ); // addi x2,  x0,  11
  h.check_trace( 'h008, 3, -6,         1 ); // addi x3,  x0,  -6
  h.check_trace( 'h00c, 4, -4,         1 ); // addi x4,  x0,  -4

  h.check_trace( 'h010, 5, -4,         1 ); // rem  x5,  x1,  x2
  h.check_trace( 'h014, 6,  5,         1 ); // rem  x6,  x2,  x3
  h.check_trace( 'h018, 7, -2,         1 ); // rem  x7,  x3,  x4

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_rem_5_zero
//------------------------------------------------------------------------

task test_case_directed_rem_5_zero();
  h.t.test_case_begin( "test_case_directed_rem_5_zero" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  0x64" );
  h.asm( 'h004, "rem  x2,  x1,  x0"   );
  h.asm( 'h008, "rem  x3,  x0,  x0"   );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0064, 1 ); // addi x1,  x0,  0x64
  h.check_trace( 'h004, 2, 'h0000_0064, 1 ); // rem  x2,  x1,  x0
  h.check_trace( 'h008, 3, 'h0000_0000, 1 ); // rem  x3,  x0,  x0

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_rem_6_overflow
//------------------------------------------------------------------------

task test_case_directed_rem_6_overflow();
  h.t.test_case_begin( "test_case_directed_rem_6_overflow" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "lui  x1,  0x80000"  );
  h.asm( 'h004, "addi x2,  x0,  -1"  );
  h.asm( 'h008, "rem  x3,  x1,  x2" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h8000_0000, 1 ); // lui  x1,  0x80000
  h.check_trace( 'h004, 2, 'hffff_ffff, 1 ); // addi x2,  x0,  -1
  h.check_trace( 'h008, 3, 'h0000_0000, 1 ); // rem  x3,  x1,  x2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_rem_tests
//------------------------------------------------------------------------

task run_directed_rem_tests();
  test_case_directed_rem_1_basic();
  test_case_directed_rem_2_x0();
  test_case_directed_rem_3_pos();
  test_case_directed_rem_4_neg();
  test_case_directed_rem_5_zero();
  test_case_directed_rem_6_overflow();
endtask
