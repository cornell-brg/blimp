//========================================================================
// jal_test_cases.v
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_directed_jal_1_basic
//------------------------------------------------------------------------

task test_case_directed_jal_1_basic();
  h.t.test_case_begin( "test_case_directed_jal_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1, x0, 1" );
  h.asm( 'h004, "jal  x2, 0x00c" );
  h.asm( 'h008, "addi x1, x0, 2" );
  h.asm( 'h00c, "addi x1, x0, 3" );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h0000_0001, 1 ); // addi x1, x0, 1
  h.check_trace( 'h004,  2, 'h0000_0008, 1 ); // jal  x2, 0x00c
  h.check_trace( 'h00c,  1, 'h0000_0003, 1 ); // addi x1, x0, 3

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_jal_2_x0
//------------------------------------------------------------------------

task test_case_directed_jal_2_x0();
  h.t.test_case_begin( "test_case_directed_jal_2_x0" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "jal  x0, 0x008"   );
  h.asm( 'h004, "addi x1, x0, 1"   );
  h.asm( 'h008, "addi x2, x0, 2"   );

  // Check each executed instruction

  h.check_trace( 'h000, 'x,          'x, 0 ); // jal  x0, 0x008
  h.check_trace( 'h008,  2, 'h0000_0002, 1 ); // addi x2, x0, 2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_jal_3_chain
//------------------------------------------------------------------------

task test_case_directed_jal_3_chain();
  h.t.test_case_begin( "test_case_directed_jal_3_chain" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "jal  x1, 0x008" );
  h.asm( 'h004, "addi x2, x0, 1" );
  h.asm( 'h008, "jal  x3, 0x010" );
  h.asm( 'h00c, "addi x4, x0, 2" );
  h.asm( 'h010, "jal  x5, 0x018" );
  h.asm( 'h014, "addi x6, x0, 3" );
  h.asm( 'h018, "addi x7, x0, 4" );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h004, 1 ); // jal  x1, 0x008
  h.check_trace( 'h008,  3, 'h00c, 1 ); // jal  x3, 0x010
  h.check_trace( 'h010,  5, 'h014, 1 ); // jal  x5, 0x018
  h.check_trace( 'h018,  7,     4, 1 ); // addi x7, x0, 4

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_jal_4_forward
//------------------------------------------------------------------------

task test_case_directed_jal_4_forward();
  h.t.test_case_begin( "test_case_directed_jal_4_forward" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "jal  x1,  0x008"  );
  h.asm( 'h004, "addi x2,  x0,  1" );
  h.asm( 'h008, "addi x3,  x0,  2" );

  h.asm( 'h00c, "jal  x4,  0x018"  );
  h.asm( 'h010, "addi x5,  x0,  3" );
  h.asm( 'h014, "addi x6,  x0,  4" );
  h.asm( 'h018, "addi x7,  x0,  5" );

  h.asm( 'h01c, "jal  x8,  0x02c" );
  h.asm( 'h020, "addi x9,  x0,  6" );
  h.asm( 'h024, "addi x10, x0,  7" );
  h.asm( 'h028, "addi x11, x0,  8" );
  h.asm( 'h02c, "addi x12, x0,  9" );

  h.asm( 'h030, "jal  x13, 0x044"  );
  h.asm( 'h034, "addi x14, x0, 10" );
  h.asm( 'h038, "addi x15, x0, 11" );
  h.asm( 'h03c, "addi x16, x0, 12" );
  h.asm( 'h040, "addi x17, x0, 13" );
  h.asm( 'h044, "addi x18, x0, 14" );

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h004, 1 ); // jal  x1,  0x008
  h.check_trace( 'h008,  3,     2, 1 ); // addi x3,  x0,  2

  h.check_trace( 'h00c,  4, 'h010, 1 ); // jal  x4,  0x018
  h.check_trace( 'h018,  7,     5, 1 ); // addi x7,  x0,  5

  h.check_trace( 'h01c,  8, 'h020, 1 ); // jal  x8,  0x02c
  h.check_trace( 'h02c, 12,     9, 1 ); // addi x12, x0,  9

  h.check_trace( 'h030, 13, 'h034, 1 ); // jal  x13, 0x044
  h.check_trace( 'h044, 18,    14, 1 ); // addi x18, x0, 14

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_jal_5_backward
//------------------------------------------------------------------------

task test_case_directed_jal_5_backward();
  h.t.test_case_begin( "test_case_directed_jal_5_backward" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "jal  x1,  0x034"  ); // --------.
  h.asm( 'h004, "addi x2,  x0, 1"  ); // <-.     |
  h.asm( 'h008, "addi x3,  x0, 2"  ); //   |     |
  h.asm( 'h00c, "addi x4,  x0, 3"  ); //   |     |
  h.asm( 'h010, "addi x5,  x0, 4"  ); //   |     |
  h.asm( 'h014, "addi x6,  x0, 5"  ); //   |     |
  h.asm( 'h018, "addi x7,  x0, 6"  ); // <-+--.  |
  h.asm( 'h01c, "jal  x8,  0x004"  ); // --'  |  |
  h.asm( 'h020, "addi x9,  x0, 7"  ); //      |  |
  h.asm( 'h024, "addi x10, x0, 8"  ); //      |  |
  h.asm( 'h028, "addi x11, x0, 9"  ); // <-.  |  |
  h.asm( 'h02c, "jal  x12, 0x018"  ); // --+--'  |
  h.asm( 'h030, "addi x13, x0, 10" ); //   |     |
  h.asm( 'h034, "addi x14, x0, 11" ); // <-+-----'
  h.asm( 'h038, "jal  x15, 0x028"  ); // --'

  // Check each executed instruction

  h.check_trace( 'h000,  1, 'h004, 1 ); // jal  x1,  0x038
  h.check_trace( 'h034, 14,    11, 1 ); // addi x14, x0, 11
  h.check_trace( 'h038, 15, 'h03c, 1 ); // jal  x15, 0x028
  h.check_trace( 'h028, 11,     9, 1 ); // addi x11, x0, 9
  h.check_trace( 'h02c, 12, 'h030, 1 ); // jal  x12, 0x018
  h.check_trace( 'h018,  7,     6, 1 ); // addi x7,  x0, 6
  h.check_trace( 'h01c,  8, 'h020, 1 ); // jal  x8,  0x004
  h.check_trace( 'h004,  2,     1, 1 ); // addi x2,  x0, 1
  h.check_trace( 'h008,  3,     2, 1 ); // addi x3,  x0, 2

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_jal_6_loop
//------------------------------------------------------------------------

task test_case_directed_jal_6_loop();
  h.t.test_case_begin( "test_case_directed_jal_6_loop" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 1"  ); // <-.
  h.asm( 'h004, "addi x2,  x0, 2"  ); //   |
  h.asm( 'h008, "addi x3,  x0, 3"  ); //   |
  h.asm( 'h00c, "jal  x4,  0x000"  ); // --'

  // Check each executed instruction

  h.check_trace( 'h000,  1,     1, 1 ); // addi x1,  x0, 1
  h.check_trace( 'h004,  2,     2, 1 ); // addi x2,  x0, 2
  h.check_trace( 'h008,  3,     3, 1 ); // addi x3,  x0, 3
  h.check_trace( 'h00c,  4, 'h010, 1 ); // jal  x4,  0x000
  h.check_trace( 'h000,  1,     1, 1 ); // addi x1,  x0, 1
  h.check_trace( 'h004,  2,     2, 1 ); // addi x2,  x0, 2
  h.check_trace( 'h008,  3,     3, 1 ); // addi x3,  x0, 3
  h.check_trace( 'h00c,  4, 'h010, 1 ); // jal  x4,  0x000
  h.check_trace( 'h000,  1,     1, 1 ); // addi x1,  x0, 1
  h.check_trace( 'h004,  2,     2, 1 ); // addi x2,  x0, 2
  h.check_trace( 'h008,  3,     3, 1 ); // addi x3,  x0, 3
  h.check_trace( 'h00c,  4, 'h010, 1 ); // jal  x4,  0x000

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_jal_7_loop_self
//------------------------------------------------------------------------

task test_case_directed_jal_7_loop_self();
  h.t.test_case_begin( "test_case_directed_jal_7_loop_self" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x0, x0, 0" );
  h.asm( 'h004, "addi x0, x0, 0" );
  h.asm( 'h008, "jal  x1, 0x008" );

  // Check each executed instruction

  h.check_trace( 'h000, 'x,    'x, 0 ); // addi x0, x0, 0
  h.check_trace( 'h004, 'x,    'x, 0 ); // addi x0, x0, 0
  h.check_trace( 'h008,  1, 'h00c, 1 ); // jal x1, 0x008
  h.check_trace( 'h008,  1, 'h00c, 1 ); // jal x1, 0x008
  h.check_trace( 'h008,  1, 'h00c, 1 ); // jal x1, 0x008
  h.check_trace( 'h008,  1, 'h00c, 1 ); // jal x1, 0x008

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_jal_8_mix
//------------------------------------------------------------------------

task test_case_directed_jal_8_mix();
  h.t.test_case_begin( "test_case_directed_jal_8_mix" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "addi x1,  x0, 0x100" );
  h.asm( 'h004, "addi x2,  x0, 0x110" );
  h.asm( 'h008, "addi x3,  x0, 0x120" );
  h.asm( 'h00c, "addi x4,  x0, 0"     );

  h.asm( 'h010, "lw   x5,  0(x1)"     );
  h.asm( 'h014, "lw   x6,  0(x2)"     );
  h.asm( 'h018, "mul  x7,  x5, x6"    );
  h.asm( 'h01c, "add  x4,  x4, x7"    );
  h.asm( 'h020, "sw   x4,  0(x3)"     );
  h.asm( 'h024, "addi x1,  x1, 4"     );
  h.asm( 'h028, "addi x2,  x2, 4"     );
  h.asm( 'h02c, "addi x3,  x3, 4"     );
  h.asm( 'h030, "jal  x0,  0x010"     );

  // Write h.data into memory

  h.data( 'h100, 1 );
  h.data( 'h104, 2 );
  h.data( 'h108, 3 );

  h.data( 'h110, 5 );
  h.data( 'h114, 6 );
  h.data( 'h118, 7 );

  h.data( 'h120, 0 );
  h.data( 'h124, 0 );
  h.data( 'h128, 0 );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h100, 1 ); // addi x1,  x0, 0x100
  h.check_trace( 'h004, 2, 'h110, 1 ); // addi x2,  x0, 0x110
  h.check_trace( 'h008, 3, 'h120, 1 ); // addi x3,  x0, 0x120
  h.check_trace( 'h00c, 4,     0, 1 ); // addi x4,  x0, 0

  h.check_trace( 'h010,  5,     1, 1 ); // lw   x5,  0(x1)
  h.check_trace( 'h014,  6,     5, 1 ); // lw   x6,  0(x2)
  h.check_trace( 'h018,  7,     5, 1 ); // mul  x7,  x5, x6
  h.check_trace( 'h01c,  4,     5, 1 ); // add  x4,  x4, x7
  h.check_trace( 'h020, 'x,    'x, 0 ); // sw   x4,  0(x3)
  h.check_trace( 'h024,  1, 'h104, 1 ); // addi x1,  x1, 4
  h.check_trace( 'h028,  2, 'h114, 1 ); // addi x2,  x2, 4
  h.check_trace( 'h02c,  3, 'h124, 1 ); // addi x3,  x3, 4
  h.check_trace( 'h030, 'x,    'x, 0 ); // jal  x0,  0x010
  
  h.check_trace( 'h010,  5,     2, 1 ); // lw   x5,  0(x1)
  h.check_trace( 'h014,  6,     6, 1 ); // lw   x6,  0(x2)
  h.check_trace( 'h018,  7,    12, 1 ); // mul  x7,  x5, x6
  h.check_trace( 'h01c,  4,    17, 1 ); // add  x4,  x4, x7
  h.check_trace( 'h020, 'x,    'x, 0 ); // sw   x4,  0(x3)
  h.check_trace( 'h024,  1, 'h108, 1 ); // addi x1,  x1, 4
  h.check_trace( 'h028,  2, 'h118, 1 ); // addi x2,  x2, 4
  h.check_trace( 'h02c,  3, 'h128, 1 ); // addi x3,  x3, 4
  h.check_trace( 'h030, 'x,    'x, 0 ); // jal  x0,  0x010

  h.check_trace( 'h010,  5,     3, 1 ); // lw   x5,  0(x1)
  h.check_trace( 'h014,  6,     7, 1 ); // lw   x6,  0(x2)
  h.check_trace( 'h018,  7,    21, 1 ); // mul  x7,  x5, x6
  h.check_trace( 'h01c,  4,    38, 1 ); // add  x4,  x4, x7
  h.check_trace( 'h020, 'x,    'x, 0 ); // sw   x4,  0(x3)
  h.check_trace( 'h024,  1, 'h10c, 1 ); // addi x1,  x1, 4
  h.check_trace( 'h028,  2, 'h11c, 1 ); // addi x2,  x2, 4
  h.check_trace( 'h02c,  3, 'h12c, 1 ); // addi x3,  x3, 4
  h.check_trace( 'h030, 'x,    'x, 0 ); // jal  x0,  0x010

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_jal_tests
//------------------------------------------------------------------------

task run_directed_jal_tests();
  test_case_directed_jal_1_basic();
  test_case_directed_jal_2_x0();
  test_case_directed_jal_3_chain();
  test_case_directed_jal_4_forward();
  test_case_directed_jal_5_backward();
  test_case_directed_jal_6_loop();
  test_case_directed_jal_7_loop_self();
  test_case_directed_jal_8_mix();
endtask
