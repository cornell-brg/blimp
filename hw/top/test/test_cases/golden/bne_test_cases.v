//========================================================================
// bne_test_cases.v
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_golden_bne_1_mix
//------------------------------------------------------------------------

task test_case_golden_bne_1_mix();
  h.t.test_case_begin( "test_case_golden_bne_1_mix" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1, x0, 0x100" );
  h.asm( 'h204, "addi x2, x0, 0x110" );
  h.asm( 'h208, "addi x3, x0, 0x120" );
  h.asm( 'h20c, "addi x4, x0, 0"     );
  h.asm( 'h210, "addi x5, x0, 3"     );

  h.asm( 'h214, "lw   x6, 0(x1)"     );
  h.asm( 'h218, "lw   x7, 0(x2)"     );
  h.asm( 'h21c, "mul  x8, x6, x7"    );
  h.asm( 'h220, "add  x4, x4, x8"    );
  h.asm( 'h224, "sw   x4, 0(x3)"     );
  h.asm( 'h228, "addi x1, x1, 4"     );
  h.asm( 'h22c, "addi x2, x2, 4"     );
  h.asm( 'h230, "addi x3, x3, 4"     );
  h.asm( 'h234, "addi x5, x5, -1"    );
  h.asm( 'h238, "bne  x5, x0, 0x014" );

  h.asm( 'h23c, "addi x1, x0, 0x120" );
  h.asm( 'h240, "lw   x2, 0(x1)"     );
  h.asm( 'h244, "lw   x3, 4(x1)"     );
  h.asm( 'h248, "lw   x4, 8(x1)"     );

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

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_bne_before_jump
//------------------------------------------------------------------------

task test_case_golden_bne_before_jump();
  h.t.test_case_begin( "test_case_golden_bne_before_jump" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1, x0, 1"     );
  h.asm( 'h204, "bne  x1, x0, 0x214" );
  h.asm( 'h208, "jal  x0, 0x210"     );
  h.asm( 'h20c, "addi x2, x0, 2"     );
  h.asm( 'h210, "addi x3, x0, 3"     );

  h.asm( 'h214, "bne  x0, x0, 0x21c" );
  h.asm( 'h218, "jal  x0, 0x220"     );
  h.asm( 'h21c, "addi x4, x0, 4"     );
  h.asm( 'h220, "addi x5, x0, 5"     );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_bne_jal_same_window
//------------------------------------------------------------------------

task test_case_golden_bne_jal_same_window();
  h.t.test_case_begin( "test_case_golden_bne_jal_same_window" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  // Setup
  h.asm( 'h200, "addi x1, x0, 1"     );
  h.asm( 'h204, "addi x2, x0, 2"     );
  h.asm( 'h208, "addi x3, x0, 3"     );
  h.asm( 'h20c, "addi x4, x0, 4"     );

  // JAL before BNE in same window: jal takes, bne squashed
  h.asm( 'h210, "jal  x10, 0x220"    );
  h.asm( 'h214, "bne  x1, x0, 0x240" );
  h.asm( 'h218, "addi x5, x0, 99"    );
  h.asm( 'h21c, "addi x6, x0, 99"    );

  h.asm( 'h220, "addi x7, x0, 7"     );
  h.asm( 'h224, "addi x8, x0, 8"     );
  h.asm( 'h228, "addi x9, x0, 9"     );
  h.asm( 'h22c, "addi x11, x0, 11"   );

  // BNE (taken) before JAL in same window: bne takes, jal squashed
  h.asm( 'h230, "bne  x1, x0, 0x240" );
  h.asm( 'h234, "jal  x0, 0x260"     );
  h.asm( 'h238, "addi x12, x0, 99"   );
  h.asm( 'h23c, "addi x13, x0, 99"   );

  h.asm( 'h240, "addi x14, x0, 14"   );
  h.asm( 'h244, "addi x15, x0, 15"   );
  h.asm( 'h248, "addi x16, x0, 16"   );
  h.asm( 'h24c, "addi x17, x0, 17"   );

  // BNE (not taken) before JAL in same window: bne falls through, jal executes
  h.asm( 'h250, "bne  x0, x0, 0x280" );
  h.asm( 'h254, "jal  x0, 0x260"     );
  h.asm( 'h258, "addi x18, x0, 99"   );
  h.asm( 'h25c, "addi x19, x0, 99"   );

  h.asm( 'h260, "addi x20, x0, 20"   );
  h.asm( 'h264, "addi x21, x0, 21"   );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_bne_multi_branch
//------------------------------------------------------------------------

task test_case_golden_bne_multi_branch();
  h.t.test_case_begin( "test_case_golden_bne_multi_branch" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  // Setup
  h.asm( 'h200, "addi x1, x0, 1"     );
  h.asm( 'h204, "addi x2, x0, 2"     );
  h.asm( 'h208, "addi x3, x0, 3"     );
  h.asm( 'h20c, "addi x4, x0, 4"     );

  // Two branches, first taken, second squashed
  h.asm( 'h210, "bne  x1, x0, 0x220" );
  h.asm( 'h214, "bne  x2, x0, 0x240" );
  h.asm( 'h218, "addi x5, x0, 99"    );
  h.asm( 'h21c, "addi x6, x0, 99"    );

  h.asm( 'h220, "addi x7, x0, 7"     );
  h.asm( 'h224, "addi x8, x0, 8"     );
  h.asm( 'h228, "addi x9, x0, 9"     );
  h.asm( 'h22c, "addi x10, x0, 10"   );

  // Two branches, first not taken, second taken
  h.asm( 'h230, "bne  x0, x0, 0x260" );
  h.asm( 'h234, "bne  x1, x0, 0x240" );
  h.asm( 'h238, "addi x11, x0, 99"   );
  h.asm( 'h23c, "addi x12, x0, 99"   );

  h.asm( 'h240, "addi x13, x0, 13"   );
  h.asm( 'h244, "addi x14, x0, 14"   );
  h.asm( 'h248, "addi x15, x0, 15"   );
  h.asm( 'h24c, "addi x16, x0, 16"   );

  // Two branches, neither taken, fall through
  h.asm( 'h250, "bne  x0, x0, 0x280" );
  h.asm( 'h254, "bne  x0, x0, 0x290" );
  h.asm( 'h258, "addi x17, x0, 17"   );
  h.asm( 'h25c, "addi x18, x0, 18"   );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_bne_jal_chain
//------------------------------------------------------------------------

task test_case_golden_bne_jal_chain();
  h.t.test_case_begin( "test_case_golden_bne_jal_chain" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1, x0, 1"     );

  // Chain of jals, each skipping one instruction
  h.asm( 'h204, "jal  x2, 0x20c"     );
  h.asm( 'h208, "addi x3, x0, 99"    ); // squashed
  h.asm( 'h20c, "jal  x4, 0x214"     );
  h.asm( 'h210, "addi x5, x0, 99"    ); // squashed
  h.asm( 'h214, "jal  x6, 0x21c"     );
  h.asm( 'h218, "addi x7, x0, 99"    ); // squashed
  h.asm( 'h21c, "jal  x8, 0x224"     );
  h.asm( 'h220, "addi x9, x0, 99"    ); // squashed

  // Chain of taken bnes, each skipping one instruction
  h.asm( 'h224, "bne  x1, x0, 0x22c" );
  h.asm( 'h228, "addi x10, x0, 99"   ); // squashed
  h.asm( 'h22c, "bne  x1, x0, 0x234" );
  h.asm( 'h230, "addi x11, x0, 99"   ); // squashed
  h.asm( 'h234, "bne  x1, x0, 0x23c" );
  h.asm( 'h238, "addi x12, x0, 99"   ); // squashed
  h.asm( 'h23c, "bne  x1, x0, 0x244" );
  h.asm( 'h240, "addi x13, x0, 99"   ); // squashed

  // Mixed jal and bne alternating
  h.asm( 'h244, "jal  x0, 0x24c"     );
  h.asm( 'h248, "addi x14, x0, 99"   ); // squashed
  h.asm( 'h24c, "bne  x1, x0, 0x254" );
  h.asm( 'h250, "addi x15, x0, 99"   ); // squashed
  h.asm( 'h254, "jal  x0, 0x25c"     );
  h.asm( 'h258, "addi x16, x0, 99"   ); // squashed
  h.asm( 'h25c, "bne  x1, x0, 0x264" );
  h.asm( 'h260, "addi x17, x0, 99"   ); // squashed

  h.asm( 'h264, "addi x18, x0, 18"   );
  h.asm( 'h268, "addi x19, x0, 19"   );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_bne_branch_storm
//------------------------------------------------------------------------

task test_case_golden_bne_branch_storm();
  h.t.test_case_begin( "test_case_golden_bne_branch_storm" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1, x0, 1"     );
  h.asm( 'h204, "addi x2, x0, 2"     );

  // Taken branch skipping to more branches
  h.asm( 'h208, "bne  x1, x0, 0x210" );
  h.asm( 'h20c, "addi x3, x0, 99"    ); // squashed
  h.asm( 'h210, "bne  x0, x0, 0x220" ); // not taken
  h.asm( 'h214, "bne  x1, x0, 0x21c" ); // taken
  h.asm( 'h218, "addi x4, x0, 99"    ); // squashed
  h.asm( 'h21c, "bne  x0, x0, 0x230" ); // not taken

  // Four consecutive not-taken branches (all fall through)
  h.asm( 'h220, "bne  x0, x0, 0x240" );
  h.asm( 'h224, "bne  x0, x0, 0x250" );
  h.asm( 'h228, "bne  x0, x0, 0x260" );
  h.asm( 'h22c, "bne  x0, x0, 0x270" );

  // Four consecutive taken branches (each skips one)
  h.asm( 'h230, "bne  x1, x0, 0x238" );
  h.asm( 'h234, "addi x5, x0, 99"    ); // squashed
  h.asm( 'h238, "bne  x2, x0, 0x240" );
  h.asm( 'h23c, "addi x6, x0, 99"    ); // squashed
  h.asm( 'h240, "bne  x1, x0, 0x248" );
  h.asm( 'h244, "addi x7, x0, 99"    ); // squashed
  h.asm( 'h248, "bne  x2, x0, 0x250" );
  h.asm( 'h24c, "addi x8, x0, 99"    ); // squashed

  // Branch landing on another branch (chain of redirections)
  h.asm( 'h250, "bne  x1, x0, 0x258" );
  h.asm( 'h254, "addi x9, x0, 99"    ); // squashed
  h.asm( 'h258, "bne  x1, x0, 0x260" );
  h.asm( 'h25c, "addi x10, x0, 99"   ); // squashed
  h.asm( 'h260, "bne  x1, x0, 0x268" );
  h.asm( 'h264, "addi x11, x0, 99"   ); // squashed
  h.asm( 'h268, "addi x12, x0, 12"   );

  // JAL -> BNE -> JAL -> BNE chain
  h.asm( 'h26c, "jal  x0, 0x274"     );
  h.asm( 'h270, "addi x13, x0, 99"   ); // squashed
  h.asm( 'h274, "bne  x1, x0, 0x27c" );
  h.asm( 'h278, "addi x14, x0, 99"   ); // squashed
  h.asm( 'h27c, "jal  x0, 0x284"     );
  h.asm( 'h280, "addi x15, x0, 99"   ); // squashed
  h.asm( 'h284, "bne  x2, x0, 0x28c" );
  h.asm( 'h288, "addi x16, x0, 99"   ); // squashed

  h.asm( 'h28c, "addi x17, x0, 17"   );
  h.asm( 'h290, "addi x18, x0, 18"   );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_golden_bne_tests
//------------------------------------------------------------------------

task run_golden_bne_tests();
  test_case_golden_bne_1_mix();
  test_case_golden_bne_before_jump();
  test_case_golden_bne_jal_same_window();
  test_case_golden_bne_multi_branch();
  test_case_golden_bne_jal_chain();
  test_case_golden_bne_branch_storm();
endtask
