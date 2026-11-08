//========================================================================
// lb_test_cases.v
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_lb_1_basic
//------------------------------------------------------------------------

task test_case_directed_lb_1_basic();
  h.t.test_case_begin( "test_case_directed_lb_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 0x100" );
  h.asm( 'h004, "lb   x2, 0(x1)"     );
  h.asm( 'h008, "lb   x3, 1(x1)"     );
  h.asm( 'h00c, "lb   x4, 2(x1)"     );
  h.asm( 'h010, "lb   x5, 3(x1)"     );

  // Write h.data into memory

  h.data( 'h100, 'hdead_beef );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2, 'hffff_ffef, 1 ); // lb   x2, 0(x1)
  h.check_trace( 'h008, 3, 'hffff_ffbe, 1 ); // lb   x3, 1(x1)
  h.check_trace( 'h00c, 4, 'hffff_ffad, 1 ); // lb   x4, 2(x1)
  h.check_trace( 'h010, 5, 'hffff_ffde, 1 ); // lb   x5, 2(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_lb_2_x0
//------------------------------------------------------------------------

task test_case_directed_lb_2_x0();
  h.t.test_case_begin( "test_case_directed_lb_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 0x100" );
  h.asm( 'h004, "lb   x0, 0(x1)"     );
  h.asm( 'h008, "lb   x0, 0(x0)"     );

  // Write h.data into memory

  h.data( 'h100, 'hdead_beef );

  // Check each executed instruction

  h.check_trace( 'h000, 1,  'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 'x, 'x,          0 ); // lb   x0, 0(x1)
  h.check_trace( 'h008, 'x, 'x,          0 ); // lb   x0, 0(x0)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_lb_3_offset_pos
//------------------------------------------------------------------------

task test_case_directed_lb_3_offset_pos();
  h.t.test_case_begin( "test_case_directed_lb_3_offset_pos" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x100" );
  h.asm( 'h004, "lb   x2,  0(x1)"     );
  h.asm( 'h008, "lb   x3,  4(x1)"     );
  h.asm( 'h00c, "lb   x4,  8(x1)"     );
  h.asm( 'h010, "lb   x5,  12(x1)"    );

  // Write h.data into memory

  h.data( 'h100, 'h0000_2000 );
  h.data( 'h104, 'h0000_2004 );
  h.data( 'h108, 'h0000_2008 );
  h.data( 'h10c, 'h0000_200c );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2, 'h0000_0000, 1 ); // lb   x2, 0(x1)
  h.check_trace( 'h008, 3, 'h0000_0004, 1 ); // lb   x3, 4(x1)
  h.check_trace( 'h00c, 4, 'h0000_0008, 1 ); // lb   x4, 8(x1)
  h.check_trace( 'h010, 5, 'h0000_000c, 1 ); // lb   x5, 12(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_lb_4_offset_neg
//------------------------------------------------------------------------

task test_case_directed_lb_4_offset_neg();
  h.t.test_case_begin( "test_case_directed_lb_4_offset_neg" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x10c" );
  h.asm( 'h004, "lb   x2,  0(x1)"     );
  h.asm( 'h008, "lb   x3,  -4(x1)"    );
  h.asm( 'h00c, "lb   x4,  -8(x1)"    );
  h.asm( 'h010, "lb   x5,  -12(x1)"   );

  // Write h.data into memory

  h.data( 'h100, 'h0000_2000 );
  h.data( 'h104, 'h0000_2004 );
  h.data( 'h108, 'h0000_2008 );
  h.data( 'h10c, 'h0000_200c );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_010c, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2, 'h0000_000c, 1 ); // lb   x2, 0(x1)
  h.check_trace( 'h008, 3, 'h0000_0008, 1 ); // lb   x3, -4(x1)
  h.check_trace( 'h00c, 4, 'h0000_0004, 1 ); // lb   x4, -8(x1)
  h.check_trace( 'h010, 5, 'h0000_0000, 1 ); // lb   x5, -12(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_lb_5_sext
//------------------------------------------------------------------------

task test_case_directed_lb_5_sext();
  h.t.test_case_begin( "test_case_directed_lb_5_sext" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x10c" );
  h.asm( 'h004, "lb   x2,  -1(x1)"    );
  h.asm( 'h008, "lb   x3,  -2(x1)"    );
  h.asm( 'h00c, "lb   x4,  -3(x1)"    );
  h.asm( 'h010, "lb   x5,  -4(x1)"    );

  // Write h.data into memory

  h.data( 'h108, 'h0180_0ff0 );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_010c, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2, 'h0000_0001, 1 ); // lb   x2, -1(x1)
  h.check_trace( 'h008, 3, 'hffff_ff80, 1 ); // lb   x3, -2(x1)
  h.check_trace( 'h00c, 4, 'h0000_000f, 1 ); // lb   x4, -3(x1)
  h.check_trace( 'h010, 5, 'hffff_fff0, 1 ); // lb   x5, -4(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_lb_tests
//------------------------------------------------------------------------

task run_directed_lb_tests();
  test_case_directed_lb_1_basic();
  test_case_directed_lb_2_x0();
  test_case_directed_lb_3_offset_pos();
  test_case_directed_lb_4_offset_neg();
  test_case_directed_lb_5_sext();
endtask
