//========================================================================
// basic_test_case
//========================================================================

//------------------------------------------------------------------------
// test_case_torture_basic
//------------------------------------------------------------------------

task test_case_torture_basic();
  h.t.test_case_begin( "test_case_torture_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "li x31, 10 " );
  h.asm( 'h204, "slli x25, x14, 1 " );
  h.asm( 'h208, "auipc x8, 431043 " );
  h.asm( 'h20c, "or x16, x18, x30 " );
  h.asm( 'h210, "sltiu x18, x8, 123 " );
  h.asm( 'h214, "sltu x23, x18, x8 " );
  h.asm( 'h218, "slt x6, x23, x8 " );
  h.asm( 'h21c, "slli x28, x11, 14 " );
  h.asm( 'h220, "lui x11, 53685 " );
  h.asm( 'h224, "ori x14, x9, 239 " );
  h.asm( 'h228, "sltu x18, x27, x17 " );
  h.asm( 'h22c, "sll x14, x7, x24 " );
  h.asm( 'h230, "slt x26, x6, x8 " );
  h.asm( 'h234, "srl x19, x21, x7 " );
  h.asm( 'h238, "sll x13, x25, x26 " );
  h.asm( 'h23c, "ori x16, x28, -1447 " );
  h.asm( 'h240, "xor x0, x16, x16 " );
  h.asm( 'h244, "slt x21, x24, x4 " );
  h.asm( 'h248, "xor x8, x16, x14 " );
  h.asm( 'h24c, "and x12, x7, x11 " );
  h.asm( 'h250, "sub x16, x24, x27 " );
  h.asm( 'h254, "andi x8, x4, -551 " );
  h.asm( 'h258, "sltu x19, x14, x18 " );
  h.asm( 'h25c, "xor x0, x14, x16 " );
  h.asm( 'h260, "auipc x14, 270740 " );
  h.asm( 'h264, "slti x14, x6, 802 " );
  h.asm( 'h268, "slt x16, x14, x8 " );
  h.asm( 'h26c, "or x8, x15, x28 " );
  h.asm( 'h270, "add x20, x28, x25 " );
  h.asm( 'h274, "sltiu x8, x4, -589 " );
  h.asm( 'h278, "addi x7, x16, -425 " );
  h.asm( 'h27c, "slti x16, x25, -1611 " );
  h.asm( 'h280, "srl x8, x14, x8 " );
  h.asm( 'h284, "slt x14, x8, x8 " );
  h.asm( 'h288, "ori x4, x6, -218 " );
  h.asm( 'h28c, "slt x5, x16, x16 " );
  h.asm( 'h290, "slt x8, x17, x19 " );
  h.asm( 'h294, "or x8, x4, x22 " );
  h.asm( 'h298, "sltiu x19, x4, -990 " );
  h.asm( 'h29c, "slti x6, x16, 1991 " );
  h.asm( 'h2a0, "sub x21, x21, x10 " );
  h.asm( 'h2a4, "and x14, x29, x6 " );
  h.asm( 'h2a8, "xor x26, x10, x29 " );
  h.asm( 'h2ac, "sub x6, x31, x30 " );
  h.asm( 'h2b0, "or x20, x14, x8 " );
  h.asm( 'h2b4, "srli x21, x6, 25 " );
  h.asm( 'h2b8, "add x25, x6, x17 " );
  h.asm( 'h2bc, "sltu x22, x16, x16 " );
  h.asm( 'h2c0, "sll x20, x9, x0 " );
  h.asm( 'h2c4, "sub x8, x16, x16 " );
  h.asm( 'h2c8, "sub x16, x14, x8 " );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_torture_basic_test
//------------------------------------------------------------------------

task run_torture_basic_test();
  test_case_torture_basic();
endtask
