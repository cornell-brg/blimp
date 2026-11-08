//========================================================================
// sb_test_cases.v
//========================================================================

//------------------------------------------------------------------------
// test_case_directed_sb_1_basic
//------------------------------------------------------------------------

task test_case_directed_sb_1_basic();
  h.t.test_case_begin( "test_case_directed_sb_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 0x100" );
  h.asm( 'h004, "addi x2, x0, 0x42"  );
  h.asm( 'h008, "sb   x2, 0(x1)"     );
  h.asm( 'h00c, "lb   x3, 0(x1)"     );

  // Check each executed instruction

  h.check_trace( 'h000, 1,  'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2,  'h0000_0042, 1 ); // addi x2, x0, 0x42
  h.check_trace( 'h008, 'x, 'x,          0 ); // sb   x2, 0(x1)
  h.check_trace( 'h00c, 3,  'h0000_0042, 1 ); // lb   x3, 0(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_sb_2_x0
//------------------------------------------------------------------------

task test_case_directed_sb_2_x0();
  h.t.test_case_begin( "test_case_directed_sb_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 0x100" );
  h.asm( 'h004, "sb   x0, 0(x1)"     );
  h.asm( 'h008, "lb   x2, 0(x1)"     );

  // Write h.data into memory

  h.data( 'h100, 32'hdead_beef );

  // Check each executed instruction

  h.check_trace( 'h000, 1,  'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 'x, 'x,          0 ); // sb   x0, 0(x1)
  h.check_trace( 'h008, 2,  'h0000_0000, 1 ); // lb   x2, 0(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_sb_3_offset_pos
//------------------------------------------------------------------------

task test_case_directed_sb_3_offset_pos();
  h.t.test_case_begin( "test_case_directed_sb_3_offset_pos" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x100" );

  h.asm( 'h004, "addi x2,  x0, 20"    );
  h.asm( 'h008, "addi x3,  x0, 21"    );
  h.asm( 'h00c, "addi x4,  x0, 22"    );
  h.asm( 'h010, "addi x5,  x0, 23"    );

  h.asm( 'h014, "sb   x2,  0(x1)"     );
  h.asm( 'h018, "sb   x3,  4(x1)"     );
  h.asm( 'h01c, "sb   x4,  8(x1)"     );
  h.asm( 'h020, "sb   x5,  12(x1)"    );

  h.asm( 'h024, "lw   x7,  0(x1)"     );
  h.asm( 'h028, "lw   x8,  4(x1)"     );
  h.asm( 'h02c, "lw   x9,  8(x1)"     );
  h.asm( 'h030, "lw   x10, 12(x1)"    );

  // Write h.data into memory

  h.data( 'h100, 'h0000_0000 );
  h.data( 'h104, 'h0000_0000 );
  h.data( 'h108, 'h0000_0000 );
  h.data( 'h10c, 'h0000_0000 );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h100, 1 ); // addi x1,  x0, 0x100

  h.check_trace( 'h004, 2,    20, 1 ); // addi x2,  x0, 20
  h.check_trace( 'h008, 3,    21, 1 ); // addi x3,  x0, 21
  h.check_trace( 'h00c, 4,    22, 1 ); // addi x4,  x0, 22
  h.check_trace( 'h010, 5,    23, 1 ); // addi x5,  x0, 23

  h.check_trace( 'h014, 'x,   'x, 0 ); // sb   x2,  0(x1)
  h.check_trace( 'h018, 'x,   'x, 0 ); // sb   x3,  4(x1)
  h.check_trace( 'h01c, 'x,   'x, 0 ); // sb   x4,  8(x1)
  h.check_trace( 'h020, 'x,   'x, 0 ); // sb   x5,  12(x1)

  h.check_trace( 'h024, 7,    20, 1 ); // lw   x7,  0(x1)
  h.check_trace( 'h028, 8,    21, 1 ); // lw   x8,  4(x1)
  h.check_trace( 'h02c, 9,    22, 1 ); // lw   x9,  8(x1)
  h.check_trace( 'h030, 10,   23, 1 ); // lw   x10, 12(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_sb_4_offset_neg
//------------------------------------------------------------------------

task test_case_directed_sb_4_offset_neg();
  h.t.test_case_begin( "test_case_directed_sb_4_offset_neg" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x10c" );

  h.asm( 'h004, "addi x2,  x0, 20"    );
  h.asm( 'h008, "addi x3,  x0, 21"    );
  h.asm( 'h00c, "addi x4,  x0, 22"    );
  h.asm( 'h010, "addi x5,  x0, 23"    );

  h.asm( 'h014, "sb   x2,  0(x1)"     );
  h.asm( 'h018, "sb   x3,  -4(x1)"     );
  h.asm( 'h01c, "sb   x4,  -8(x1)"     );
  h.asm( 'h020, "sb   x5,  -12(x1)"    );

  h.asm( 'h024, "addi x1,  x0, 0x100" );

  h.asm( 'h028, "lw   x7,  0(x1)"     );
  h.asm( 'h02c, "lw   x8,  4(x1)"     );
  h.asm( 'h030, "lw   x9,  8(x1)"     );
  h.asm( 'h034, "lw   x10, 12(x1)"    );

  // Write h.data into memory

  h.data( 'h100, 'h0000_0000 );
  h.data( 'h104, 'h0000_0000 );
  h.data( 'h108, 'h0000_0000 );
  h.data( 'h10c, 'h0000_0000 );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h10c, 1 ); // addi x1,  x0, 0x10c

  h.check_trace( 'h004, 2,    20, 1 ); // addi x2,  x0, 20
  h.check_trace( 'h008, 3,    21, 1 ); // addi x3,  x0, 21
  h.check_trace( 'h00c, 4,    22, 1 ); // addi x4,  x0, 22
  h.check_trace( 'h010, 5,    23, 1 ); // addi x5,  x0, 23

  h.check_trace( 'h014, 'x,   'x, 0 ); // sb   x2,  0(x1)
  h.check_trace( 'h018, 'x,   'x, 0 ); // sb   x3,  -4(x1)
  h.check_trace( 'h01c, 'x,   'x, 0 ); // sb   x4,  -8(x1)
  h.check_trace( 'h020, 'x,   'x, 0 ); // sb   x5,  -12(x1)

  h.check_trace( 'h024, 1, 'h100, 1 ); // addi x1,  x0, 0x100

  h.check_trace( 'h028, 7,    23, 1 ); // lw   x7,  0(x1)
  h.check_trace( 'h02c, 8,    22, 1 ); // lw   x8,  4(x1)
  h.check_trace( 'h030, 9,    21, 1 ); // lw   x9,  8(x1)
  h.check_trace( 'h034, 10,   20, 1 ); // lw   x10, 12(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_sb_5_partial
//------------------------------------------------------------------------

task test_case_directed_sb_5_partial();
  h.t.test_case_begin( "test_case_directed_sb_5_partial" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 0x100" );
  h.asm( 'h004, "addi x2, x0, 0x12" );
  h.asm( 'h008, "addi x3, x0, 0x34" );
  h.asm( 'h00c, "sb   x2, 0(x1)"     );
  h.asm( 'h010, "sb   x3, 1(x1)"     );
  h.asm( 'h014, "lw   x4, 0(x1)"     );

  // Write h.data into memory

  h.data( 'h100, 32'hdead_beef );

  // Check each executed instruction

  h.check_trace( 'h000, 1,  'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2,  'h0000_0012, 1 ); // addi x2, x0, 0x100
  h.check_trace( 'h008, 3,  'h0000_0034, 1 ); // addi x3, x0, 0x100
  h.check_trace( 'h00c, 'x, 'x,          0 ); // sb   x2, 0(x1)
  h.check_trace( 'h010, 'x, 'x,          0 ); // sb   x3, 0(x1)
  h.check_trace( 'h014, 4,  'hdead_3412, 1 ); // lw   x2, 0(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_sb_tests
//------------------------------------------------------------------------

task run_directed_sb_tests();
  test_case_directed_sb_1_basic();
  test_case_directed_sb_2_x0();
  test_case_directed_sb_3_offset_pos();
  test_case_directed_sb_4_offset_neg();
  test_case_directed_sb_5_partial();
endtask
