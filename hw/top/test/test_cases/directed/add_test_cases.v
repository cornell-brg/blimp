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

  h.asm( 'h000, "addi x1, x0, 2"  );
  h.asm( 'h004, "addi x2, x0, 3"  );
  h.asm( 'h008, "add  x3, x1, x2" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0002, 1 ); // addi x1, x0, 2
  h.check_trace( 'h004, 2, 'h0000_0003, 1 ); // addi x2, x0, 3
  h.check_trace( 'h008, 3, 'h0000_0005, 1 ); // add  x3, x1, x2

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

  h.asm( 'h000, "addi x1, x0, 1"  );
  h.asm( 'h004, "addi x2, x0, 2"  );
  h.asm( 'h008, "add  x0, x0, x0" );
  h.asm( 'h00c, "add  x0, x0, x1" );
  h.asm( 'h010, "add  x0, x2, x0" );
  h.asm( 'h014, "add  x3, x0, x1" );
  h.asm( 'h018, "add  x4, x2, x0" );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h01, 1 ); // addi x1, x0, 1
  h.check_trace( 'h004,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h008, 'x, 'x,   0 ); // add  x0, x0, x0
  h.check_trace( 'h00c, 'x, 'x,   0 ); // add  x0, x0, x1
  h.check_trace( 'h010, 'x, 'x,   0 ); // add  x0, x2, x0
  h.check_trace( 'h014,  3, 'h01, 1 ); // add  x3, x0, x1
  h.check_trace( 'h018,  4, 'h02, 1 ); // add  x4, x2, x0


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

  h.asm( 'h000, "addi x1,  x0,  1"    );
  h.asm( 'h004, "addi x2,  x0,  2"    );
  h.asm( 'h008, "addi x3,  x0,  3"    );
  h.asm( 'h00c, "addi x4,  x0,  4"    );

  h.asm( 'h010, "add  x5,  x1,  x2"   );
  h.asm( 'h014, "add  x6,  x2,  x3"   );
  h.asm( 'h018, "add  x7,  x3,  x4"   );

  h.asm( 'h01c, "addi x1,  x0,  2001" );
  h.asm( 'h020, "addi x2,  x0,  2002" );
  h.asm( 'h024, "addi x3,  x0,  2003" );
  h.asm( 'h028, "addi x4,  x0,  2004" );

  h.asm( 'h02c, "add  x5,  x1,  x2"   );
  h.asm( 'h030, "add  x6,  x2,  x3"   );
  h.asm( 'h034, "add  x7,  x3,  x4"   );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 1,    1 ); // addi x1,  x0,  1
  h.check_trace( 'h004, 2, 2,    1 ); // addi x2,  x0,  2
  h.check_trace( 'h008, 3, 3,    1 ); // addi x3,  x0,  3
  h.check_trace( 'h00c, 4, 4,    1 ); // addi x4,  x0,  4

  h.check_trace( 'h010, 5, 3,    1 ); // add  x5,  x1,  x2
  h.check_trace( 'h014, 6, 5,    1 ); // add  x6,  x2,  x3
  h.check_trace( 'h018, 7, 7,    1 ); // add  x7,  x3,  x4

  h.check_trace( 'h01c, 1, 2001, 1 ); // addi x1,  x0,  2001
  h.check_trace( 'h020, 2, 2002, 1 ); // addi x2,  x0,  2002
  h.check_trace( 'h024, 3, 2003, 1 ); // addi x3,  x0,  2003
  h.check_trace( 'h028, 4, 2004, 1 ); // addi x4,  x0,  2004

  h.check_trace( 'h02c, 5, 4003, 1 ); // add  x5,  x1,  x2
  h.check_trace( 'h030, 6, 4005, 1 ); // add  x6,  x2,  x3
  h.check_trace( 'h034, 7, 4007, 1 ); // add  x7,  x3,  x4

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

  h.asm( 'h000, "addi x1,  x0,  -1"    );
  h.asm( 'h004, "addi x2,  x0,  -2"    );
  h.asm( 'h008, "addi x3,  x0,  -3"    );
  h.asm( 'h00c, "addi x4,  x0,  -4"    );

  h.asm( 'h010, "add  x5,  x1,  x2"    );
  h.asm( 'h014, "add  x6,  x2,  x3"    );
  h.asm( 'h018, "add  x7,  x3,  x4"    );

  h.asm( 'h01c, "addi x1,  x0,  -2001" );
  h.asm( 'h020, "addi x2,  x0,  -2002" );
  h.asm( 'h024, "addi x3,  x0,  -2003" );
  h.asm( 'h028, "addi x4,  x0,  -2004" );

  h.asm( 'h02c, "add  x5,  x1,  x2"    );
  h.asm( 'h030, "add  x6,  x2,  x3"    );
  h.asm( 'h034, "add  x7,  x3,  x4"    );

  // Check each executed instruction

  h.check_trace( 'h000, 1, -1,    1 ); // addi x1,  x0,  -1
  h.check_trace( 'h004, 2, -2,    1 ); // addi x2,  x0,  -2
  h.check_trace( 'h008, 3, -3,    1 ); // addi x3,  x0,  -3
  h.check_trace( 'h00c, 4, -4,    1 ); // addi x4,  x0,  -4

  h.check_trace( 'h010, 5, -3,    1 ); // add  x5,  x1,  x2
  h.check_trace( 'h014, 6, -5,    1 ); // add  x6,  x2,  x3
  h.check_trace( 'h018, 7, -7,    1 ); // add  x7,  x3,  x4

  h.check_trace( 'h01c, 1, -2001, 1 ); // addi x1,  x0,  -2001
  h.check_trace( 'h020, 2, -2002, 1 ); // addi x2,  x0,  -2002
  h.check_trace( 'h024, 3, -2003, 1 ); // addi x3,  x0,  -2003
  h.check_trace( 'h028, 4, -2004, 1 ); // addi x4,  x0,  -2004

  h.check_trace( 'h02c, 5, -4003, 1 ); // add  x5,  x1,  x2
  h.check_trace( 'h030, 6, -4005, 1 ); // add  x6,  x2,  x3
  h.check_trace( 'h034, 7, -4007, 1 ); // add  x7,  x3,  x4

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

  h.asm( 'h000, "addi x1,  x0,  0xfff" );
  h.asm( 'h004, "addi x2,  x0,  1"     );
  h.asm( 'h008, "add  x3,  x1,  x2"    );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'hffff_ffff, 1 ); // addi x1,  x0,  0xfff
  h.check_trace( 'h004, 2, 'h0000_0001, 1 ); // addi x2,  x0,  1
  h.check_trace( 'h008, 3, 'h0000_0000, 1 ); // addi x3,  x1,  x2

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
