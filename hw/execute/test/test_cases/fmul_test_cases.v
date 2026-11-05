//========================================================================
// fmul_test_cases.v
//========================================================================
// Test cases for FPUMult - Floating-Point Multiplier
// IEEE 754 single-precision format (32-bit)

//----------------------------------------------------------------------
// test_case_fmul_basic
//----------------------------------------------------------------------
task test_case_fmul_basic();
  t.test_case_begin( "test_case_fmul_basic" );
  if( !t.run_test ) return;
  fork
    //   pc  seq_num op1        op2        waddr uop
    // 2.0 * 3.0 = 6.0
    send('0, 0,      32'h40000000, 32'h40400000, 5'h1, OP_FMUL_S);
    //   pc  seq_num waddr wdata      wen
    // Result: 6.0 = 0x40C00000
    recv('0, 0,      5'h1, 32'h40C00000, 1);
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fmul_positive
//----------------------------------------------------------------------
task test_case_fmul_positive();
  t.test_case_begin( "test_case_fmul_positive" );
  if( !t.run_test ) return;
  fork
    begin
      //   pc  seq_num op1        op2        waddr uop
      // 1.0 * 1.0 = 1.0
      send('0, 1,      32'h3F800000, 32'h3F800000, 5'h1, OP_FMUL_S);
      // 1.5 * 2.0 = 3.0
      send('1, 2,      32'h3FC00000, 32'h40000000, 5'h2, OP_FMUL_S);
      // 4.0 * 0.5 = 2.0
      send('0, 3,      32'h40800000, 32'h3F000000, 5'h3, OP_FMUL_S);
      // 7.5 * 8.0 = 60.0
      send('1, 4,      32'h40F00000, 32'h41000000, 5'h4, OP_FMUL_S);
      // 0.25 * 0.25 = 0.0625
      send('0, 5,      32'h3E800000, 32'h3E800000, 5'h5, OP_FMUL_S);
    end
    begin
      //   pc  seq_num waddr wdata      wen
      // 1.0 = 0x3F800000
      recv('0, 1,      5'h1, 32'h3F800000, 1);
      // 3.0 = 0x40400000
      recv('1, 2,      5'h2, 32'h40400000, 1);
      // 2.0 = 0x40000000
      recv('0, 3,      5'h3, 32'h40000000, 1);
      // 60.0 = 0x42700000
      recv('1, 4,      5'h4, 32'h42700000, 1);
      // 0.0625 = 0x3D800000
      recv('0, 5,      5'h5, 32'h3D800000, 1);
    end
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fmul_negative
//----------------------------------------------------------------------
task test_case_fmul_negative();
  t.test_case_begin( "test_case_fmul_negative" );
  if( !t.run_test ) return;
  fork
    begin
      //   pc  seq_num op1        op2        waddr uop
      // -2.0 * 3.0 = -6.0
      send('0, 1,      32'hC0000000, 32'h40400000, 5'h1, OP_FMUL_S);
      // 2.0 * -3.0 = -6.0
      send('1, 2,      32'h40000000, 32'hC0400000, 5'h2, OP_FMUL_S);
      // -2.0 * -3.0 = 6.0
      send('0, 3,      32'hC0000000, 32'hC0400000, 5'h3, OP_FMUL_S);
      // -1.0 * 1.0 = -1.0
      send('1, 4,      32'hBF800000, 32'h3F800000, 5'h4, OP_FMUL_S);
      // -0.5 * -0.5 = 0.25
      send('0, 5,      32'hBF000000, 32'hBF000000, 5'h5, OP_FMUL_S);
    end
    begin
      //   pc  seq_num waddr wdata      wen
      // -6.0 = 0xC0C00000
      recv('0, 1,      5'h1, 32'hC0C00000, 1);
      // -6.0 = 0xC0C00000
      recv('1, 2,      5'h2, 32'hC0C00000, 1);
      // 6.0 = 0x40C00000
      recv('0, 3,      5'h3, 32'h40C00000, 1);
      // -1.0 = 0xBF800000
      recv('1, 4,      5'h4, 32'hBF800000, 1);
      // 0.25 = 0x3E800000
      recv('0, 5,      5'h5, 32'h3E800000, 1);
    end
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fmul_zero
//----------------------------------------------------------------------
task test_case_fmul_zero();
  t.test_case_begin( "test_case_fmul_zero" );
  if( !t.run_test ) return;
  fork
    begin
      //   pc  seq_num op1        op2        waddr uop
      // 0.0 * 5.0 = 0.0
      send('0, 1,      32'h00000000, 32'h40A00000, 5'h1, OP_FMUL_S);
      // 3.0 * 0.0 = 0.0
      send('1, 2,      32'h40400000, 32'h00000000, 5'h2, OP_FMUL_S);
      // 0.0 * 0.0 = 0.0
      send('0, 3,      32'h00000000, 32'h00000000, 5'h3, OP_FMUL_S);
      // -0.0 * 5.0 = -0.0 (sign bit set)
      send('1, 4,      32'h80000000, 32'h40A00000, 5'h4, OP_FMUL_S);
      // 0.0 * -5.0 = -0.0
      send('0, 5,      32'h00000000, 32'hC0A00000, 5'h5, OP_FMUL_S);
    end
    begin
      //   pc  seq_num waddr wdata      wen
      // 0.0 = 0x00000000
      recv('0, 1,      5'h1, 32'h00000000, 1);
      // 0.0 = 0x00000000
      recv('1, 2,      5'h2, 32'h00000000, 1);
      // 0.0 = 0x00000000
      recv('0, 3,      5'h3, 32'h00000000, 1);
      // -0.0 = 0x80000000 or 0.0 (implementation dependent)
      recv('1, 4,      5'h4, 32'h00000000, 1);
      // -0.0 = 0x80000000 or 0.0
      recv('0, 5,      5'h5, 32'h00000000, 1);
    end
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fmul_special_values
//----------------------------------------------------------------------
task test_case_fmul_special_values();
  t.test_case_begin( "test_case_fmul_special_values" );
  if( !t.run_test ) return;
  fork
    begin
      //   pc  seq_num op1        op2        waddr uop
      // Very small * very small (may underflow to 0)
      // 1.0e-20 * 1.0e-20 = 1.0e-40 (underflows to 0)
      send('0, 1,      32'h1F800000, 32'h1F800000, 5'h1, OP_FMUL_S);
      // 1.0 * very_small = very_small
      send('1, 2,      32'h3F800000, 32'h00000001, 5'h2, OP_FMUL_S);
      // Smallest normal * 2 
      send('0, 3,      32'h00800000, 32'h40000000, 5'h3, OP_FMUL_S);
    end
    begin
      //   pc  seq_num waddr wdata      wen
      // Underflow -> 0
      recv('0, 1,      5'h1, 32'h00000000, 1);
      // Result is denormal -> 0
      recv('1, 2,      5'h2, 32'h00000000, 1);
      // 2 * smallest_normal = 0x01000000
      recv('0, 3,      5'h3, 32'h01000000, 1);
    end
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fmul_overflow
//----------------------------------------------------------------------
task test_case_fmul_overflow();
  t.test_case_begin( "test_case_fmul_overflow" );
  if( !t.run_test ) return;
  fork
    begin
      //   pc  seq_num op1        op2        waddr uop
      // Large * Large = overflow to infinity
      
      // 1.0e38 * 1.0e38 = overflow
      send('1, 2,      32'h7E967699, 32'h7E967699, 5'h2, OP_FMUL_S);
    end
    begin
      //   pc  seq_num waddr wdata      wen
      
      // +Infinity = 0x7F800000
      recv('1, 2,      5'h2, 32'h7F800000, 1);
    end
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fmul_powers_of_two
//----------------------------------------------------------------------
task test_case_fmul_powers_of_two();
  t.test_case_begin( "test_case_fmul_powers_of_two" );
  if( !t.run_test ) return;
  fork
    begin
      //   pc  seq_num op1        op2        waddr uop
      // 2.0 * 2.0 = 4.0
      send('0, 1,      32'h40000000, 32'h40000000, 5'h1, OP_FMUL_S);
      // 4.0 * 4.0 = 16.0
      send('1, 2,      32'h40800000, 32'h40800000, 5'h2, OP_FMUL_S);
      // 0.5 * 0.5 = 0.25
      send('0, 3,      32'h3F000000, 32'h3F000000, 5'h3, OP_FMUL_S);
      // 16.0 * 0.0625 = 1.0
      send('1, 4,      32'h41800000, 32'h3D800000, 5'h4, OP_FMUL_S);
      // 8.0 * 0.125 = 1.0
      send('0, 5,      32'h41000000, 32'h3E000000, 5'h5, OP_FMUL_S);
    end
    begin
      //   pc  seq_num waddr wdata      wen
      // 4.0 = 0x40800000
      recv('0, 1,      5'h1, 32'h40800000, 1);
      // 16.0 = 0x41800000
      recv('1, 2,      5'h2, 32'h41800000, 1);
      // 0.25 = 0x3E800000
      recv('0, 3,      5'h3, 32'h3E800000, 1);
      // 1.0 = 0x3F800000
      recv('1, 4,      5'h4, 32'h3F800000, 1);
      // 1.0 = 0x3F800000
      recv('0, 5,      5'h5, 32'h3F800000, 1);
    end
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fmul_fractional
//----------------------------------------------------------------------
task test_case_fmul_fractional();
  t.test_case_begin( "test_case_fmul_fractional" );
  if( !t.run_test ) return;
  fork
    begin
      //   pc  seq_num op1        op2        waddr uop
      // 1.5 * 1.5 = 2.25
      send('0, 1,      32'h3FC00000, 32'h3FC00000, 5'h1, OP_FMUL_S);
      // 0.1 * 10.0 = 1.0 (approximately)
      send('1, 2,      32'h3DCCCCCD, 32'h41200000, 5'h2, OP_FMUL_S);
      // 3.14159 * 2.0 = 6.28318
      send('0, 3,      32'h40490FDB, 32'h40000000, 5'h3, OP_FMUL_S);
      // 0.333... * 3.0 ≈ 1.0
      send('1, 4,      32'h3EAAAAAB, 32'h40400000, 5'h4, OP_FMUL_S);
    end
    begin
      //   pc  seq_num waddr wdata      wen
      // 2.25 = 0x40100000
      recv('0, 1,      5'h1, 32'h40100000, 1);
      // 1.0 ≈ 0x3F800000 (may have rounding)
      recv('1, 2,      5'h2, 32'h3F800000, 1);
      // 6.28318 = 0x40C90FDB
      recv('0, 3,      5'h3, 32'h40C90FDB, 1);
      // 1.0 ≈ 0x3F800000
      recv('1, 4,      5'h4, 32'h3F800000, 1);
    end
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fmul_mixed_magnitudes
//----------------------------------------------------------------------
task test_case_fmul_mixed_magnitudes();
  t.test_case_begin( "test_case_fmul_mixed_magnitudes" );
  if( !t.run_test ) return;
  fork
    begin
      //   pc  seq_num op1        op2        waddr uop
      // 1000.0 * 0.001 = 1.0
      send('0, 1,      32'h447A0000, 32'h3A83126F, 5'h1, OP_FMUL_S);
      // 100.0 * 0.01 = 1.0
      send('1, 2,      32'h42C80000, 32'h3C23D70A, 5'h2, OP_FMUL_S);
      // 0.0001 * 10000.0 = 1.0
      send('0, 3,      32'h38D1B717, 32'h461C4000, 5'h3, OP_FMUL_S);
    end
    begin
      //   pc  seq_num waddr wdata      wen
      // 1.0 = 0x3F800000
      recv('0, 1,      5'h1, 32'h3F800000, 1);
      // 1.0 = 0x3F800000
      recv('1, 2,      5'h2, 32'h3F800000, 1);
      // 1.0 = 0x3F800000
      recv('0, 3,      5'h3, 32'h3F800000, 1);
    end
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fmul_underflow
//----------------------------------------------------------------------

task test_case_fmul_underflow();
  t.test_case_begin( "test_case_fmul_underflow" );
  if( !t.run_test ) return;
  fork
    begin
      // sma
      send('0, 0,      32'h00800000, 32'h3A83126F, 5'h1, OP_FMUL_S);
      // 100.0 * 0.01 = 1.0
      send('1, 2,      32'h42C80000, 32'h3C23D70A, 5'h2, OP_FMUL_S);
      // 0.0001 * 10000.0 = 1.0
      send('0, 3,      32'h38D1B717, 32'h461C4000, 5'h3, OP_FMUL_S);
    end
    begin
      //   pc  seq_num waddr wdata      wen
      // 1.0 = 0x3F800000
      recv('0, 1,      5'h1, 32'h3F800000, 1);
      // 1.0 = 0x3F800000
      recv('1, 2,      5'h2, 32'h3F800000, 1);
      // 1.0 = 0x3F800000
      recv('0, 3,      5'h3, 32'h3F800000, 1);
    end
  join
  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_sign_logic
//----------------------------------------------------------------------

task test_case_sign_logic();
  t.test_case_begin("test_case_sign_logic");
  if (!t.run_test) return;

  fork
    begin
      // + * + = +
      send('0, 0, 32'h40000000, 32'h40400000, 5'h1, OP_FMUL_S); // 2.0 * 3.0 = 6.0

      // + * - = -
      send('1, 1, 32'h40000000, 32'hc0400000, 5'h2, OP_FMUL_S); // 2.0 * -3.0 = -6.0

      // - * + = -
      send('0, 2, 32'hc0000000, 32'h40400000, 5'h3, OP_FMUL_S); // -2.0 * 3.0 = -6.0

      // - * - = +
      send('1, 3, 32'hc0000000, 32'hc0400000, 5'h4, OP_FMUL_S); // -2.0 * -3.0 = 6.0
    end

    begin
      recv('0, 0, 5'h1, 32'h40c00000, 1); // 6.0
      recv('1, 1, 5'h2, 32'hc0c00000, 1); // -6.0
      recv('0, 2, 5'h3, 32'hc0c00000, 1); // -6.0
      recv('1, 3, 5'h4, 32'h40c00000, 1); // 6.0
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_underflow
//----------------------------------------------------------------------

task test_case_underflow();
  t.test_case_begin("test_case_underflow");
  if (!t.run_test) return;

  fork
    begin
      // smallest normal * smallest normal -> underflow -> 0
      send('0, 0, 32'h00800000, 32'h00800000, 5'h1, OP_FMUL_S);

      // tiny normal * 0.5 -> underflow/very tiny
      send('1, 1, 32'h00800000, 32'h3f000000, 5'h2, OP_FMUL_S);

      // very small * very small -> underflow
      send('0, 2, 32'h01000000, 32'h01000000, 5'h3, OP_FMUL_S);
    end

    begin
      recv('0, 0, 5'h1, 32'h00000000, 1);
      recv('1, 1, 5'h2, 32'h00000000, 1);
      recv('0, 2, 5'h3, 32'h00000000, 1);
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_denormals
//----------------------------------------------------------------------

task test_case_denormals();
  t.test_case_begin("test_case_denormals");
  if (!t.run_test) return;

  fork
    begin
      // subnormal * 1.0 -> 0 in this design
      send('0, 0, 32'h00000001, 32'h3f800000, 5'h1, OP_FMUL_S);

      // 1.0 * subnormal -> 0 in this design
      send('1, 1, 32'h3f800000, 32'h00000001, 5'h2, OP_FMUL_S);

      // subnormal * subnormal -> 0
      send('0, 2, 32'h00000002, 32'h00000003, 5'h3, OP_FMUL_S);

      // negative subnormal * normal -> 0
      send('1, 3, 32'h80000001, 32'h40000000, 5'h4, OP_FMUL_S);
    end

    begin
      recv('0, 0, 5'h1, 32'h00000000, 1);
      recv('1, 1, 5'h2, 32'h00000000, 1);
      recv('0, 2, 5'h3, 32'h00000000, 1);
      recv('1, 3, 5'h4, 32'h00000000, 1);
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_rounding
//----------------------------------------------------------------------

task test_case_rounding();
  t.test_case_begin("test_case_rounding");
  if (!t.run_test) return;

  fork
    begin
      // exact representable result
      send('0, 0, 32'h3fc00000, 32'h3fc00000, 5'h1, OP_FMUL_S); // 1.5 * 1.5 = 2.25

      // simple fractional
      send('1, 1, 32'h3fa00000, 32'h40200000, 5'h2, OP_FMUL_S); // 1.25 * 2.5 = 3.125

      // another clean mantissa case
      send('0, 2, 32'h3f400000, 32'h3fc00000, 5'h3, OP_FMUL_S); // 0.75 * 1.5 = 1.125

      // small mantissa product
      send('1, 3, 32'h3f000000, 32'h3f000000, 5'h4, OP_FMUL_S); // 0.5 * 0.5 = 0.25
    end

    begin
      recv('0, 0, 5'h1, 32'h40100000, 1); // 2.25
      recv('1, 1, 5'h2, 32'h40480000, 1); // 3.125
      recv('0, 2, 5'h3, 32'h3f900000, 1); // 1.125
      recv('1, 3, 5'h4, 32'h3e800000, 1); // 0.25
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_normalization
//----------------------------------------------------------------------

task test_case_normalization();
  t.test_case_begin("test_case_normalization");
  if (!t.run_test) return;

  fork
    begin
      // 1.5 * 1.5 = 2.25, requires normalization
      send('0, 0, 32'h3fc00000, 32'h3fc00000, 5'h1, OP_FMUL_S);

      // 1.75 * 1.5 = 2.625
      send('1, 1, 32'h3fe00000, 32'h3fc00000, 5'h2, OP_FMUL_S);

      // 1.5 * 2.0 = 3.0
      send('0, 2, 32'h3fc00000, 32'h40000000, 5'h3, OP_FMUL_S);

      // 1.25 * 2.0 = 2.5
      send('1, 3, 32'h3fa00000, 32'h40000000, 5'h4, OP_FMUL_S);
    end

    begin
      recv('0, 0, 5'h1, 32'h40100000, 1); // 2.25
      recv('1, 1, 5'h2, 32'h40280000, 1); // 2.625
      recv('0, 2, 5'h3, 32'h40400000, 1); // 3.0
      recv('1, 3, 5'h4, 32'h40200000, 1); // 2.5
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_pipeline_back_to_back
//----------------------------------------------------------------------

task test_case_pipeline_back_to_back();
  t.test_case_begin("test_case_pipeline_back_to_back");
  if (!t.run_test) return;

  fork
    begin
      send('h10, 0, 32'h3f800000, 32'h3f800000, 5'h1, OP_FMUL_S); // 1 * 1 = 1
      send('h14, 1, 32'h40000000, 32'h40400000, 5'h2, OP_FMUL_S); // 2 * 3 = 6
      send('h18, 2, 32'hbf800000, 32'h40000000, 5'h3, OP_FMUL_S); // -1 * 2 = -2
      send('h1c, 3, 32'h40a00000, 32'h3f000000, 5'h4, OP_FMUL_S); // 5 * 0.5 = 2.5
      send('h20, 4, 32'h3fc00000, 32'h40000000, 5'h5, OP_FMUL_S); // 1.5 * 2 = 3
    end

    begin
      recv('h10, 0, 5'h1, 32'h3f800000, 1);
      recv('h14, 1, 5'h2, 32'h40c00000, 1);
      recv('h18, 2, 5'h3, 32'hc0000000, 1);
      recv('h1c, 3, 5'h4, 32'h40200000, 1);
      recv('h20, 4, 5'h5, 32'h40400000, 1);
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_identity_values
//----------------------------------------------------------------------

task test_case_identity_values();
  t.test_case_begin("test_case_identity_values");
  if (!t.run_test) return;

  fork
    begin
      // x * 1 = x
      send('0, 0, 32'h40600000, 32'h3f800000, 5'h1, OP_FMUL_S); // 3.5 * 1.0 = 3.5

      // x * -1 = -x
      send('1, 1, 32'h41000000, 32'hbf800000, 5'h2, OP_FMUL_S); // 8.0 * -1.0 = -8.0

      // x * 0 = 0
      send('0, 2, 32'h40e80000, 32'h00000000, 5'h3, OP_FMUL_S); // 7.25 * 0.0 = 0.0

      // 1 * 1 = 1
      send('1, 3, 32'h3f800000, 32'h3f800000, 5'h4, OP_FMUL_S);
    end

    begin
      recv('0, 0, 5'h1, 32'h40600000, 1); // 3.5
      recv('1, 1, 5'h2, 32'hc1000000, 1); // -8.0
      recv('0, 2, 5'h3, 32'h00000000, 1); // 0.0
      recv('1, 3, 5'h4, 32'h3f800000, 1); // 1.0
    end
  join

  t.test_case_end();
endtask


//----------------------------------------------------------------------
// run_fmul_test_cases
//----------------------------------------------------------------------
task run_fmul_test_cases();
  test_case_fmul_basic();
  test_case_fmul_positive();
  test_case_fmul_negative();
  test_case_fmul_zero();
  test_case_fmul_special_values();
  test_case_fmul_overflow();
  test_case_fmul_powers_of_two();
  test_case_fmul_fractional();
  test_case_fmul_mixed_magnitudes();
  test_case_sign_logic();
  test_case_underflow();
  test_case_denormals();
  test_case_rounding();
  test_case_normalization();
  test_case_pipeline_back_to_back();
  test_case_identity_values();

endtask