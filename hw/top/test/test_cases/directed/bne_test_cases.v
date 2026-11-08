//========================================================================
// bne_test_cases.v
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_directed_bne_1_basic
//------------------------------------------------------------------------

task test_case_directed_bne_1_basic();
  h.t.test_case_begin( "test_case_directed_bne_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 1"     );
  h.asm( 'h004, "bne  x1, x0, 0x00c" );
  h.asm( 'h008, "addi x1, x0, 2"     );
  h.asm( 'h00c, "addi x1, x0, 3"     );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h0000_0001, 1 ); // addi x1, x0, 1
  h.check_trace( 'h004, 'x, 'x,          0 ); // bne  x1, x0, 0x00c
  h.check_trace( 'h00c,  1, 'h0000_0003, 1 ); // addi x1, x0, 3

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_bne_2_taken
//------------------------------------------------------------------------

task test_case_directed_bne_2_taken();
  h.t.test_case_begin( "test_case_directed_bne_2_taken" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 1"     );
  h.asm( 'h004, "addi x2,  x0, 2"     );
  h.asm( 'h008, "bne  x1,  x2, 0x010" );
  h.asm( 'h00c, "addi x3,  x0, 3"     );
  h.asm( 'h010, "addi x4,  x0, 4"     );

  h.asm( 'h014, "addi x5,  x0, 100"   );
  h.asm( 'h018, "addi x6,  x0, 200"   );
  h.asm( 'h01c, "bne  x5,  x6, 0x024" );
  h.asm( 'h020, "addi x7,  x0, 5"     );
  h.asm( 'h024, "addi x8,  x0, 6"     );

  h.asm( 'h028, "addi x9,  x0, -13"   );
  h.asm( 'h02c, "addi x10, x0, 42"    );
  h.asm( 'h030, "bne  x9, x10, 0x038" );
  h.asm( 'h034, "addi x11, x0, 7"     );
  h.asm( 'h038, "addi x12, x0, 8"     );

  // Check each executed instruction

  h.check_trace( 'h000,  1,  1, 1 ); // addi x1,  x0, 1
  h.check_trace( 'h004,  2,  2, 1 ); // addi x2,  x0, 2
  h.check_trace( 'h008, 'x, 'x, 0 ); // bne  x1,  x2, 0x010
  h.check_trace( 'h010,  4,  4, 1 ); // addi x4,  x0, 4

  h.check_trace( 'h014,  5, 100, 1 ); // addi x5,  x0, 100
  h.check_trace( 'h018,  6, 200, 1 ); // addi x6,  x0, 200
  h.check_trace( 'h01c, 'x,  'x, 0 ); // bne  x5,  x6, 0x024
  h.check_trace( 'h024,  8,   6, 1 ); // addi x8,  x0, 6

  h.check_trace( 'h028,  9, -13, 1 ); // addi x9,  x0, -13
  h.check_trace( 'h02c, 10,  42, 1 ); // addi x10, x0, 42
  h.check_trace( 'h030, 'x,  'x, 0 ); // bne  x9, x10, 0x038
  h.check_trace( 'h038, 12,   8, 1 ); // addi x12, x0, 8

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_bne_3_not_taken
//------------------------------------------------------------------------

task test_case_directed_bne_3_not_taken();
  h.t.test_case_begin( "test_case_directed_bne_3_not_taken" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 1"     );
  h.asm( 'h004, "addi x2,  x0, 1"     );
  h.asm( 'h008, "bne  x1,  x2, 0x010" );
  h.asm( 'h00c, "addi x3,  x0, 3"     );
  h.asm( 'h010, "addi x4,  x0, 4"     );

  h.asm( 'h014, "addi x5,  x0, 100"   );
  h.asm( 'h018, "addi x6,  x0, 100"   );
  h.asm( 'h01c, "bne  x5,  x6, 0x024" );
  h.asm( 'h020, "addi x7,  x0, 5"     );
  h.asm( 'h024, "addi x8,  x0, 6"     );

  h.asm( 'h028, "addi x9,  x0, -13"   );
  h.asm( 'h02c, "addi x10, x0, -13"   );
  h.asm( 'h030, "bne  x9, x10, 0x038" );
  h.asm( 'h034, "addi x11, x0, 7"     );
  h.asm( 'h038, "addi x12, x0, 8"     );

  // Check each executed instruction

  h.check_trace( 'h000,  1,  1, 1 ); // addi x1,  x0, 1
  h.check_trace( 'h004,  2,  1, 1 ); // addi x2,  x0, 1
  h.check_trace( 'h008, 'x, 'x, 0 ); // bne  x1,  x2, 0x010
  h.check_trace( 'h00c,  3,  3, 1 ); // addi x3,  x0, 3
  h.check_trace( 'h010,  4,  4, 1 ); // addi x4,  x0, 4

  h.check_trace( 'h014,  5, 100, 1 ); // addi x5,  x0, 100
  h.check_trace( 'h018,  6, 100, 1 ); // addi x6,  x0, 100
  h.check_trace( 'h01c, 'x,  'x, 0 ); // bne  x5,  x6, 0x024
  h.check_trace( 'h020,  7,   5, 1 ); // addi x7,  x0, 5
  h.check_trace( 'h024,  8,   6, 1 ); // addi x8,  x0, 6

  h.check_trace( 'h028,  9, -13, 1 ); // addi x9,  x0, -13
  h.check_trace( 'h02c, 10, -13, 1 ); // addi x10, x0, -13
  h.check_trace( 'h030, 'x,  'x, 0 ); // bne  x9, x10, 0x038
  h.check_trace( 'h034, 11,   7, 1 ); // addi x11, x0, 7
  h.check_trace( 'h038, 12,   8, 1 ); // addi x12, x0, 8

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_bne_4_chain
//------------------------------------------------------------------------

task test_case_directed_bne_4_chain();
  h.t.test_case_begin( "test_case_directed_bne_4_chain" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 1"     );
  h.asm( 'h004, "addi x2,  x0, 2"     );
  h.asm( 'h008, "addi x3,  x0, 100"   );
  h.asm( 'h00c, "addi x4,  x0, 200"   );
  h.asm( 'h010, "addi x5,  x0, -13"   );
  h.asm( 'h014, "addi x6,  x0, 42"    );

  h.asm( 'h018, "bne  x1,  x2, 0x020" );
  h.asm( 'h01c, "addi x7,  x0, 2"     );
  h.asm( 'h020, "bne  x3,  x4, 0x028" );
  h.asm( 'h024, "addi x8,  x0, 3"     );
  h.asm( 'h028, "bne  x5,  x6, 0x030" );
  h.asm( 'h02c, "addi x9,  x0, 4"     );
  h.asm( 'h030, "addi x10, x0, 5"     );

  // Check each executed instruction

  h.check_trace( 'h000,  1,   1, 1 ); // addi x1,  x0, 1
  h.check_trace( 'h004,  2,   2, 1 ); // addi x2,  x0, 2
  h.check_trace( 'h008,  3, 100, 1 ); // addi x3,  x0, 100
  h.check_trace( 'h00c,  4, 200, 1 ); // addi x4,  x0, 200
  h.check_trace( 'h010,  5, -13, 1 ); // addi x5,  x0, -13
  h.check_trace( 'h014,  6,  42, 1 ); // addi x6,  x0, 42

  h.check_trace( 'h018, 'x, 'x, 0 ); // bne  x1,  x2, 0x020
  h.check_trace( 'h020, 'x, 'x, 0 ); // bne  x3,  x4, 0x028
  h.check_trace( 'h028, 'x, 'x, 0 ); // bne  x5,  x6, 0x030
  h.check_trace( 'h030, 10,  5, 1 ); // addi x10, x0, 5

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_bne_5_backward
//------------------------------------------------------------------------

task test_case_directed_bne_5_backward();
  h.t.test_case_begin( "test_case_directed_bne_5_backward" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 1"     );
  h.asm( 'h004, "addi x8,  x0, 2"     );
  h.asm( 'h008, "addi x12, x0, 3"     );
  h.asm( 'h00c, "addi x15, x0, 4"     );

  h.asm( 'h010, "bne  x1,  x0, 0x044" ); // --------.
  h.asm( 'h014, "addi x2,  x0, 1"     ); // <-.     |
  h.asm( 'h018, "addi x3,  x0, 2"     ); //   |     |
  h.asm( 'h01c, "addi x4,  x0, 3"     ); //   |     |
  h.asm( 'h020, "addi x5,  x0, 4"     ); //   |     |
  h.asm( 'h024, "addi x6,  x0, 5"     ); //   |     |
  h.asm( 'h028, "addi x7,  x0, 6"     ); // <-+--.  |
  h.asm( 'h02c, "bne  x8,  x0, 0x014" ); // --'  |  |
  h.asm( 'h030, "addi x9,  x0, 7"     ); //      |  |
  h.asm( 'h034, "addi x10, x0, 8"     ); //      |  |
  h.asm( 'h038, "addi x11, x0, 9"     ); // <-.  |  |
  h.asm( 'h03c, "bne  x12, x0, 0x028" ); // --+--'  |
  h.asm( 'h040, "addi x13, x0, 10"    ); //   |     |
  h.asm( 'h044, "addi x14, x0, 11"    ); // <-+-----'
  h.asm( 'h048, "bne  x15, x0, 0x038" ); // --'

  // Check each executed instruction

  h.check_trace( 'h000,  1, 1, 1 ); // addi x1,  x0, 1
  h.check_trace( 'h004,  8, 2, 1 ); // addi x8,  x0, 2
  h.check_trace( 'h008, 12, 3, 1 ); // addi x12, x0, 3
  h.check_trace( 'h00c, 15, 4, 1 ); // addi x15, x0, 4

  h.check_trace( 'h010, 'x, 'x, 0 ); // bne  x1,  x0, 0x044
  h.check_trace( 'h044, 14, 11, 1 ); // addi x14, x0, 11
  h.check_trace( 'h048, 'x, 'x, 0 ); // bne  x15, x0, 0x038
  h.check_trace( 'h038, 11,  9, 1 ); // addi x11, x0, 9
  h.check_trace( 'h03c, 'x, 'x, 0 ); // bne  x12, x0, 0x028
  h.check_trace( 'h028,  7,  6, 1 ); // addi x7,  x0, 6
  h.check_trace( 'h02c, 'x, 'x, 0 ); // bne  x8,  x0, 0x014
  h.check_trace( 'h014,  2,  1, 1 ); // addi x2,  x0, 1
  h.check_trace( 'h018,  3,  2, 1 ); // addi x3,  x0, 2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_bne_6_loop
//------------------------------------------------------------------------

task test_case_directed_bne_6_loop();
  h.t.test_case_begin( "test_case_directed_bne_6_loop" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 4"     ); //
  h.asm( 'h004, "addi x1, x1, -1"    ); // <-.
  h.asm( 'h008, "addi x1, x1, -1"    ); //   |
  h.asm( 'h00c, "bne  x1, x0, 0x004" ); // --'
  h.asm( 'h010, "addi x2, x0, 1"     ); //
  h.asm( 'h014, "addi x3, x0, 2"     ); //

  // Check each executed instruction

  h.check_trace( 'h000,  1,  4, 1 ); // addi x1, x0, 4
  h.check_trace( 'h004,  1,  3, 1 ); // addi x1, x1, -1
  h.check_trace( 'h008,  1,  2, 1 ); // addi x1, x1, -1
  h.check_trace( 'h00c, 'x, 'x, 0 ); // bne  x1, x0, 0x004
  h.check_trace( 'h004,  1,  1, 1 ); // addi x1, x1, -1
  h.check_trace( 'h008,  1,  0, 1 ); // addi x1, x1, -1
  h.check_trace( 'h00c, 'x, 'x, 0 ); // bne  x1, x0, 0x004
  h.check_trace( 'h010,  2,  1, 1 ); // addi x2, x0, 1
  h.check_trace( 'h014,  3,  2, 1 ); // addi x3, x0, 2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_bne_7_loop_self
//------------------------------------------------------------------------

task test_case_directed_bne_7_loop_self();
  h.t.test_case_begin( "test_case_directed_bne_7_loop_self" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 1"     );
  h.asm( 'h004, "bne  x1, x0, 0x004" );

  // Check each executed instruction

  h.check_trace( 'h000,  1,  1, 1 ); // addi x1, x0, 1
  h.check_trace( 'h004, 'x, 'x, 0 ); // bne  x1, x0, 0x004
  h.check_trace( 'h004, 'x, 'x, 0 ); // bne  x1, x0, 0x004
  h.check_trace( 'h004, 'x, 'x, 0 ); // bne  x1, x0, 0x004
  h.check_trace( 'h004, 'x, 'x, 0 ); // bne  x1, x0, 0x004

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_bne_tests
//------------------------------------------------------------------------

task run_directed_bne_tests();
  test_case_directed_bne_1_basic();
  test_case_directed_bne_2_taken();
  test_case_directed_bne_3_not_taken();
  test_case_directed_bne_4_chain();
  test_case_directed_bne_5_backward();
  test_case_directed_bne_6_loop();
  test_case_directed_bne_7_loop_self();
endtask
