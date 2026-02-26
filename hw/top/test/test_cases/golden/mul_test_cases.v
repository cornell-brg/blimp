//========================================================================
// mul_test_cases.v
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_golden_mul_1_regs
//------------------------------------------------------------------------

task test_case_golden_mul_1_regs();
  h.t.test_case_begin( "test_case_golden_mul_1_regs" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1,  x0,  0x01" );
  h.asm( 'h204, "addi x2,  x0,  0x02" ); // x2 = 2
  h.asm( 'h208, "addi x3,  x0,  0x03" );
  h.asm( 'h20c, "addi x4,  x0,  0x04" );

  h.asm( 'h210, "mul  x1,  x2,  x3"   );
  h.asm( 'h214, "mul  x2,  x3,  x4"   ); // x2 = 3*4 = 12
  h.asm( 'h218, "mul  x3,  x4,  x1"   ); // x3 = 4*6 = 24
  h.asm( 'h21c, "mul  x4,  x1,  x2"   );

  h.asm( 'h220, "addi x28, x0,  0x24" );
  h.asm( 'h224, "addi x29, x0,  0x25" );
  h.asm( 'h228, "addi x30, x0,  0x26" );
  h.asm( 'h22c, "addi x31, x0,  0x27" );

  h.asm( 'h230, "mul  x28, x29, x30"  ); // x28 = 0x25*0x26 = 0x5ca
  h.asm( 'h234, "mul  x29, x30, x31"  );
  h.asm( 'h238, "mul  x30, x31, x28"  );
  h.asm( 'h23c, "mul  x31, x28, x29"  );

  h.asm( 'h240, "mul  x1,  x2,  x2"   ); // x1 = 12*12 = 144
  h.asm( 'h244, "mul  x2,  x2,  x3"   );
  h.asm( 'h248, "mul  x3,  x3,  x3"   );

  h.asm( 'h24c, "addi x1,  x1,  0"    ); // x1 = 144
  h.asm( 'h250, "addi x2,  x2,  0"    );
  h.asm( 'h254, "addi x3,  x3,  0"    );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_mul_2_deps
//------------------------------------------------------------------------

task test_case_golden_mul_2_deps();
  h.t.test_case_begin( "test_case_golden_mul_2_deps" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1,  x0,  0x02"   );
  h.asm( 'h204, "addi x2,  x0,  0x03"   );
  h.asm( 'h208, "mul  x3,  x1,  x2"     );
  h.asm( 'h20c, "mul  x4,  x3,  x1"     );
  h.asm( 'h210, "mul  x5,  x4,  x1"     );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_mul_3_mix
//------------------------------------------------------------------------

task test_case_golden_mul_3_mix();
  h.t.test_case_begin( "test_case_golden_mul_3_mix" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x3,  x0, 0"     );

  h.asm( 'h204, "addi x4,  x0, 1"     );
  h.asm( 'h208, "addi x5,  x0, 5"     );
  h.asm( 'h20c, "mul  x6,  x4, x5"    );
  h.asm( 'h210, "add  x3,  x3, x6"    );

  h.asm( 'h214, "addi x4,  x0, 2"     );
  h.asm( 'h218, "addi x5,  x0, 6"     );
  h.asm( 'h21c, "mul  x6,  x4, x5"    );
  h.asm( 'h220, "add  x3,  x3, x6"    );

  h.asm( 'h224, "addi x4,  x0, 3"     );
  h.asm( 'h228, "addi x5,  x0, 7"     );
  h.asm( 'h22c, "mul  x6,  x4, x5"    );
  h.asm( 'h230, "add  x3,  x3, x6"    );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_golden_mul_4_latency
//------------------------------------------------------------------------
// Check that OOO backends can handle potentially increased multiplier
// latency

task test_case_golden_mul_4_latency();
  h.t.test_case_begin( "test_case_golden_mul_4_latency" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x1,  x0, 1"     );
  h.asm( 'h204, "addi x2,  x0, 2"     );
  h.asm( 'h208, "addi x3,  x0, 3"     );

  // mul may complete later
  h.asm( 'h20c, "mul  x4,  x2, x3"     );
  h.asm( 'h210, "add  x5,  x1, x2"     );
  h.asm( 'h214, "add  x6,  x3, x3"     );

  h.asm( 'h218, "add  x7,  x4, x5"     );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_mul_tests
//------------------------------------------------------------------------

task run_golden_mul_tests();
  test_case_golden_mul_1_regs();
  test_case_golden_mul_2_deps();
  test_case_golden_mul_3_mix();
  test_case_golden_mul_4_latency();
endtask
