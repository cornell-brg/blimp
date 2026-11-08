//========================================================================
// lw_test_cases.v
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_directed_lw_1_basic
//------------------------------------------------------------------------

task test_case_directed_lw_1_basic();
  h.t.test_case_begin( "test_case_directed_lw_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 0x100" );
  h.asm( 'h004, "lw   x2, 0(x1)"     );

  // Write h.data into memory

  h.data( 'h100, 'hdead_beef );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2, 'hdead_beef, 1 ); // lw   x2, 0(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_lw_2_x0
//------------------------------------------------------------------------

task test_case_directed_lw_2_x0();
  h.t.test_case_begin( "test_case_directed_lw_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 0x100" );
  h.asm( 'h004, "lw   x0, 0(x1)"     );
  h.asm( 'h008, "lw   x0, 0(x0)"     );

  // Write h.data into memory

  h.data( 'h100, 'hdead_beef );

  // Check each executed instruction

  h.check_trace( 'h000, 1,  'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 'x, 'x,          0 ); // lw   x0, 0(x1)
  h.check_trace( 'h008, 'x, 'x,          0 ); // lw   x0, 0(x0)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_lw_3_offset_pos
//------------------------------------------------------------------------

task test_case_directed_lw_3_offset_pos();
  h.t.test_case_begin( "test_case_directed_lw_3_offset_pos" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x100" );
  h.asm( 'h004, "lw   x2,  0(x1)"     );
  h.asm( 'h008, "lw   x3,  4(x1)"     );
  h.asm( 'h00c, "lw   x4,  8(x1)"     );
  h.asm( 'h010, "lw   x5,  12(x1)"    );

  // Write h.data into memory

  h.data( 'h100, 'h0000_2000 );
  h.data( 'h104, 'h0000_2004 );
  h.data( 'h108, 'h0000_2008 );
  h.data( 'h10c, 'h0000_200c );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2, 'h0000_2000, 1 ); // lw   x2, 0(x1)
  h.check_trace( 'h008, 3, 'h0000_2004, 1 ); // lw   x3, 4(x1)
  h.check_trace( 'h00c, 4, 'h0000_2008, 1 ); // lw   x4, 8(x1)
  h.check_trace( 'h010, 5, 'h0000_200c, 1 ); // lw   x5, 12(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_lw_4_offset_neg
//------------------------------------------------------------------------

task test_case_directed_lw_4_offset_neg();
  h.t.test_case_begin( "test_case_directed_lw_4_offset_neg" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x10c" );
  h.asm( 'h004, "lw   x2,  0(x1)"     );
  h.asm( 'h008, "lw   x3,  -4(x1)"    );
  h.asm( 'h00c, "lw   x4,  -8(x1)"    );
  h.asm( 'h010, "lw   x5,  -12(x1)"   );

  // Write h.data into memory

  h.data( 'h100, 'h0000_2000 );
  h.data( 'h104, 'h0000_2004 );
  h.data( 'h108, 'h0000_2008 );
  h.data( 'h10c, 'h0000_200c );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_010c, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2, 'h0000_200c, 1 ); // lw   x2, 0(x1)
  h.check_trace( 'h008, 3, 'h0000_2008, 1 ); // lw   x3, -4(x1)
  h.check_trace( 'h00c, 4, 'h0000_2004, 1 ); // lw   x4, -8(x1)
  h.check_trace( 'h010, 5, 'h0000_2000, 1 ); // lw   x5, -12(x1)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_lw_5_chain
//------------------------------------------------------------------------

task test_case_directed_lw_5_chain();
  h.t.test_case_begin( "test_case_directed_lw_5_chain" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 0x100" );
  h.asm( 'h004, "lw   x2, 0(x1)"     );
  h.asm( 'h008, "lw   x3, 0(x2)"     );
  h.asm( 'h00c, "lw   x4, 0(x3)"     );
  h.asm( 'h010, "lw   x5, 0(x4)"     );
  h.asm( 'h014, "lw   x6, 0(x5)"     );
  h.asm( 'h018, "lw   x7, 0(x6)"     );
  h.asm( 'h01c, "lw   x8, 0(x7)"     );
  h.asm( 'h020, "lw   x9, 0(x8)"     );

  // Write h.data into memory

  h.data( 'h100, 'h110 );
  h.data( 'h110, 'h120 );
  h.data( 'h120, 'h130 );
  h.data( 'h130, 'h140 );
  h.data( 'h140, 'h150 );
  h.data( 'h150, 'h160 );
  h.data( 'h160, 'h170 );
  h.data( 'h170, 'h180 );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_0100, 1 ); // addi x1, x0, 0x100
  h.check_trace( 'h004, 2, 'h0000_0110, 1 ); // lw   x2, 0(x1)
  h.check_trace( 'h008, 3, 'h0000_0120, 1 ); // lw   x3, 0(x2)
  h.check_trace( 'h00c, 4, 'h0000_0130, 1 ); // lw   x4, 0(x3)
  h.check_trace( 'h010, 5, 'h0000_0140, 1 ); // lw   x5, 0(x4)
  h.check_trace( 'h014, 6, 'h0000_0150, 1 ); // lw   x6, 0(x5)
  h.check_trace( 'h018, 7, 'h0000_0160, 1 ); // lw   x7, 0(x6)
  h.check_trace( 'h01c, 8, 'h0000_0170, 1 ); // lw   x8, 0(x7)
  h.check_trace( 'h020, 9, 'h0000_0180, 1 ); // lw   x9, 0(x8)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_lw_6_two_chain
//------------------------------------------------------------------------

task test_case_directed_lw_6_two_chain();
  h.t.test_case_begin( "test_case_directed_lw_6_two_chain" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 0x080" );
  h.asm( 'h004, "addi x9, x0, 0x100" );
  h.asm( 'h008, "lw   x2,  0(x1)"    );
  h.asm( 'h00c, "lw   x10, 0(x9)"    );
  h.asm( 'h010, "lw   x3,  0(x2)"    );
  h.asm( 'h014, "lw   x11, 0(x10)"   );
  h.asm( 'h018, "lw   x4,  0(x3)"    );
  h.asm( 'h01c, "lw   x12, 0(x11)"   );
  h.asm( 'h020, "lw   x5,  0(x4)"    );
  h.asm( 'h024, "lw   x13, 0(x12)"   );
  h.asm( 'h028, "lw   x6,  0(x5)"    );
  h.asm( 'h02c, "lw   x14, 0(x13)"   );
  h.asm( 'h030, "lw   x7,  0(x6)"    );
  h.asm( 'h034, "lw   x15, 0(x14)"   );
  h.asm( 'h038, "lw   x8,  0(x7)"    );
  h.asm( 'h03c, "lw   x16, 0(x15)"   );
  h.asm( 'h040, "lw   x9,  0(x8)"    );
  h.asm( 'h044, "lw   x17, 0(x16)"   );

  // Write h.data into memory

  h.data( 'h080, 'h090 );
  h.data( 'h090, 'h0a0 );
  h.data( 'h0a0, 'h0b0 );
  h.data( 'h0b0, 'h0c0 );
  h.data( 'h0c0, 'h0d0 );
  h.data( 'h0d0, 'h0e0 );
  h.data( 'h0e0, 'h0f0 );
  h.data( 'h0f0, 'h100 );

  h.data( 'h100, 'h110 );
  h.data( 'h110, 'h120 );
  h.data( 'h120, 'h130 );
  h.data( 'h130, 'h140 );
  h.data( 'h140, 'h150 );
  h.data( 'h150, 'h160 );
  h.data( 'h160, 'h170 );
  h.data( 'h170, 'h180 );

  // Check each executed instruction

  h.check_trace( 'h000, 1,  'h0000_0080, 1 ); // addi x1, x0, 0x080
  h.check_trace( 'h004, 9,  'h0000_0100, 1 ); // addi x9, x0, 0x100
  h.check_trace( 'h008, 2,  'h0000_0090, 1 ); // lw   x2,  0(x1)
  h.check_trace( 'h00c, 10, 'h0000_0110, 1 ); // lw   x10, 0(x9)
  h.check_trace( 'h010, 3,  'h0000_00a0, 1 ); // lw   x3,  0(x2)
  h.check_trace( 'h014, 11, 'h0000_0120, 1 ); // lw   x11, 0(x10)
  h.check_trace( 'h018, 4,  'h0000_00b0, 1 ); // lw   x4,  0(x3)
  h.check_trace( 'h01c, 12, 'h0000_0130, 1 ); // lw   x12, 0(x11)
  h.check_trace( 'h020, 5,  'h0000_00c0, 1 ); // lw   x5,  0(x4)
  h.check_trace( 'h024, 13, 'h0000_0140, 1 ); // lw   x13, 0(x12)
  h.check_trace( 'h028, 6,  'h0000_00d0, 1 ); // lw   x6,  0(x5)
  h.check_trace( 'h02c, 14, 'h0000_0150, 1 ); // lw   x14, 0(x13)
  h.check_trace( 'h030, 7,  'h0000_00e0, 1 ); // lw   x7,  0(x6)
  h.check_trace( 'h034, 15, 'h0000_0160, 1 ); // lw   x15, 0(x14)
  h.check_trace( 'h038, 8,  'h0000_00f0, 1 ); // lw   x8,  0(x7)
  h.check_trace( 'h03c, 16, 'h0000_0170, 1 ); // lw   x16, 0(x15)
  h.check_trace( 'h040, 9,  'h0000_0100, 1 ); // lw   x9,  0(x8)
  h.check_trace( 'h044, 17, 'h0000_0180, 1 ); // lw   x17, 0(x16)

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_lw_tests
//------------------------------------------------------------------------

task run_directed_lw_tests();
  test_case_directed_lw_1_basic();
  test_case_directed_lw_2_x0();
  test_case_directed_lw_3_offset_pos();
  test_case_directed_lw_4_offset_neg();
  test_case_directed_lw_5_chain();
  test_case_directed_lw_6_two_chain();
endtask
