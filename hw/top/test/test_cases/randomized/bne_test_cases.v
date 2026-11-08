//========================================================================
// randomized bne_test_cases (SystemVerilog)
//========================================================================
// Emits randomized BNE instruction sequences using assembly strings and h.asm

//------------------------------------------------------------------------
// test_case_randomized_bne_1_simple
//   Simple randomized BNE cases with clear taken vs not-taken behavior.
//   - If x[r1] != x[r2]: branch taken, x31 = 1
//   - If x[r1] == x[r2]: fallthrough, x31 = 0
//------------------------------------------------------------------------

task test_case_randomized_bne_1_simple();
  integer pc;
  integer i;
  integer r1, r2, rd;
  integer imm1, imm2;
  integer target;
  string inst;

  h.t.test_case_begin("test_case_randomized_bne_1_simple");
  if (!h.t.run_test) return;
  fl_reset();

  pc = 32'h000;
  for (i = 0; i < 20; i = i + 1) begin
    r1 = $urandom & 32'h1F;
    r2 = $urandom & 32'h1F;

    // random signed immediates in [-2048, 2047]
    imm1 = $urandom % 4096;
    if (imm1 > 2047) imm1 = imm1 - 4096;
    imm2 = $urandom % 4096;
    if (imm2 > 2047) imm2 = imm2 - 4096;

    // init registers
    inst = $sformatf("addi x%0d, x0, %0d", r1, imm1);
    h.asm(pc, inst);
    pc = pc + 4;

    inst = $sformatf("addi x%0d, x0, %0d", r2, imm2);
    h.asm(pc, inst);
    pc = pc + 4;

    // Branch: if not equal go to 'target' which sets x31=1,
    // else fallthrough path sets x31=0 and skips the target.
    target = pc + 12; // target is after bne + fallthrough + jal
    inst = $sformatf("bne x%0d, x%0d, 0x%0h", r1, r2, target);
    h.asm(pc, inst);
    pc = pc + 4;

    // fallthrough: set x31 = 0
    inst = $sformatf("addi x31, x0, 0");
    h.asm(pc, inst);
    pc = pc + 4;

    // unconditional skip over target if branch not taken
    // At this point pc is the address of this jal.
    // We want to jump to the instruction AFTER target.
    inst = $sformatf("jal x0, 0x%0h", pc + 8);
    h.asm(pc, inst);
    pc = pc + 4;

    // target: set x31 = 1 (only executed when branch is taken)
    inst = $sformatf("addi x31, x0, 1");
    h.asm(pc, inst);
    pc = pc + 4;

    // small sink to avoid overlapping with next sequence
    inst = $sformatf("addi x0, x0, 0");
    h.asm(pc, inst);
    pc = pc + 4;
  end

  h.check_traces();
  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_randomized_bne_2_backward
//   Backward branch test: small counted loop using BNE backward.
//   Loop: rcnt = N; label: rcnt--; bne rcnt, x0, label
//------------------------------------------------------------------------

task test_case_randomized_bne_2_backward();
  integer pc;
  integer i;
  integer rcnt, rtmp;
  integer loop_pc;
  string inst;

  h.t.test_case_begin("test_case_randomized_bne_2_backward");
  if (!h.t.run_test) return;
  fl_reset();

  pc = 32'h000;
  for (i = 0; i < 20; i = i + 1) begin
    // create a small counted loop: rcnt = N; loop: addi rcnt, rcnt, -1; bne rcnt, x0, loop
    rcnt = ($urandom % 15) + 1; // 1..15
    rtmp = ($urandom % 31) + 1; // 1..31, avoid x0 as the counter

    // init counter
    inst = $sformatf("addi x%0d, x0, %0d", rtmp, rcnt);
    h.asm(pc, inst);
    pc = pc + 4;

    // label_loop at current pc
    loop_pc = pc;

    // subtract 1
    inst = $sformatf("addi x%0d, x%0d, -1", rtmp, rtmp);
    h.asm(pc, inst);
    pc = pc + 4;

    // branch back to label_loop if rtmp != 0
    inst = $sformatf("bne x%0d, x0, 0x%0h", rtmp, loop_pc);
    h.asm(pc, inst);
    pc = pc + 4;

    // post-loop: nop (sink)
    inst = $sformatf("addi x0, x0, 0");
    h.asm(pc, inst);
    pc = pc + 4;
  end

  h.check_traces();
  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_randomized_bne_3_mix
