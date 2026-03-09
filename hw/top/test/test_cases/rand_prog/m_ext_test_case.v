//========================================================================
// m_ext_test_case
//========================================================================

//------------------------------------------------------------------------
// test_case_rand_prog_m_ext
//------------------------------------------------------------------------

task test_case_rand_prog_m_ext();
  h.t.test_case_begin( "test_case_rand_prog_m_ext" );
  if( !h.t.run_test ) return;
  fl_reset();

  // Write assembly program into memory

  h.asm( 'h200, "addi x0, x0, -968" );
  h.asm( 'h204, "addi x1, x0, 1907" );
  h.asm( 'h208, "lui x2, 524434" );
  h.asm( 'h20c, "addi x2, x2, -2048" );
  h.asm( 'h210, "addi x3, x0, 819" );
  h.asm( 'h214, "addi x4, x0, -262" );
  h.asm( 'h218, "addi x5, x0, 827" );
  h.asm( 'h21c, "addi x6, x0, -1491" );
  h.asm( 'h220, "addi x7, x0, 316" );
  h.asm( 'h224, "addi x8, x0, 1488" );
  h.asm( 'h228, "addi x9, x0, -616" );
  h.asm( 'h22c, "addi x10, x0, -244" );
  h.asm( 'h230, "addi x11, x0, -1585" );
  h.asm( 'h234, "addi x12, x0, 350" );
  h.asm( 'h238, "addi x13, x0, -613" );
  h.asm( 'h23c, "addi x14, x0, 12" );
  h.asm( 'h240, "addi x15, x0, 1386" );
  h.asm( 'h244, "addi x16, x0, 1040" );
  h.asm( 'h248, "addi x17, x0, -1159" );
  h.asm( 'h24c, "addi x18, x0, 1250" );
  h.asm( 'h250, "addi x19, x0, 1659" );
  h.asm( 'h254, "addi x20, x0, -274" );
  h.asm( 'h258, "addi x21, x0, -660" );
  h.asm( 'h25c, "addi x22, x0, 967" );
  h.asm( 'h260, "addi x23, x0, 1453" );
  h.asm( 'h264, "addi x24, x0, -144" );
  h.asm( 'h268, "addi x25, x0, 523" );
  h.asm( 'h26c, "addi x26, x0, -586" );
  h.asm( 'h270, "addi x27, x0, -1876" );
  h.asm( 'h274, "addi x28, x0, 666" );
  h.asm( 'h278, "addi x29, x0, -811" );
  h.asm( 'h27c, "addi x30, x0, -139" );
  h.asm( 'h280, "addi x31, x0, 457" );
  h.asm( 'h284, "addi x31, x0, 10" );
  h.asm( 'h288, "or x31, x22, x26" );
  h.asm( 'h28c, "sltu x22, x5, x24" );
  h.asm( 'h290, "lui x0, 260422" );
  h.asm( 'h294, "srli x22, x0, 14" );
  h.asm( 'h298, "sra x0, x21, x25" );
  h.asm( 'h29c, "mulhu x8, x31, x22" );
  h.asm( 'h2a0, "mulhu x0, x8, x8" );
  h.asm( 'h2a4, "sra x12, x8, x31" );
  h.asm( 'h2a8, "and x31, x30, x13" );
  h.asm( 'h2ac, "mulhsu x8, x22, x22" );
  h.asm( 'h2b0, "mulhu x23, x5, x19" );
  h.asm( 'h2b4, "remu x9, x20, x30" );
  h.asm( 'h2b8, "div x22, x8, x8" );
  h.asm( 'h2bc, "remu x21, x8, x31" );
  h.asm( 'h2c0, "lui x19, 149212" );
  h.asm( 'h2c4, "divu x18, x8, x31" );
  h.asm( 'h2c8, "mulhsu x8, x4, x25" );
  h.asm( 'h2cc, "rem x23, x22, x8" );
  h.asm( 'h2d0, "mulhsu x18, x0, x8" );
  h.asm( 'h2d4, "and x10, x22, x0" );
  h.asm( 'h2d8, "mul x31, x0, x8" );
  h.asm( 'h2dc, "div x22, x8, x22" );
  h.asm( 'h2e0, "srli x20, x14, 2" );
  h.asm( 'h2e4, "srli x0, x0, 5" );
  h.asm( 'h2e8, "xor x20, x7, x19" );
  h.asm( 'h2ec, "ori x25, x31, 421" );
  h.asm( 'h2f0, "srl x20, x0, x0" );
  h.asm( 'h2f4, "rem x22, x22, x0" );
  h.asm( 'h2f8, "auipc x18, 523545" );
  h.asm( 'h2fc, "mul x13, x20, x8" );
  h.asm( 'h300, "srl x28, x29, x21" );
  h.asm( 'h304, "srli x12, x5, 21" );
  h.asm( 'h308, "slti x0, x20, 63" );
  h.asm( 'h30c, "srli x15, x22, 1" );
  h.asm( 'h310, "slti x22, x28, -1317" );
  h.asm( 'h314, "add x23, x20, x8" );
  h.asm( 'h318, "divu x8, x14, x15" );
  h.asm( 'h31c, "or x8, x31, x13" );
  h.asm( 'h320, "sltu x18, x6, x23" );
  h.asm( 'h324, "mulh x27, x22, x0" );
  h.asm( 'h328, "mulh x17, x22, x22" );
  h.asm( 'h32c, "mul x22, x28, x28" );
  h.asm( 'h330, "srl x5, x22, x8" );
  h.asm( 'h334, "mul x3, x22, x0" );
  h.asm( 'h338, "srai x8, x31, 9" );
  h.asm( 'h33c, "div x22, x28, x16" );
  h.asm( 'h340, "addi x24, x21, 121" );
  h.asm( 'h344, "rem x22, x8, x0" );
  h.asm( 'h348, "remu x15, x8, x8" );
  h.asm( 'h34c, "sra x0, x29, x17" );
  h.asm( 'h350, "ori x22, x12, 285" );
  h.asm( 'h354, "or x22, x22, x22" );
  h.asm( 'h358, "srl x31, x8, x22" );
  h.asm( 'h35c, "mulhsu x25, x8, x22" );
  h.asm( 'h360, "remu x8, x8, x0" );
  h.asm( 'h364, "divu x19, x21, x15" );
  h.asm( 'h368, "mulhsu x29, x28, x14" );
  h.asm( 'h36c, "and x0, x22, x0" );
  h.asm( 'h370, "mulhu x8, x10, x9" );
  h.asm( 'h374, "mulhsu x0, x28, x5" );
  h.asm( 'h378, "rem x22, x0, x8" );
  h.asm( 'h37c, "div x22, x10, x29" );
  h.asm( 'h380, "mul x0, x0, x22" );
  h.asm( 'h384, "ori x8, x8, -1886" );
  h.asm( 'h388, "sra x8, x19, x11" );
  h.asm( 'h38c, "rem x16, x0, x8" );
  h.asm( 'h390, "remu x12, x8, x8" );
  h.asm( 'h394, "rem x8, x12, x28" );
  h.asm( 'h398, "and x18, x23, x18" );
  h.asm( 'h39c, "mul x22, x8, x22" );
  h.asm( 'h3a0, "add x0, x10, x3" );
  h.asm( 'h3a4, "or x3, x22, x22" );
  h.asm( 'h3a8, "mulhu x20, x22, x0" );
  h.asm( 'h3ac, "sra x23, x0, x0" );
  h.asm( 'h3b0, "mulhu x18, x0, x0" );
  h.asm( 'h3b4, "sltiu x0, x0, -1523" );
  h.asm( 'h3b8, "sub x27, x28, x14" );
  h.asm( 'h3bc, "auipc x8, 358100" );
  h.asm( 'h3c0, "mulhu x0, x16, x16" );
  h.asm( 'h3c4, "or x17, x12, x5" );
  h.asm( 'h3c8, "slt x22, x26, x18" );
  h.asm( 'h3cc, "remu x8, x22, x8" );
  h.asm( 'h3d0, "mulhu x6, x29, x30" );
  h.asm( 'h3d4, "srli x16, x6, 2" );
  h.asm( 'h3d8, "andi x0, x17, 207" );
  h.asm( 'h3dc, "mulhsu x31, x3, x11" );
  h.asm( 'h3e0, "mulh x8, x6, x17" );
  h.asm( 'h3e4, "rem x23, x0, x8" );
  h.asm( 'h3e8, "rem x28, x14, x25" );
  h.asm( 'h3ec, "mulhu x13, x27, x14" );
  h.asm( 'h3f0, "remu x22, x22, x0" );
  h.asm( 'h3f4, "rem x22, x22, x8" );
  h.asm( 'h3f8, "addi x23, x8, -667" );
  h.asm( 'h3fc, "sll x22, x22, x22" );
  h.asm( 'h400, "sub x0, x22, x0" );
  h.asm( 'h404, "and x29, x31, x15" );
  h.asm( 'h408, "remu x22, x0, x0" );
  h.asm( 'h40c, "srai x3, x14, 15" );
  h.asm( 'h410, "or x6, x22, x8" );
  h.asm( 'h414, "mul x10, x22, x22" );

  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_rand_prog_m_ext_test
//------------------------------------------------------------------------

task run_rand_prog_m_ext_test();
  test_case_rand_prog_m_ext();
endtask
