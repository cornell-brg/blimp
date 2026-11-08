//========================================================================
// slli_test_cases
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_slli_1_basic
//------------------------------------------------------------------------

task test_case_directed_slli_1_basic();
  h.t.test_case_begin( "test_case_directed_slli_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 7"  );
  h.asm( 'h004, "slli x2, x1, 1" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0007, 1 ); // addi x1, x0, 7
  h.check_trace( 'h004, 2, 'h0000_000e, 1 ); // slli x2, x1, 1

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_slli_2_x0
//------------------------------------------------------------------------

task test_case_directed_slli_2_x0();
  h.t.test_case_begin( "test_case_directed_slli_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x2, x0, 2" );
  h.asm( 'h004, "slli x0, x0, 0" );
  h.asm( 'h008, "slli x0, x0, 1" );
  h.asm( 'h00c, "slli x0, x2, 0" );
  h.asm( 'h010, "slli x3, x0, 1" );
  h.asm( 'h014, "slli x4, x2, 0" );

  // Check each executed instruction

  h.check_trace( 'h000,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h004, 'x, 'x,   0 ); // slli x0, x0, 0
  h.check_trace( 'h008, 'x, 'x,   0 ); // slli x0, x0, 1
  h.check_trace( 'h00c, 'x, 'x,   0 ); // slli x0, x2, 0
  h.check_trace( 'h010,  3, 'h00, 1 ); // slli x3, x0, 1
  h.check_trace( 'h014,  4, 'h02, 1 ); // slli x4, x2, 0


  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_slli_3_upper
//------------------------------------------------------------------------

task test_case_directed_slli_3_upper();
  h.t.test_case_begin( "test_case_directed_slli_3_upper" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  0xfff" );
  h.asm( 'h004, "addi x2,  x0,  0xae0" );
  h.asm( 'h008, "addi x3,  x0,  0x00a" );

  h.asm( 'h00c, "slli  x5,  x3,  0x1f" );
  h.asm( 'h010, "slli  x6,  x3,  0x00" );
  h.asm( 'h014, "slli  x7,  x3,  0x0a" );
  h.asm( 'h018, "slli  x8,  x1,  0x1f" );
  h.asm( 'h01c, "slli  x9,  x3,  0x02" );
  h.asm( 'h020, "slli  x10, x2,  0x02" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'hffff_ffff, 1 ); // addi x1,  x0,  0xfff
  h.check_trace( 'h004, 2, 'hffff_fae0, 1 ); // addi x2,  x0,  0xae0
  h.check_trace( 'h008, 3, 'h0000_000a, 1 ); // addi x3,  x0,  0x00a

  h.check_trace( 'h00c, 5,  'h0000_0000, 1 ); // slli  x5,  x3,  0x1f
  h.check_trace( 'h010, 6,  'h0000_000a, 1 ); // slli  x6,  x3,  0x00
  h.check_trace( 'h014, 7,  'h0000_2800, 1 ); // slli  x7,  x3,  0x0a
  h.check_trace( 'h018, 8,  'h8000_0000, 1 ); // slli  x8,  x1,  0x1f
  h.check_trace( 'h01c, 9,  'h0000_0028, 1 ); // slli  x9,  x3,  0x02
  h.check_trace( 'h020, 10, 'hffff_eb80, 1 ); // slli  x10, x2,  0x02

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_slli_tests
//------------------------------------------------------------------------

task run_directed_slli_tests();
  test_case_directed_slli_1_basic();
  test_case_directed_slli_2_x0();
  test_case_directed_slli_3_upper();
endtask
