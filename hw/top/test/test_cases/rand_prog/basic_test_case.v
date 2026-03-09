//========================================================================
// basic_test_case
//========================================================================

//------------------------------------------------------------------------
// test_case_rand_prog_basic
//------------------------------------------------------------------------

task test_case_rand_prog_basic();
  h.t.test_case_begin( "test_case_rand_prog_basic" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x0, x0, -880" );
  h.asm( 'h204, "addi x1, x0, 1293" );
  h.asm( 'h208, "lui x2, 524434" );
  h.asm( 'h20c, "addi x2, x2, -2048" );
  h.asm( 'h210, "addi x3, x0, -785" );
  h.asm( 'h214, "addi x4, x0, -1121" );
  h.asm( 'h218, "addi x5, x0, -788" );
  h.asm( 'h21c, "addi x6, x0, 265" );
  h.asm( 'h220, "addi x7, x0, 782" );
  h.asm( 'h224, "addi x8, x0, -489" );
  h.asm( 'h228, "addi x9, x0, -457" );
  h.asm( 'h22c, "addi x10, x0, -1703" );
  h.asm( 'h230, "addi x11, x0, -1166" );
  h.asm( 'h234, "addi x12, x0, -1743" );
  h.asm( 'h238, "addi x13, x0, -1648" );
  h.asm( 'h23c, "addi x14, x0, -1175" );
  h.asm( 'h240, "addi x15, x0, -389" );
  h.asm( 'h244, "addi x16, x0, -1448" );
  h.asm( 'h248, "addi x17, x0, 1919" );
  h.asm( 'h24c, "addi x18, x0, -1573" );
  h.asm( 'h250, "addi x19, x0, 1419" );
  h.asm( 'h254, "addi x20, x0, -33" );
  h.asm( 'h258, "addi x21, x0, -154" );
  h.asm( 'h25c, "addi x22, x0, -1697" );
  h.asm( 'h260, "addi x23, x0, -1173" );
  h.asm( 'h264, "addi x24, x0, 426" );
  h.asm( 'h268, "addi x25, x0, -659" );
  h.asm( 'h26c, "addi x26, x0, 1215" );
  h.asm( 'h270, "addi x27, x0, 1584" );
  h.asm( 'h274, "addi x28, x0, -1740" );
  h.asm( 'h278, "addi x29, x0, 1" );
  h.asm( 'h27c, "addi x30, x0, 1619" );
  h.asm( 'h280, "addi x31, x0, -1644" );
  h.asm( 'h284, "addi x31, x0, 10" );
  h.asm( 'h288, "or x0, x3, x30" );
  h.asm( 'h28c, "srl x31, x25, x25" );
  h.asm( 'h290, "xori x0, x29, 1057" );
  h.asm( 'h294, "auipc x28, 101389" );
  h.asm( 'h298, "add x6, x29, x25" );
  h.asm( 'h29c, "srai x29, x0, 7" );
  h.asm( 'h2a0, "xori x3, x0, -595" );
  h.asm( 'h2a4, "slli x21, x28, 10" );
  h.asm( 'h2a8, "sll x15, x6, x31" );
  h.asm( 'h2ac, "sll x29, x18, x5" );
  h.asm( 'h2b0, "sll x21, x13, x13" );
  h.asm( 'h2b4, "auipc x4, 7702" );
  h.asm( 'h2b8, "and x25, x23, x5" );
  h.asm( 'h2bc, "slt x6, x29, x21" );
  h.asm( 'h2c0, "sltiu x12, x6, -123" );
  h.asm( 'h2c4, "slt x23, x0, x29" );
  h.asm( 'h2c8, "srai x25, x0, 12" );
  h.asm( 'h2cc, "sltu x29, x17, x30" );
  h.asm( 'h2d0, "add x29, x21, x25" );
  h.asm( 'h2d4, "srli x12, x25, 26" );
  h.asm( 'h2d8, "sltu x29, x21, x25" );
  h.asm( 'h2dc, "srai x25, x0, 21" );
  h.asm( 'h2e0, "xori x0, x25, -241" );
  h.asm( 'h2e4, "xor x25, x30, x8" );
  h.asm( 'h2e8, "addi x0, x27, -837" );
  h.asm( 'h2ec, "sltu x15, x29, x0" );
  h.asm( 'h2f0, "xori x30, x0, -1543" );
  h.asm( 'h2f4, "andi x0, x14, -1916" );
  h.asm( 'h2f8, "slti x30, x25, 2031" );
  h.asm( 'h2fc, "srai x30, x7, 11" );
  h.asm( 'h300, "xor x29, x0, x0" );
  h.asm( 'h304, "ori x29, x29, -582" );
  h.asm( 'h308, "sltu x22, x0, x0" );
  h.asm( 'h30c, "sltiu x4, x0, 1658" );
  h.asm( 'h310, "andi x25, x6, 979" );
  h.asm( 'h314, "sltiu x29, x14, 4" );
  h.asm( 'h318, "sra x18, x15, x10" );
  h.asm( 'h31c, "xor x13, x29, x25" );
  h.asm( 'h320, "add x9, x27, x3" );
  h.asm( 'h324, "sltiu x29, x26, 1291" );
  h.asm( 'h328, "srai x9, x18, 1" );
  h.asm( 'h32c, "srai x9, x25, 1" );
  h.asm( 'h330, "slli x0, x29, 4" );
  h.asm( 'h334, "slt x12, x0, x25" );
  h.asm( 'h338, "sub x18, x25, x25" );
  h.asm( 'h33c, "or x31, x0, x0" );
  h.asm( 'h340, "sll x29, x29, x29" );
  h.asm( 'h344, "and x7, x10, x11" );
  h.asm( 'h348, "add x30, x26, x24" );
  h.asm( 'h34c, "and x25, x6, x4" );
  h.asm( 'h350, "sltiu x0, x25, -574" );
  h.asm( 'h354, "sltiu x25, x29, 1086" );
  h.asm( 'h358, "srli x0, x29, 12" );
  h.asm( 'h35c, "add x21, x25, x0" );
  h.asm( 'h360, "sltiu x0, x25, -1956" );
  h.asm( 'h364, "sra x29, x18, x5" );
  h.asm( 'h368, "lui x12, 354100" );
  h.asm( 'h36c, "xor x4, x4, x12" );
  h.asm( 'h370, "addi x18, x29, -1266" );
  h.asm( 'h374, "lui x25, 352583" );
  h.asm( 'h378, "srl x0, x0, x29" );
  h.asm( 'h37c, "srai x17, x19, 9" );
  h.asm( 'h380, "sub x4, x0, x25" );
  h.asm( 'h384, "srl x27, x25, x0" );
  h.asm( 'h388, "slti x29, x0, -1092" );
  h.asm( 'h38c, "srli x0, x0, 18" );
  h.asm( 'h390, "srl x29, x29, x0" );
  h.asm( 'h394, "sll x6, x25, x29" );
  h.asm( 'h398, "addi x17, x29, -254" );
  h.asm( 'h39c, "and x0, x25, x25" );
  h.asm( 'h3a0, "and x29, x25, x0" );
  h.asm( 'h3a4, "sll x28, x3, x9" );
  h.asm( 'h3a8, "slt x0, x8, x18" );
  h.asm( 'h3ac, "sll x0, x29, x29" );
  h.asm( 'h3b0, "xor x4, x0, x25" );
  h.asm( 'h3b4, "slli x0, x25, 13" );
  h.asm( 'h3b8, "sltu x0, x0, x0" );
  h.asm( 'h3bc, "sub x18, x13, x24" );
  h.asm( 'h3c0, "add x25, x5, x19" );
  h.asm( 'h3c4, "sltu x29, x7, x20" );
  h.asm( 'h3c8, "srai x7, x25, 5" );
  h.asm( 'h3cc, "slt x25, x25, x25" );
  h.asm( 'h3d0, "and x30, x14, x11" );
  h.asm( 'h3d4, "sll x0, x25, x29" );
  h.asm( 'h3d8, "sltiu x20, x17, 1967" );
  h.asm( 'h3dc, "lui x0, 190266" );
  h.asm( 'h3e0, "addi x10, x11, 465" );
  h.asm( 'h3e4, "or x25, x29, x0" );
  h.asm( 'h3e8, "auipc x5, 283943" );
  h.asm( 'h3ec, "or x0, x29, x29" );
  h.asm( 'h3f0, "srai x29, x29, 10" );
  h.asm( 'h3f4, "srai x25, x14, 7" );
  h.asm( 'h3f8, "sll x25, x29, x25" );
  h.asm( 'h3fc, "sltiu x0, x0, -20" );
  h.asm( 'h400, "auipc x26, 395403" );
  h.asm( 'h404, "sra x31, x0, x25" );
  h.asm( 'h408, "andi x21, x0, -858" );
  h.asm( 'h40c, "andi x5, x23, 1059" );
  h.asm( 'h410, "sltu x25, x10, x20" );
  h.asm( 'h414, "xori x9, x0, -1724" );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_rand_prog_basic_test
//------------------------------------------------------------------------

task run_rand_prog_basic_test();
  test_case_rand_prog_basic();
endtask
