//========================================================================
// fdiv_test_cases.sv
//========================================================================
// Author: Ritika Roy, Alina Lee
//
// NOTE: each test case uses at most 8 transactions (seq_num 0..7) so it
// fits in the 3-bit seq_num suite (suite_3).
//
// NOTE: This file may be obsolute, see fp_div_test_cases.sv for updated test cases
//========================================================================

`ifndef FDIV_TEST_CASES_SV
`define FDIV_TEST_CASES_SV

//----------------------------------------------------------------------
// test_case_fdiv_basic
//----------------------------------------------------------------------

task test_case_fdiv_basic();
  t.test_case_begin("test_case_fdiv_basic");
  if (!t.run_test) return;

  fork
    begin
      //   pc  seq_num op1          op2          waddr uop
      send('0, 0, 32'h40c00000, 32'h40000000, 5'h2, OP_FDIV_S); // 6.0 / 2.0
      send('1, 1, 32'h40a00000, 32'h3f800000, 5'h4, OP_FDIV_S); // 5.0 / 1.0
      send('0, 2, 32'h41200000, 32'h3f000000, 5'h4, OP_FDIV_S); // 10.0 / 0.5
      send('1, 3, 32'h42c80000, 32'h41a00000, 5'h2, OP_FDIV_S); // 100.0 / 20.0
    end

    begin
      //   pc  seq_num waddr wdata        wen
      recv('0, 0, 5'h2, 32'h40400000, 1); // 3.0
      recv('1, 1, 5'h4, 32'h40a00000, 1); // 5.0
      recv('0, 2, 5'h4, 32'h41a00000, 1); // 20.0
      recv('1, 3, 5'h2, 32'h40a00000, 1); // 5.0
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fdiv_rounding
//----------------------------------------------------------------------

task test_case_fdiv_rounding();
  t.test_case_begin("test_case_fdiv_rounding");
  if (!t.run_test) return;

  fork
    begin
      //   pc  seq_num op1          op2          waddr uop
      send('0, 0, 32'h3f800000, 32'h40400000, 5'h1, OP_FDIV_S); // 1.0 / 3.0
      send('1, 1, 32'h40000000, 32'h40400000, 5'h2, OP_FDIV_S); // 2.0 / 3.0
      send('0, 2, 32'h3f800000, 32'h41200000, 5'h3, OP_FDIV_S); // 1.0 / 10.0
      send('1, 3, 32'h3f800000, 32'h40a00000, 5'h4, OP_FDIV_S); // 1.0 / 5.0
      send('0, 4, 32'h42c80000, 32'h40400000, 5'h5, OP_FDIV_S); // 100.0 / 3.0
      send('1, 5, 32'h40a00000, 32'h40400000, 5'h6, OP_FDIV_S); // 5.0 / 3.0
      send('0, 6, 32'h40e00000, 32'h40400000, 5'h7, OP_FDIV_S); // 7.0 / 3.0
      send('1, 7, 32'h3f800001, 32'h3f800000, 5'h8, OP_FDIV_S); // (1+2^-23) / 1.0, exact
    end

    begin
      //   pc  seq_num waddr wdata        wen
      recv('0, 0, 5'h1, 32'h3eaaaaab, 1); // 0.33333334 (round up)
      recv('1, 1, 5'h2, 32'h3f2aaaab, 1); // 0.6666667  (round up)
      recv('0, 2, 5'h3, 32'h3dcccccd, 1); // 0.1        (round up)
      recv('1, 3, 5'h4, 32'h3e4ccccd, 1); // 0.2        (round up)
      recv('0, 4, 5'h5, 32'h42055555, 1); // 33.333332  (round down)
      recv('1, 5, 5'h6, 32'h3fd55555, 1); // 1.6666666  (round down)
      recv('0, 6, 5'h7, 32'h40155555, 1); // 2.3333333  (round down)
      recv('1, 7, 5'h8, 32'h3f800001, 1); // exact
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fdiv_edge
//----------------------------------------------------------------------

task test_case_fdiv_edge();
  t.test_case_begin("test_case_fdiv_edge");
  if (!t.run_test) return;

  fork
    begin
      //   pc  seq_num op1          op2          waddr uop
      send('0, 0, 32'h42c80000, 32'h42c80000, 5'h1, OP_FDIV_S); // 100 / 100
      send('1, 1, 32'h42c80000, 32'h3f800000, 5'h2, OP_FDIV_S); // 100 / 1
      send('0, 2, 32'h3fc00000, 32'h40400000, 5'h3, OP_FDIV_S); // 1.5 / 3.0 (normalize shift)
      send('1, 3, 32'h40a00000, 32'h00000000, 5'h4, OP_FDIV_S); // 5.0 / 0.0
      send('0, 4, 32'h00000000, 32'h40a00000, 5'h5, OP_FDIV_S); // 0.0 / 5.0
      send('1, 5, 32'h00000000, 32'h00000000, 5'h6, OP_FDIV_S); // 0.0 / 0.0
      send('0, 6, 32'h7f7fffff, 32'h3f000000, 5'h7, OP_FDIV_S); // max float / 0.5 (overflow)
      send('1, 7, 32'h00800000, 32'h40800000, 5'h8, OP_FDIV_S); // min normal / 4.0 (underflow)
    end

    begin
      //   pc  seq_num waddr wdata        wen
      recv('0, 0, 5'h1, 32'h3f800000, 1); // 1.0
      recv('1, 1, 5'h2, 32'h42c80000, 1); // 100.0
      recv('0, 2, 5'h3, 32'h3f000000, 1); // 0.5
      recv('1, 3, 5'h4, 32'h7f800000, 1); // +inf   (confirm intended behavior)
      recv('0, 4, 5'h5, 32'h00000000, 1); // 0.0
      recv('1, 5, 5'h6, 32'h7fc00000, 1); // NaN
      recv('0, 6, 5'h7, 32'h7f800000, 1); // +inf
      recv('1, 7, 5'h8, 32'h00000000, 1); // 0.0 (flushed)
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fdiv_subnormal
//----------------------------------------------------------------------
// Assumes subnormal inputs/results are flushed to zero.
//----------------------------------------------------------------------

task test_case_fdiv_subnormal();
  t.test_case_begin("test_case_fdiv_subnormal");
  if (!t.run_test) return;

  fork
    begin
      //   pc  seq_num op1          op2          waddr uop
      // Normal inputs, subnormal result
      send('0, 0, 32'h00800000, 32'h40000000, 5'h1, OP_FDIV_S); // 2^-126 / 2
      send('1, 1, 32'h80800000, 32'h40000000, 5'h2, OP_FDIV_S); // -2^-126 / 2 (keeps sign)
      send('0, 2, 32'h00800000, 32'h7f000000, 5'h3, OP_FDIV_S); // 2^-126 / 2^127

      // Subnormal inputs
      send('1, 3, 32'h00400000, 32'h40000000, 5'h4, OP_FDIV_S); // subnormal / 2
      send('0, 4, 32'h007fffff, 32'h3f800000, 5'h5, OP_FDIV_S); // largest subnormal / 1
      send('1, 5, 32'h3f800000, 32'h00400000, 5'h6, OP_FDIV_S); // 1 / subnormal
      send('0, 6, 32'h00000003, 32'h00000002, 5'h7, OP_FDIV_S); // subnormal / subnormal
      send('1, 7, 32'h80400000, 32'h40000000, 5'h8, OP_FDIV_S); // -subnormal / 2
    end

    begin
      //   pc  seq_num waddr wdata        wen
      recv('0, 0, 5'h1, 32'h00000000, 1); // +0
      recv('1, 1, 5'h2, 32'h80000000, 1); // -0
      recv('0, 2, 5'h3, 32'h00000000, 1); // +0
      recv('1, 3, 5'h4, 32'h00000000, 1); // 0 / 2 = 0
      recv('0, 4, 5'h5, 32'h00000000, 1); // 0 / 1 = 0
      recv('1, 5, 5'h6, 32'h7f800000, 1); // 1 / 0 = +inf
      recv('0, 6, 5'h7, 32'h7fc00000, 1); // 0 / 0 = NaN
      recv('1, 7, 5'h8, 32'h80000000, 1); // -0 / 2 = -0
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_fdiv_test_cases
//----------------------------------------------------------------------

task run_fdiv_test_cases();
  test_case_fdiv_basic();
  test_case_fdiv_rounding();
  // test_case_fdiv_edge();
  // test_case_fdiv_subnormal();
endtask

`endif // FDIV_TEST_CASES_SV