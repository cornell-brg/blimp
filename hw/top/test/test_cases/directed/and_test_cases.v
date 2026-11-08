//========================================================================
// and_test_cases
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_and_1_basic
//------------------------------------------------------------------------

task test_case_directed_and_1_basic();
  h.t.test_case_begin( "test_case_directed_and_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 5"  );
  h.asm( 'h004, "addi x2, x0, 3"  );
  h.asm( 'h008, "and  x3, x1, x2" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0005, 1 ); // addi x1, x0, 5
  h.check_trace( 'h004, 2, 'h0000_0003, 1 ); // addi x2, x0, 3
  h.check_trace( 'h008, 3, 'h0000_0001, 1 ); // and  x3, x1, x2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_and_2_x0
//------------------------------------------------------------------------

task test_case_directed_and_2_x0();
  h.t.test_case_begin( "test_case_directed_and_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 1"  );
  h.asm( 'h004, "addi x2, x0, 2"  );
  h.asm( 'h008, "and  x0, x0, x0" );
  h.asm( 'h00c, "and  x0, x0, x1" );
  h.asm( 'h010, "and  x0, x2, x0" );
  h.asm( 'h014, "and  x3, x0, x1" );
  h.asm( 'h018, "and  x4, x2, x0" );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h01, 1 ); // addi x1, x0, 1
  h.check_trace( 'h004,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h008, 'x, 'x,   0 ); // and  x0, x0, x0
  h.check_trace( 'h00c, 'x, 'x,   0 ); // and  x0, x0, x1
  h.check_trace( 'h010, 'x, 'x,   0 ); // and  x0, x2, x0
  h.check_trace( 'h014,  3, 'h00, 1 ); // and  x3, x0, x1
  h.check_trace( 'h018,  4, 'h00, 1 ); // and  x4, x2, x0


  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_and_3_extreme
//------------------------------------------------------------------------

task test_case_directed_and_3_extreme();
  h.t.test_case_begin( "test_case_directed_and_3_extreme" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  0xfff" );
  h.asm( 'h004, "addi x2,  x0,  0x7ff" );
  h.asm( 'h008, "addi x3,  x0,  1"     );

  h.asm( 'h00c, "and  x4,  x1,  x2"   );
  h.asm( 'h010, "and  x5,  x2,  x3"   );
  h.asm( 'h014, "and  x6,  x3,  x1"   );
  h.asm( 'h018, "and  x7,  x1,  x0"   );
  h.asm( 'h01c, "and  x8,  x1,  x1"   );
  h.asm( 'h020, "and  x9,  x0,  x0"   );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'hffff_ffff,    1 ); // addi x1,  x0,  0xfff
  h.check_trace( 'h004, 2, 'h0000_07ff,    1 ); // addi x2,  x0,  0x7ff
  h.check_trace( 'h008, 3, 'h0000_0001,    1 ); // addi x3,  x0,  1

  h.check_trace( 'h00c, 4, 'h0000_07ff,    1 ); // and  x4,  x1,  x2
  h.check_trace( 'h010, 5, 'h0000_0001,    1 ); // and  x5,  x2,  x3
  h.check_trace( 'h014, 6, 'h0000_0001,    1 ); // and  x6,  x3,  x1
  h.check_trace( 'h018, 7, 'h0000_0000,    1 ); // and  x7,  x1,  x0
  h.check_trace( 'h01c, 8, 'hffff_ffff,    1 ); // and  x8,  x1,  x1
  h.check_trace( 'h020, 9, 'h0000_0000,    1 ); // and  x9,  x0,  x0

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_and_tests
//------------------------------------------------------------------------

task run_directed_and_tests();
  test_case_directed_and_1_basic();
  test_case_directed_and_2_x0();
  test_case_directed_and_3_extreme();
endtask
