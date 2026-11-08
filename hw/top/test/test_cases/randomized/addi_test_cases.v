// Randomized ADDI testcases: seed/imm/reg combos to exercise immediate
// addition and x0 behavior. Uses $urandom for randomness and emits
// assembly strings via h.asm so matches the golden/test style.

// Emit addi instruction from PC (pc passed explicitly to keep API simple)
task emit_addi_inst;
  input [31:0] pc_in;
  input integer rd;
  input integer imm;
  string inst;
  begin
    inst = $sformatf("addi x%0d, x0, %0d", rd, imm);
    h.asm(pc_in, inst);
  end
endtask

//------------------------------------------------------------------------
// test_case_randomized_addi_1_basic
//------------------------------------------------------------------------

task test_case_randomized_addi_1_basic();
  integer pc;
  integer i;
  integer rd;
  integer imm;

  h.t.test_case_begin("test_case_randomized_addi_1_basic");
  if (!h.t.run_test) return;
  fl_reset();

  pc = 32'h000;
  for (i = 0; i < 100; i = i + 1) begin
    rd = $urandom % 32;
    imm = $urandom % 4096;
    if (imm > 2047) imm = imm - 4096;
    if ((rd == 0) && (($urandom % 10) > 2)) rd = ($urandom % 31) + 1;
    emit_addi_inst(pc, rd, imm);
    pc = pc + 4;
  end

  h.check_traces();
  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_randomized_addi_2_depchains
//------------------------------------------------------------------------

task test_case_randomized_addi_2_depchains();
  integer pc;
  integer c;
  integer a, b;
  integer imm1, imm2;

  h.t.test_case_begin("test_case_randomized_addi_2_depchains");
  if (!h.t.run_test) return;
  fl_reset();

  pc = 32'h000;
  for (c = 0; c < 50; c = c + 1) begin
    a = ($urandom % 31) + 1;
    b = ($urandom % 31) + 1;
    imm1 = $urandom % 2048;
    if (imm1 > 1023) imm1 = imm1 - 2048;
    imm2 = $urandom % 2048;
    if (imm2 > 1023) imm2 = imm2 - 2048;
    emit_addi_inst(pc, a, imm1); pc = pc + 4;
    emit_addi_inst(pc, b, imm2); pc = pc + 4;
    emit_addi_inst(pc, a, imm2); pc = pc + 4;
    emit_addi_inst(pc, b, imm1); pc = pc + 4;
    emit_addi_inst(pc, a, 0); pc = pc + 4;
  end

  h.check_traces();
  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_randomized_addi_3_x0
//------------------------------------------------------------------------

task test_case_randomized_addi_3_x0();
  integer pc;
  integer i;
  integer rd;
  integer imm;

  h.t.test_case_begin("test_case_randomized_addi_3_x0");
  if (!h.t.run_test) return;
  fl_reset();

  pc = 32'h000;
  for (i = 0; i < 60; i = i + 1) begin
    rd = $urandom % 32;
    if (($urandom % 4) == 0)
      imm = 0;
    else begin
      imm = $urandom % 4096;
      if (imm > 2047) imm = imm - 4096;
    end
    emit_addi_inst(pc, rd, imm);
    pc = pc + 4;
  end

  h.check_traces();
  h.t.test_case_end();
endtask

// Aggregator
task automatic run_randomized_addi_tests();
  integer _run_rand;
  // default: run randomized tests
  _run_rand = 1;
  if ($value$plusargs("run_randomized=%d", _run_rand)) begin
    // plusarg provided; _run_rand updated
  end
  if (_run_rand != 0) begin
    test_case_randomized_addi_1_basic();
    test_case_randomized_addi_2_depchains();
    test_case_randomized_addi_3_x0();
  end
endtask
