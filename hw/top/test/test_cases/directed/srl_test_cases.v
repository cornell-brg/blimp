//========================================================================
// srl_test_cases
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_srl_1_basic
//------------------------------------------------------------------------

task test_case_directed_srl_1_basic();
  h.t.test_case_begin( "test_case_directed_srl_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 7"  );
  h.asm( 'h004, "addi x2, x0, 1"  );
  h.asm( 'h008, "srl  x3, x1, x2" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0007, 1 ); // addi x1, x0, 7
  h.check_trace( 'h004, 2, 'h0000_0001, 1 ); // addi x2, x0, 1
  h.check_trace( 'h008, 3, 'h0000_0003, 1 ); // srl  x3, x1, x2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_srl_2_x0
//------------------------------------------------------------------------

task test_case_directed_srl_2_x0();
  h.t.test_case_begin( "test_case_directed_srl_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 1"  );
  h.asm( 'h004, "addi x2, x0, 2"  );
  h.asm( 'h008, "srl  x0, x0, x0" );
  h.asm( 'h00c, "srl  x0, x0, x1" );
  h.asm( 'h010, "srl  x0, x2, x0" );
  h.asm( 'h014, "srl  x3, x0, x1" );
  h.asm( 'h018, "srl  x4, x2, x0" );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h01, 1 ); // addi x1, x0, 1
  h.check_trace( 'h004,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h008, 'x, 'x,   0 ); // srl  x0, x0, x0
  h.check_trace( 'h00c, 'x, 'x,   0 ); // srl  x0, x0, x1
  h.check_trace( 'h010, 'x, 'x,   0 ); // srl  x0, x2, x0
  h.check_trace( 'h014,  3, 'h00, 1 ); // srl  x3, x0, x1
  h.check_trace( 'h018,  4, 'h02, 1 ); // srl  x4, x2, x0


  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_srl_3_upper
//------------------------------------------------------------------------

task test_case_directed_srl_3_upper();
  h.t.test_case_begin( "test_case_directed_srl_3_upper" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  0xfff" );
  h.asm( 'h004, "addi x2,  x0,  0xae0" );
  h.asm( 'h008, "addi x3,  x0,  0x00a" );
  h.asm( 'h00c, "addi x4,  x0,  0x002" );

  h.asm( 'h010, "srl  x5,  x3,  x1"   );
  h.asm( 'h014, "srl  x6,  x3,  x2"   );
  h.asm( 'h018, "srl  x7,  x3,  x3"   );
  h.asm( 'h01c, "srl  x8,  x1,  x1"   );
  h.asm( 'h020, "srl  x9,  x3,  x4"   );
  h.asm( 'h024, "srl  x10, x2,  x4"   );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'hffff_ffff, 1 ); // addi x1,  x0,  0xfff
  h.check_trace( 'h004, 2, 'hffff_fae0, 1 ); // addi x2,  x0,  0xae0
  h.check_trace( 'h008, 3, 'h0000_000a, 1 ); // addi x3,  x0,  0x00a
  h.check_trace( 'h00c, 4, 'h0000_0002, 1 ); // addi x4,  x0,  2

  h.check_trace( 'h010, 5,  'h0000_0000, 1 ); // srl  x5,  x3,  x1
  h.check_trace( 'h014, 6,  'h0000_000a, 1 ); // srl  x6,  x3,  x2
  h.check_trace( 'h018, 7,  'h0000_0000, 1 ); // srl  x7,  x3,  x3
  h.check_trace( 'h01c, 8,  'h0000_0001, 1 ); // srl  x8,  x1,  x1
  h.check_trace( 'h020, 9,  'h0000_0002, 1 ); // srl  x9,  x3,  x4
  h.check_trace( 'h024, 10, 'h3fff_feb8, 1 ); // srl  x10, x2,  x4

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_srl_tests
//------------------------------------------------------------------------

task run_directed_srl_tests();
  test_case_directed_srl_1_basic();
  test_case_directed_srl_2_x0();
  test_case_directed_srl_3_upper();
endtask
