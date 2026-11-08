//========================================================================
// auipc_test_cases
//========================================================================
// Adapted from Cornell's ECE 2300

//------------------------------------------------------------------------
// test_case_directed_auipc_1_basic
//------------------------------------------------------------------------

task test_case_directed_auipc_1_basic();
  h.t.test_case_begin( "test_case_directed_auipc_1_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "auipc x1, 0x001"  );

  // Check each executed instruction

  h.check_trace( 'h000, 1, 'h0000_1000, 1 ); // auipc  x1, 0x001

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_directed_auipc_extreme
//------------------------------------------------------------------------

task test_case_directed_auipc_2_extreme();
  h.t.test_case_begin( "test_case_directed_auipc_2_extreme" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h000, "auipc  x0, 0x12345" );

  h.asm( 'h004, "auipc  x1, 0x00000" );
  h.asm( 'h008, "auipc  x2, 0xfffff" );
  h.asm( 'h00c, "auipc  x3, 0x7ffff" );
  h.asm( 'h010, "auipc  x4, 0x80000" );

  // Check each executed instruction

  h.check_trace( 'h000, 'x, 'x,   0 ); // auipc  x0, 0x12345
  
  h.check_trace( 'h004, 1, 'h0000_0004, 1 ); // auipc  x1, 0x00000
  h.check_trace( 'h008, 2, 'hffff_f008, 1 ); // auipc  x2, 0xfffff
  h.check_trace( 'h00c, 3, 'h7fff_f00c, 1 ); // auipc  x3, 0x7ffff
  h.check_trace( 'h010, 4, 'h8000_0010, 1 ); // auipc  x4, 0x80000

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_directed_auipc_tests
//------------------------------------------------------------------------

task run_directed_auipc_tests();
  test_case_directed_auipc_1_basic();
  test_case_directed_auipc_2_extreme();
endtask
