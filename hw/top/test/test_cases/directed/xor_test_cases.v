//========================================================================
// xor_test_cases
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_xor_1_basic
//------------------------------------------------------------------------

task test_case_directed_xor_1_basic();
  h.t.test_case_begin( "test_case_directed_xor_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 5"  );
  h.asm( 'h004, "addi x2, x0, 3"  );
  h.asm( 'h008, "xor  x3, x1, x2" );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0005, 1 ); // addi x1, x0, 5
  h.check_trace( 'h004, 2, 'h0000_0003, 1 ); // addi x2, x0, 3
  h.check_trace( 'h008, 3, 'h0000_0006, 1 ); // xor  x3, x1, x2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_xor_2_x0
//------------------------------------------------------------------------

task test_case_directed_xor_2_x0();
  h.t.test_case_begin( "test_case_directed_xor_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 1"  );
  h.asm( 'h004, "addi x2, x0, 2"  );
  h.asm( 'h008, "xor  x0, x0, x0" );
  h.asm( 'h00c, "xor  x0, x0, x1" );
  h.asm( 'h010, "xor  x0, x2, x0" );
  h.asm( 'h014, "xor  x3, x0, x1" );
  h.asm( 'h018, "xor  x4, x2, x0" );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h01, 1 ); // addi x1, x0, 1
  h.check_trace( 'h004,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h008, 'x, 'x,   0 ); // xor  x0, x0, x0
  h.check_trace( 'h00c, 'x, 'x,   0 ); // xor  x0, x0, x1
  h.check_trace( 'h010, 'x, 'x,   0 ); // xor  x0, x2, x0
  h.check_trace( 'h014,  3, 'h01, 1 ); // xor  x3, x0, x1
  h.check_trace( 'h018,  4, 'h02, 1 ); // xor  x4, x2, x0


  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_xor_3_extreme
//------------------------------------------------------------------------

task test_case_directed_xor_3_extreme();
  h.t.test_case_begin( "test_case_directed_xor_3_extreme" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0,  0xfff" );
  h.asm( 'h004, "addi x2,  x0,  0x7ff" );
  h.asm( 'h008, "addi x3,  x0,  1"     );

  h.asm( 'h00c, "xor  x4,  x1,  x2"   );
  h.asm( 'h010, "xor  x5,  x2,  x3"   );
  h.asm( 'h014, "xor  x6,  x3,  x1"   );
  h.asm( 'h018, "xor  x7,  x1,  x0"   );
  h.asm( 'h01c, "xor  x8,  x1,  x1"   );
  h.asm( 'h020, "xor  x9,  x0,  x0"   );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'hffff_ffff,    1 ); // addi x1,  x0,  0xfff
  h.check_trace( 'h004, 2, 'h0000_07ff,    1 ); // addi x2,  x0,  0x7ff
  h.check_trace( 'h008, 3, 'h0000_0001,    1 ); // addi x3,  x0,  1

  h.check_trace( 'h00c, 4, 'hffff_f800,    1 ); // xor  x4,  x1,  x2
  h.check_trace( 'h010, 5, 'h0000_07fe,    1 ); // xor  x5,  x2,  x3
  h.check_trace( 'h014, 6, 'hffff_fffe,    1 ); // xor  x6,  x3,  x1
  h.check_trace( 'h018, 7, 'hffff_ffff,    1 ); // xor  x7,  x1,  x0
  h.check_trace( 'h01c, 8, 'h0000_0000,    1 ); // xor  x8,  x1,  x1
  h.check_trace( 'h020, 9, 'h0000_0000,    1 ); // xor  x9,  x0,  x0

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_xor_tests
//------------------------------------------------------------------------

task run_directed_xor_tests();
  test_case_directed_xor_1_basic();
  test_case_directed_xor_2_x0();
  test_case_directed_xor_3_extreme();
endtask
