//========================================================================
// randomized add_test_cases (Verilog)
//========================================================================
// Emits randomized ADD instruction sequences by encoding R-type instructions
// directly and writing 32-bit words into memory using h.asm_binary.

//========================================================================
// randomized add_test_cases (Verilog)
//========================================================================
// Emit randomized ADD/ADDI sequences using assembly strings and h.asm

// Note: This file uses Verilog tasks and $urandom for randomness. We
// construct instruction strings with $sformatf which many Verilog
// toolchains accept even in .v files; if your toolchain rejects it,
// we can switch to a table-of-strings approach.

task test_case_randomized_add_1_sanity();
  integer pc;
  integer i;
  integer r1, r2, rd;
  integer imm1, imm2;
  string inst;

  h.t.test_case_begin("test_case_randomized_add_1_sanity");
  if (!h.t.run_test) return;
  fl_reset();

  pc = 32'h000;
  for (i = 0; i < 200; i = i + 1) begin
    r1 = $urandom & 32'h1F;
    r2 = $urandom & 32'h1F;
    rd = $urandom & 32'h1F;

    imm1 = $urandom % 4096;
    if (imm1 > 2047) imm1 = imm1 - 4096;
    imm2 = $urandom % 4096;
    if (imm2 > 2047) imm2 = imm2 - 4096;

    inst = $sformatf("addi x%0d, x0, %0d", r1, imm1);
    h.asm(pc, inst);
    pc = pc + 4;

    inst = $sformatf("addi x%0d, x0, %0d", r2, imm2);
    h.asm(pc, inst);
    pc = pc + 4;

    inst = $sformatf("add x%0d, x%0d, x%0d", rd, r1, r2);
    h.asm(pc, inst);
    pc = pc + 4;
  end

  h.check_traces();
  h.t.test_case_end();
endtask

task test_case_randomized_add_2_deps();
  integer pc;
  integer c;
  integer a, b, creg, d;
  integer ia, ib;
  string inst;

  h.t.test_case_begin("test_case_randomized_add_2_deps");
  if (!h.t.run_test) return;
  fl_reset();

  pc = 32'h000;
  for (c = 0; c < 50; c = c + 1) begin
    a = ( ($urandom & 31) == 0 ) ? 1 : ($urandom & 32'h1F);
    b = ( ($urandom & 31) == 0 ) ? 2 : ($urandom & 32'h1F);
    creg = $urandom & 32'h1F;
    d = $urandom & 32'h1F;

    ia = $urandom % 4096;
    if (ia > 2047) ia = ia - 4096;
    ib = $urandom % 4096;
    if (ib > 2047) ib = ib - 4096;

    inst = $sformatf("addi x%0d, x0, %0d", a, ia);
    h.asm(pc, inst);
    pc = pc + 4;
    inst = $sformatf("addi x%0d, x0, %0d", b, ib);
    h.asm(pc, inst);
    pc = pc + 4;

    inst = $sformatf("add x%0d, x%0d, x%0d", creg, b, a);
    h.asm(pc, inst);
    pc = pc + 4;
    inst = $sformatf("add x%0d, x%0d, x%0d", d, creg, a);
    h.asm(pc, inst);
    pc = pc + 4;
    inst = $sformatf("add x%0d, x%0d, x%0d", a, d, b);
    h.asm(pc, inst);
    pc = pc + 4;
  end

  h.check_traces();
  h.t.test_case_end();
endtask

task test_case_randomized_add_3_x0();
  integer pc;
  integer i;
  integer r1, r2, rd;
  integer imm;
  string inst;

  h.t.test_case_begin("test_case_randomized_add_3_x0");
  if (!h.t.run_test) return;
  fl_reset();

  pc = 32'h000;
  for (i = 0; i < 150; i = i + 1) begin
    r1 = $urandom & 32'h1F;
    r2 = $urandom & 32'h1F;

    imm = $urandom % 4096;
    if (imm > 2047) imm = imm - 4096;

    inst = $sformatf("addi x%0d, x0, %0d", r1, imm);
    h.asm(pc, inst);
    pc = pc + 4;
    inst = $sformatf("addi x%0d, x0, %0d", r2, imm);
    h.asm(pc, inst);
    pc = pc + 4;

    if (($urandom & 3) == 0) rd = 0; else rd = $urandom & 32'h1F;
    inst = $sformatf("add x%0d, x%0d, x%0d", rd, r2, r1);
    h.asm(pc, inst);
    pc = pc + 4;
  end

  h.check_traces();
  h.t.test_case_end();
endtask

// Aggregator
task run_randomized_add_tests();
  test_case_randomized_add_1_sanity();
  test_case_randomized_add_2_deps();
  test_case_randomized_add_3_x0();
endtask