//   Mixed randomized sequences combining branches, jumps and arithmetic.
//   - Half the time the branch is taken (rd != 0).
//   - Half the time the branch is not taken (rd == 0).
//   - Taken path sets rd = 42, fallthrough path sets rd = 0.
//------------------------------------------------------------------------

task test_case_randomized_bne_3_mix();
  integer pc;
  integer i;
  integer r1, r2, rd;
  integer imm;
  integer target;
  integer taken_case;
  string inst;

  h.t.test_case_begin("test_case_randomized_bne_3_mix");
  if (!h.t.run_test) return;
  fl_reset();

  pc = 32'h000;
  for (i = 0; i < 20; i = i + 1) begin
    r1 = $urandom & 32'h1F;
    r2 = $urandom & 32'h1F;
    rd = ($urandom % 31) + 1; // 1..31, avoid x0 as destination

    // random signed imm in [-512, 511], avoid 0 to ensure nonzero sum when desired
    imm = $urandom % 1024;
    if (imm > 511) imm = imm - 1024;
    if (imm == 0) imm = 1;

    // Randomly choose whether this iteration should make rd != 0 or rd == 0
    taken_case = $urandom % 2;

    if (|taken_case) begin
      // Case: branch taken (rd != 0)
      // x[r1] = imm, x[r2] = 0 => rd = imm != 0
      inst = $sformatf("addi x%0d, x0, %0d", r1, imm);
      h.asm(pc, inst);
      pc = pc + 4;

      inst = $sformatf("addi x%0d, x0, 0", r2);
      h.asm(pc, inst);
      pc = pc + 4;
    end
    else begin
      // Case: branch not taken (rd == 0)
      // x[r1] = imm, x[r2] = -imm => rd = 0
      inst = $sformatf("addi x%0d, x0, %0d", r1, imm);
      h.asm(pc, inst);
      pc = pc + 4;

      inst = $sformatf("addi x%0d, x0, %0d", r2, -imm);
      h.asm(pc, inst);
      pc = pc + 4;
    end

    // perform an arithmetic op then branch on result
    inst = $sformatf("add x%0d, x%0d, x%0d", rd, r1, r2);
    h.asm(pc, inst);
    pc = pc + 4;

    // target for the branch (marker): will set rd = 42
    // Layout:
    //   pc       : bne
    //   pc+4     : fallthrough (clear rd)
    //   pc+8     : jal skip_target
    //   pc+12    : marker (rd = 42)
    target = pc + 12;

    // branch to marker if rd != 0
    inst = $sformatf("bne x%0d, x0, 0x%0h", rd, target);
    h.asm(pc, inst);
    pc = pc + 4;

    // fallthrough: clear rd (only when branch not taken)
    inst = $sformatf("addi x%0d, x0, 0", rd);
    h.asm(pc, inst);
    pc = pc + 4;

    // skip over marker when branch not taken
    // At this point pc is the address of this jal; marker is at pc+8, and
    // the instruction after marker is at pc+12.
    inst = $sformatf("jal x0, 0x%0h", pc + 8);
    h.asm(pc, inst);
    pc = pc + 4;

    // marker: set rd = 42 (only reached when branch was taken)
    inst = $sformatf("addi x%0d, x0, 42", rd);
    h.asm(pc, inst);
    pc = pc + 4;
  end

  h.check_traces();
  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// Aggregator
//------------------------------------------------------------------------

task run_randomized_bne_tests();
  test_case_randomized_bne_1_simple();
  test_case_randomized_bne_2_backward();
  test_case_randomized_bne_3_mix();
endtask
