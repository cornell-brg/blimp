//========================================================================
// lw_test_cases.v
//========================================================================

//------------------------------------------------------------------------
// test_case_randomized_lw_1_offset
//------------------------------------------------------------------------

task test_case_randomized_lw_1_offset();
  integer offset;
  integer addr;
  integer data;
  integer base_addr;
  integer pc;
  string  inst;
  integer unused;

  h.t.test_case_begin( "test_case_randomized_lw_1_offset" );
  if( !h.t.run_test ) return;
  fl_reset();

  unused = $urandom(seed);

  base_addr = 'h2000;

  // Write assembly program and data into memory

  h.asm( 'h000, "addi x1, x0, 0x200" );
  h.asm( 'h004, "slli x1, x1, 4"     );
  h.asm( 'h000, "addi x1, x0, 0x200" );
  h.asm( 'h004, "slli x1, x1, 4"     );

  pc = 'h008;

  for (int i = 0; i < 200; i++) begin
    
    // Determine address to read from and data to read

    offset = {{ 21{1'($urandom)}}, 9'($urandom), 2'b0};

    addr = base_addr + offset;

    data = 32'($urandom);

    // Write h.data into memory

    h.data( addr, data );

    // Write instruction

    inst = $sformatf("lw x2, %d(x1)", offset);
    h.asm( pc, inst );

    pc = pc + 4;
  end

  // Check each executed instruction
  
  h.check_traces();

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// test_case_randomized_lw_2_chains
//------------------------------------------------------------------------

task test_case_randomized_lw_2_chains();
  integer unused;
  integer pc;
  string  inst;
  integer addr;
  integer data;

  bit select_chain;
  bit select_inst;
  integer reg_fl [18];
  integer rd_idx;
  integer rs1_idx;
  integer rs2_idx;

  integer mem [128];

  integer reg_tr [500];
  integer wdata_tr [500];

  h.t.test_case_begin( "test_case_randomized_lw_2_chains" );
  if( !h.t.run_test ) return;
  fl_reset();

  seed = 32'hC252C252;

  unused = $urandom(seed + 1);

  // Initialize expected base registers (x1-x8 hold pointers into 0x2000 region)

  for (int i = 0; i < 8; i++) begin
    reg_fl[i+1] = 'h2000 + (i << 4);
  end

  // Initialize expected data registers (x10-x17)
  for (int i = 0; i < 8; i++) begin
    reg_fl[i+10] = 0;
  end

  // Initialize memory randomly at 0x2000+

  for (int i = 0; i < 128; i++) begin
    mem[i] = $urandom() & 32'h1fc;
    h.data( (i << 2) + 'h2000, mem[i] );
  end

  // Load 0x2000 into x9 using multi-instruction pattern (like test 1)
  h.asm( 'h000, "addi x9, x0, 0x200" );
  h.asm( 'h004, "slli x9, x9, 4"     );

  // Initialize x1-x8 with offsets from 0x2000 (0x00, 0x10, 0x20, ..., 0x70)
  h.asm( 'h008, "addi x1, x9, 0"   );
  h.asm( 'h00c, "addi x2, x9, 0x10" );
  h.asm( 'h010, "addi x3, x9, 0x20" );
  h.asm( 'h014, "addi x4, x9, 0x30" );
  h.asm( 'h018, "addi x5, x9, 0x40" );
  h.asm( 'h01c, "addi x6, x9, 0x50" );
  h.asm( 'h020, "addi x7, x9, 0x60" );
  h.asm( 'h024, "addi x8, x9, 0x70" );

  // Initialize mutable data regs used by randomized xor/lw chains
  h.asm( 'h028, "addi x10, x0, 0" );
  h.asm( 'h02c, "addi x11, x0, 0" );
  h.asm( 'h030, "addi x12, x0, 0" );
  h.asm( 'h034, "addi x13, x0, 0" );
  h.asm( 'h038, "addi x14, x0, 0" );
  h.asm( 'h03c, "addi x15, x0, 0" );
  h.asm( 'h040, "addi x16, x0, 0" );
  h.asm( 'h044, "addi x17, x0, 0" );

  pc = 'h048;  // Start after init instructions (0x000..0x044)

  for (int i = 0; i < 500; i++) begin
    select_chain = 1'($urandom());
    select_inst  = 1'($urandom());

    // Determine which chain to write to

    if (select_chain == 0) begin
      // Chain 0: base regs x1..x4, data regs x10..x13
      rs1_idx = {30'b0, 2'($urandom())} + 1;
      rd_idx  = {30'b0, 2'($urandom())} + 10;
      rs2_idx = {30'b0, 2'($urandom())} + 10;
    end
    else begin
      // Chain 1: base regs x5..x8, data regs x14..x17
      rs1_idx = {30'b01, 2'($urandom())} + 1;
      rd_idx  = {30'b0, 2'($urandom())} + 14;
      rs2_idx = {30'b0, 2'($urandom())} + 14;
    end

    // Determine which instruction to write

    if (select_inst == 0) begin
      // XOR only mutates data regs, never base pointer regs
      rs1_idx = rs2_idx;
      if (select_chain == 0)
        rs1_idx = {30'b0, 2'($urandom())} + 10;
      else
        rs1_idx = {30'b0, 2'($urandom())} + 14;

      inst = $sformatf("xor x%0d, x%0d, x%0d", rd_idx, rs1_idx, rs2_idx);

      reg_fl[rd_idx] = reg_fl[rs1_idx] & reg_fl[rs2_idx];
    end
    else begin
      addr = reg_fl[rs1_idx];
      // addr is now 0x2000 + offset; convert to mem[] index by subtracting 0x2000 and shifting
      data = mem[((addr - 'h2000) >> 2)];

      inst = $sformatf("lw x%0d, 0(x%0d)", rd_idx, rs1_idx);

      reg_fl[rd_idx] = data;
    end

    reg_tr[i] = rd_idx;
    wdata_tr[i] = reg_fl[rd_idx];

    h.asm(pc, inst);
    pc = pc + 4;
  end

  // Verify traces
  h.check_traces();

  // h.check_trace( 'h000, 1, 'h0000_0100, 1 );
  // h.check_trace( 'h004, 2, 'h0000_0110, 1 );
  // h.check_trace( 'h008, 3, 'h0000_0120, 1 );
  // h.check_trace( 'h00c, 4, 'h0000_0130, 1 );
  // h.check_trace( 'h010, 5, 'h0000_0140, 1 );
  // h.check_trace( 'h014, 6, 'h0000_0150, 1 );
  // h.check_trace( 'h018, 7, 'h0000_0160, 1 );
  // h.check_trace( 'h01c, 8, 'h0000_0170, 1 );

  // for (int i = 0; i < 500; i++) begin
  //   h.check_trace( 'h020 + i*4, reg_tr[i], wdata_tr[i], 1 );
  // end

  h.t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_randomized_lw_tests
//------------------------------------------------------------------------

task run_randomized_lw_tests();
  test_case_randomized_lw_1_offset();
  test_case_randomized_lw_2_chains();
endtask
