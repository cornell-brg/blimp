//========================================================================
// srai_test_cases
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_srai_1_basic
//------------------------------------------------------------------------

task test_case_directed_srai_1_basic();
  h.t.test_case_begin( "test_case_directed_srai_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 7"  );
  h.asm( 'h004, "srai x2, x1, 1" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0007, 1 ); // addi x1, x0, 7
  h.check_trace( 'h004, 2, 'h0000_0003, 1 ); // srai x2, x1, 1

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_srai_2_x0
//------------------------------------------------------------------------

task test_case_directed_srai_2_x0();
  h.t.test_case_begin( "test_case_directed_srai_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x2, x0, 2" );
  h.asm( 'h004, "srai x0, x0, 0" );
  h.asm( 'h008, "srai x0, x0, 1" );
  h.asm( 'h00c, "srai x0, x2, 0" );
  h.asm( 'h010, "srai x3, x0, 1" );
  h.asm( 'h014, "srai x4, x2, 0" );

  // Check each executed instruction

  h.check_trace( 'h000,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h004, 'x, 'x,   0 ); // srai x0, x0, 0
  h.check_trace( 'h008, 'x, 'x,   0 ); // srai x0, x0, 1
  h.check_trace( 'h00c, 'x, 'x,   0 ); // srai x0, x2, 0
  h.check_trace( 'h010,  3, 'h00, 1 ); // srai x3, x0, 1
  h.check_trace( 'h014,  4, 'h02, 1 ); // srai x4, x2, 0


  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_srai_3_upper
//------------------------------------------------------------------------

task test_case_directed_srai_3_upper();
  h.t.test_case_begin( "test_case_directed_srai_3_upper" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  0xfff" );
  h.asm( 'h004, "addi x2,  x0,  0xae0" );
  h.asm( 'h008, "addi x3,  x0,  0x00a" );

  h.asm( 'h00c, "srai  x5,  x3,  0x1f" );
  h.asm( 'h010, "srai  x6,  x3,  0x00" );
  h.asm( 'h014, "srai  x7,  x3,  0x0a" );
  h.asm( 'h018, "srai  x8,  x1,  0x1f" );
  h.asm( 'h01c, "srai  x9,  x3,  0x02" );
  h.asm( 'h020, "srai  x10, x2,  0x02" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'hffff_ffff, 1 ); // addi x1,  x0,  0xfff
  h.check_trace( 'h004, 2, 'hffff_fae0, 1 ); // addi x2,  x0,  0xae0
  h.check_trace( 'h008, 3, 'h0000_000a, 1 ); // addi x3,  x0,  0x00a

  h.check_trace( 'h00c, 5,  'h0000_0000, 1 ); // srai  x5,  x3,  0x1f
  h.check_trace( 'h010, 6,  'h0000_000a, 1 ); // srai  x6,  x3,  0x00
  h.check_trace( 'h014, 7,  'h0000_0000, 1 ); // srai  x7,  x3,  0x0a
  h.check_trace( 'h018, 8,  'hffff_ffff, 1 ); // srai  x8,  x1,  0x1f
  h.check_trace( 'h01c, 9,  'h0000_0002, 1 ); // srai  x9,  x3,  0x02
  h.check_trace( 'h020, 10, 'hffff_feb8, 1 ); // srai  x10, x2,  0x02

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_srai_tests
//------------------------------------------------------------------------

task run_directed_srai_tests();
  test_case_directed_srai_1_basic();
  test_case_directed_srai_2_x0();
  test_case_directed_srai_3_upper();
endtask
