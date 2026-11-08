//========================================================================
// mulh_test_cases.v
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_mulh_1_basic
//------------------------------------------------------------------------

task test_case_directed_mulh_1_basic();
  h.t.test_case_begin( "test_case_directed_mulh_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "lui  x1, 0x00020"  );
  h.asm( 'h004, "lui  x2, 0x00030"  );
  h.asm( 'h008, "mulh x3, x1, x2"   );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0002_0000, 1 ); // lui  x1, 0x00020
  h.check_trace( 'h004, 2, 'h0003_0000, 1 ); // lui  x2, 0x00030
  h.check_trace( 'h008, 3, 'h0000_0006, 1 ); // mulh x3, x1, x2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_mulh_2_x0
//------------------------------------------------------------------------

task test_case_directed_mulh_2_x0();
  h.t.test_case_begin( "test_case_directed_mulh_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 1"  );
  h.asm( 'h004, "addi x2, x0, 2"  );
  h.asm( 'h008, "mulh x0, x0, x0" );
  h.asm( 'h00c, "mulh x0, x0, x1" );
  h.asm( 'h010, "mulh x0, x2, x0" );
  h.asm( 'h014, "mulh x3, x0, x1" );
  h.asm( 'h018, "mulh x4, x2, x0" );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h01, 1 ); // addi x1, x0, 1
  h.check_trace( 'h004,  2, 'h02, 1 ); // addi x2, x0, 2
  h.check_trace( 'h008, 'x, 'x,   0 ); // mulh x0, x0, x0
  h.check_trace( 'h00c, 'x, 'x,   0 ); // mulh x0, x0, x1
  h.check_trace( 'h010, 'x, 'x,   0 ); // mulh x0, x2, x0
  h.check_trace( 'h014,  3, 'h00, 1 ); // mulh x3, x0, x1
  h.check_trace( 'h018,  4, 'h00, 1 ); // mulh x4, x2, x0

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_mulh_3_upper_bit
//------------------------------------------------------------------------

task test_case_directed_mulh_3_upper_bit();
  h.t.test_case_begin( "test_case_directed_mulh_3_upper_bit" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "lui  x1, 0x80000" );
  h.asm( 'h004, "lui  x2, 0x7ffff" );
  h.asm( 'h008, "lui  x3, 0xfffff" );

  h.asm( 'h00c, "mulh x4,  x1,  x2"   );
  h.asm( 'h010, "mulh x5,  x2,  x3"   );
  h.asm( 'h014, "mulh x6,  x1,  x3"   );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h8000_0000, 1 ); // lui  x1, 0x80000
  h.check_trace( 'h004, 2, 'h7fff_f000, 1 ); // lui  x2, 0x7ffff
  h.check_trace( 'h008, 3, 'hffff_f000, 1 ); // lui  x3, 0xfffff

  h.check_trace( 'h00c, 4, 'hc000_0800, 1 ); // mulh x4,  x1,  x2
  h.check_trace( 'h010, 5, 'hffff_f800, 1 ); // mulh x5,  x2,  x3
  h.check_trace( 'h014, 6, 'h0000_0800, 1 ); // mulh x6,  x1,  x3

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_mulh_tests
//------------------------------------------------------------------------

task run_directed_mulh_tests();
  test_case_directed_mulh_1_basic();
  test_case_directed_mulh_2_x0();
  test_case_directed_mulh_3_upper_bit();
endtask
