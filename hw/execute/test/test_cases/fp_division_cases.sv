//========================================================================
// fp_test_cases.v
//========================================================================
// Author: Alina Lee, Ritika Roy
//========================================================================

`ifndef FP_TEST_CASES_V
`define FP_TEST_CASES_V

//----------------------------------------------------------------------
// test_case_fp_basic
//----------------------------------------------------------------------
// Float division test cases
//----------------------------------------------------------------------
task test_case_fp_basic();
  t.test_case_begin("test_case_fp_basic");
  if (!t.run_test) return;
  fork
    begin
      //   pc  seq_num op1     op2     waddr uop
      send('0, 0,      32'h40c00000,  32'h40000000,  5'h2, OP_FDIV_S); // 6.0 / 2.0 = 3.0
      send('1, 1,      32'h40a00000,  32'h3f800000,  5'h4, OP_FDIV_S); // 5.0 + 1.0 = 5.0
      send('0, 2,      32'h41200000,  32'h3f000000,  5'h4, OP_FDIV_S); // 10.0 / 0.5 = 2.0
      send('1, 3,      32'h42c80000,  32'h41a00000,  5'h2, OP_FDIV_S); // 100.0 / 20.0 = 5.0
      
    end

    begin
      //   pc  seq_num waddr wdata        wen
      recv('0, 0,      5'h2,  32'h40400000, 1); // 3.0
      recv('1, 1,      5'h4,  32'h40a00000, 1); // 5.0
      recv('0, 2,      5'h4,  32'h41a00000, 1); // 20.0
      recv('1, 3,      5'h2,  32'h40a00000, 1); // 5.0
      
    end

  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fp_rounding
//----------------------------------------------------------------------

task test_case_fp_rounding();
  t.test_case_begin("test_case_fp_rounding");
  if (!t.run_test) return;

  fork
    begin
      //   pc  seq_num op1     op2     waddr uop
      //Round up
      send('0, 0, 32'h3f800000, 32'h40400000, 5'h2, OP_FDIV_S); // 1.0  / 3.0
      send('1, 1, 32'h40000000, 32'h40400000, 5'h2, OP_FDIV_S); // 2.0  / 3.0
      send('0, 2, 32'h3f800000, 32'h41200000, 5'h3, OP_FDIV_S); // 1.0 / 10.0
      send('1, 3, 32'h3f800000, 32'h40a00000, 5'h4, OP_FDIV_S); // 1.0 / 5.0
      
      // Checks rounding up
      send('0, 6, 32'h42c800000, 32'h40400000, 5'h5, OP_FDIV_S); // 1.0 + 2^-23
      send('1, 5, 32'h40a00000, 32'h40400000, 5'h6, OP_FDIV_S); // 5.0 / 3.0
      send('0, 6, 32'h40e00000, 32'h40400000, 5'h7, OP_FDIV_S); // 7.0 / 3.0
    
      // Exact answer, NO rounding needed (should stay clean)
      send('1, 7, 32'h3f800001, 32'h3f800000, 5'h8, OP_FDIV_S); // 1.0000001 / 1.0

    end

    begin 
      //   pc  seq_num waddr wdata          wen
      // Round UP
      recv('0, 0, 5'h1, 32'h3eaaaaab, 1); // 0.33333334
      recv('1, 1, 5'h2, 32'h3f2aaaab, 1); // 0.6666667
      recv('0, 2, 5'h3, 32'h3dcccccd, 1); // 0.1
      recv('1, 3, 5'h4, 32'h3e4ccccd, 1); // 0.2

      // Round DOWN
      recv('0, 4, 5'h5, 32'h42055555, 1); // 33.333332
      recv('1, 5, 5'h6, 32'h3fd55555, 1); // 1.6666666
      recv('0, 6, 5'h7, 32'h40155555, 1); // 2.3333333

      // Exact
      recv('1, 7, 5'h8, 32'h3f800001, 1); // 1.0000001
    end

  join

  t.test_case_end();
endtask

task test_case_edge();
  t.test_case_begin("test_case_edge");
  if (!t.run_test) return;

  fork
    begin
      //   pc  seq_num waddr wdata          wen

      // Number divided by itseof (100.0 / 100.0)
      send('0, 0, 32'h42c80000, 32'h42c80000, 5'h1, OP_FDIV_S);

      // Number divided by 1.0 (100.0 / 1.0)
      send('1, 1, 32'h42c80000, 32'h3f800000, 5'h2, OP_FDIV_S);  

      // Number divided by smaller than dividsor NORMALIZE shift (1.5 / 3.0)
      send('0, 2, 32'h3fc00000, 32'h40400000, 5'h3, OP_FDIV_S); 

      // Divide by zero = infinity (ASK ABOUT BEHAVIOR NAN or Infinity) (5.0 / 0.0)
      send('1, 3, 32'h40a00000, 32'h00000000, 5'h4, OP_FDIV_S); 

      // Zero divided by a number = zero (0.0 / 5.0)
      send('0, 4, 32'h00000000, 32'h40a00000, 5'h5, OP_FDIV_S); 

      // Zero divided by zero = NaN (0.0 / 0.0)
      send('1, 5, 32'h00000000, 32'h00000000, 5'h6, OP_FDIV_S); 

      // Result too big = infinity overflow (2^31 - 2^23 - 1 / 0.5 = OVERFLOW)
      send('0, 6, 32'h7f7fffff, 32'h3f000000, 5'h7, OP_FDIV_S); // biggest float / 0.5

      // Result too small = zero underflow (smallest normal / 4.0)
      send('1, 7, 32'h00800000, 32'h40800000, 5'h8, OP_FDIV_S); // smallest normal / 4.0
    end

    begin
      //   pc  seq_num waddr wdata          wen
      recv('0, 0, 5'h1, 32'h3f800000, 1); // 1.0
      recv('1, 1, 5'h2, 32'h42c80000, 1); // 100.0
      recv('0, 2, 5'h3, 32'h3f000000, 1); // 0.5
      recv('1, 3, 5'h4, 32'h7f800000, 1); // +infinity (ASK)
      recv('0, 4, 5'h5, 32'h00000000, 1); // 0.0
      recv('1, 5, 5'h6, 32'h7fc00000, 1); // NaN
      recv('0, 6, 5'h7, 32'h7f800000, 1); // +infinity (ASK)
      recv('1, 7, 5'h8, 32'h00000000, 1); // 0.0

    end

  join

t.test_case_end();
endtask


task test_case_fp_subnormal();
  t.test_case_begin("test_fp_subnormal");
  if(!t.run_test) return;


  fork
    begin
      //   pc  seq_num op1           op2           waddr uop

      // Group 1: normal inputs, result is too small (should already pass)
      send('0, 0, 32'h00800000, 32'h40000000, 5'h1, OP_FDIV_S); // 2^-126 / 2
      send('1, 1, 32'h00800000, 32'h40800000, 5'h2, OP_FDIV_S); // 2^-126 / 4
      send('0, 2, 32'h80800000, 32'h40000000, 5'h3, OP_FDIV_S); // -2^-126 / 2 (keeps the minus sign)
      send('1, 3, 32'h00800000, 32'h7f000000, 5'h4, OP_FDIV_S); // 2^-126 / 2^127, far too small

      // Group 2: subnormal inputs (will fail until the RTL fix below)
      send('0, 4, 32'h00400000, 32'h40000000, 5'h5, OP_FDIV_S); // subnormal / 2
      send('1, 5, 32'h007fffff, 32'h3f800000, 5'h6, OP_FDIV_S); // largest subnormal / 1
      send('0, 6, 32'h3f800000, 32'h00400000, 5'h7, OP_FDIV_S); // 1 / subnormal
      send('1, 7, 32'h00000003, 32'h00000002, 5'h8, OP_FDIV_S); // subnormal / subnormal
      send('0, 8, 32'h80400000, 32'h40000000, 5'h9, OP_FDIV_S); // -subnormal / 2
    end

    begin
      //   pc  seq_num waddr wdata          wen
      // Group 1
      recv('0, 0, 5'h1, 32'h00000000, 1); // flushed to +0
      recv('1, 1, 5'h2, 32'h00000000, 1); // flushed to +0
      recv('0, 2, 5'h3, 32'h80000000, 1); // flushed to -0
      recv('1, 3, 5'h4, 32'h00000000, 1); // +0

      // Group 2 (subnormal inputs treated as zero)
      recv('0, 4, 5'h5, 32'h00000000, 1); // 0 / 2 = 0
      recv('1, 5, 5'h6, 32'h00000000, 1); // 0 / 1 = 0
      recv('0, 6, 5'h7, 32'h7f800000, 1); // 1 / 0 = +inf
      recv('1, 7, 5'h8, 32'h7fc00000, 1); // 0 / 0 = NaN
      recv('0, 8, 5'h9, 32'h80000000, 1); // -0 / 2 = -0
    end
  join
  t.test_case_end();

  t.test_case_begin("test_case_zero_operand");
if (!t.run_test) return;

fork

  begin
    /*
    // --------------------------
    // POS_SMALL + ZERO
    // --------------------------
    send(1, '0, 32'h00000001, 32'h00000000, 5'h1, OP_FADD_S);

    // --------------------------
    // POS_MEDIUM + ZERO
    // --------------------------
    send(2, '0, 32'h00010000, 32'h00000000, 5'h2, OP_FADD_S);

    // --------------------------
    // NEG_SMALL + ZERO
    // --------------------------
    send(3, '0, 32'h80000001, 32'h00000000, 5'h3, OP_FADD_S);

    // --------------------------
    // NEG_MEDIUM + ZERO
    // --------------------------
    send(4, '0, 32'h80010000, 32'h00000000, 5'h4, OP_FADD_S);
    */
end

begin
    // --------------------------
    // Recv Results
    // --------------------------
    /*
    recv(1, '0, 5'h1, 32'h00000001, 1); // pos_small + 0 = pos_small
    recv(2, '0, 5'h2, 32'h00010000, 1); // pos_medium + 0 = pos_medium
    recv(3, '0, 5'h3, 32'h80000001, 1); // neg_small + 0 = neg_small
    recv(4, '0, 5'h4, 32'h80010000, 1); // neg_medium + 0 = neg_medium
    */
end

join

t.test_case_end();

endtask


task test_case_fp_normal();
t.test_case_begin("t_fp_pos_neg");
  if(!t.run_test) return;

  fork
    begin
        /*
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      // pos (10.5) + neg (−2.25) = 8.25
      send('h0000_0020, 0, 32'h41280000, 32'hC0200000, 5'h1, OP_FADD_S);

      // pos (3.0) + neg (−10.0) = −7.0
      send('h0000_0024, 1, 32'h40400000, 32'hC1200000, 5'h2, OP_FADD_S);

      // pos (5.0) + neg (−5.0) = 0.0
      send('h0000_0028, 2, 32'h40A00000, 32'hC0A00000, 5'h3, OP_FADD_S);
      */
    end

    begin
        /*
      recv('h0000_0020, 0, 5'h1, 32'h41040000, 1); // 8.25
      recv('h0000_0024, 1, 5'h2, 32'hC0E00000, 1); // −7.0
      recv('h0000_0028, 2, 5'h3, 32'h00000000, 1); // +0.0
      */
    end
  join

  t.test_case_end();

t.test_case_begin("test_case_fp_grs_bits");
  if (!t.run_test) return;

  fork
    //====================================================================
    // Send Thread
    //====================================================================
    begin
      //------------------------------------------------------------------
      // BASELINE: 1.0 (0x3F800000)
      // Exponent = 127.
      // We vary Op2 to shift bits into GRS positions.
      //------------------------------------------------------------------

      // 1. GRS = 000 (Exact fit, no rounding)
      // 1.0 + 1.0*2^-10 (Shift 10) -> Fits inside 23-bit mantissa
      // Exp: 127-10 = 117 (0x75) -> 0x3A800000
     // send('h0000_0030, 0, 32'h3F800000, 32'h3A800000, 5'h1, OP_FADD_S);

      // 2. GRS = 010 (Guard=0, Round=1, Sticky=0) -> Round Down (Truncate)
      // 1.0 + 1.0*2^-25 (Shift 25)
      // Exp: 127-25 = 102 (0x66) -> 0x33000000
    //  send('h0000_0034, 1, 32'h3F800000, 32'h33000000, 5'h2, OP_FADD_S);

      // 3. GRS = 011 (Guard=0, Round=1, Sticky=1) -> Round Up
      // 1.0 + (1.0 + epsilon)*2^-25
      // We use 0x33000001 so the LSB contributes to Sticky
      //send('h0000_0038, 2, 32'h3F800000, 32'h33000001, 5'h3, OP_FADD_S);

      //------------------------------------------------------------------
      // TIE-BREAKING CASES (Guard=1, Round=0, Sticky=0)
      //------------------------------------------------------------------

      // 4. GRS = 100, LSB=0 (Tie -> Round to Even -> Stay 0)
      // Op1: 1.5 (0x3FC00000) - LSB is 0
      // Op2: 1.0*2^-24 (Shift 24 relative to 1.5's Exp 127)
      // Exp: 127-24 = 103 (0x67) -> 0x33800000
     // send('h0000_003C, 3, 32'h3FC00000, 32'h33800000, 5'h4, OP_FADD_S);

      // 5. GRS = 100, LSB=1 (Tie -> Round to Even -> Round Up +1)
      // Op1: 1.5 + 1ULP (0x3FC00001) - LSB is 1
      // Op2: Same as above (0x33800000)
     // send('h0000_0040, 4, 32'h3FC00001, 32'h33800000, 5'h5, OP_FADD_S);

      //------------------------------------------------------------------
      // REMAINING COMBINATIONS
      //------------------------------------------------------------------

      // 6. GRS = 101 (Guard=1, Sticky=1) -> Round Up
      // Shift 24. Op2 needs sticky bit. 0x33800001
      //send('h0000_0044, 5, 32'h3F800000, 32'h33800001, 5'h6, OP_FADD_S);

      // 7. GRS = 110 (Guard=1, Round=1) -> Round Up
      // Shift 24. We need Mantissa 0.5 (Binary 1.1)
      // Op2: 1.5 * 2^-24. Hex 0x33C00000
      //send('h0000_0048, 6, 32'h3F800000, 32'h33C00000, 5'h7, OP_FADD_S);

      // 8. GRS = 111 (All 1s) -> Round Up
      // Shift 24. Mantissa 0.5 + epsilon. 0x33C00001
      //send('h0000_004C, 7, 32'h3F800000, 32'h33C00001, 5'h8, OP_FADD_S);
    end

    //====================================================================
    // Receive Thread
    //====================================================================
    begin
        /*
      // 1. GRS=000
      recv('h0000_0030, 0, 5'h1, 32'h3F800400, 1); // Exact sum

      // 2. GRS=010 (Round Down)
      recv('h0000_0034, 1, 5'h2, 32'h3F800000, 1); // Stays 1.0

      // 3. GRS=011 (Round Up)
      recv('h0000_0038, 2, 5'h3, 32'h3F800001, 1); // 1.0 + 1ulp

      // 4. GRS=100, LSB=0 (Tie -> Even)
      recv('h0000_003C, 3, 5'h4, 32'h3FC00000, 1); // Stays 1.5

      // 5. GRS=100, LSB=1 (Tie -> Even -> Up)
      recv('h0000_0040, 4, 5'h5, 32'h3FC00002, 1); // 1.5...1 -> 1.5...2

      // 6. GRS=101 (Round Up)
      recv('h0000_0044, 5, 5'h6, 32'h3F800001, 1);

      // 7. GRS=110 (Round Up)
      recv('h0000_0048, 6, 5'h7, 32'h3F800001, 1);

      // 8. GRS=111 (Round Up)
      recv('h0000_004C, 7, 5'h8, 32'h3F800001, 1);
      */
    end
  join
  t.test_case_end();

  t.test_case_begin("t_fp_exponent differences");
  if(!t.run_test) return;

  fork
    begin
     /*
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      // large exp diff: 2^125 + 2^5 ≈ 2^125 (alignment drop)
      send('h0000_0050, 0, 32'h5E800000, 32'h41000000, 5'h1, OP_FADD_S);
      // exps 23 vs 56
      send('h0000_0054, 1, 32'h4B000000, 32'h4E800000, 5'h2, OP_FADD_S);
      // exps 1 vs 100
      send('h0000_0058, 2, 32'h3F800000, 32'h57000000, 5'h3, OP_FADD_S);
      // equal exps : no alignment shift
      send('h0000_005C, 3, 32'h41C00000, 32'h41A00000, 5'h4, OP_FADD_S); 
      */     
    end

    begin
        /*
      recv('h0000_0050, 0, 5'h1, 32'h5E800000, 1);
      recv('h0000_0054, 1, 5'h2, 32'h4E800000, 1);
      recv('h0000_0058, 2, 5'h3, 32'h57000000, 1);
      recv('h0000_005C, 3, 5'h4, 32'h42300000, 1); // 24.0 + 20.0 = 44.0
      */

    end
  join

  t.test_case_end();
endtask

task test_case_fp_extremes();
t.test_case_begin("t_fp_overflow");
  if(!t.run_test) return;

  fork
    begin
        /*
     
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      // max normal + max normal → +inf
      send('h0000_0060, 0, 32'h7F7FFFFF, 32'h7F7FFFFF, 5'h1, OP_FADD_S);
      */
    end

    begin
      //recv('h0000_0060, 0, 5'h1, 32'h7F800000, 1); // +inf
    end
  join

  t.test_case_end();

t.test_case_begin("t_fp_underflow");
  if(!t.run_test) return;

  fork
    begin
        /*
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      // smallest negative subnormal + smallest negative subnormal -> underflow -> −0.0
      send('h0000_0064, 0, 32'h807FFFFF, 32'h807FFFFF, 5'h1, OP_FADD_S);
      */
    end

    begin
      //recv('h0000_0064, 0, 5'h1, 32'h80000000, 1); // −0.0
    end
  join

  t.test_case_end();

  t.test_case_begin("t_fp_nan");
  if(!t.run_test) return;

  fork
    begin
     /*
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      // NaN + number = NaN
      send('h0000_0068, 0, 32'h7FC00000, 32'h3F800000, 5'h1, OP_FADD_S);
      // +inf - inf = NaN
      send('h0000_006C, 1, 32'h7F800000, 32'hFF800000, 5'h2, OP_FADD_S);
      */

    end

    begin
      //recv('h0000_0068, 0, 5'h1, 32'h7FC00000, 1);
      //recv('h0000_006C, 1, 5'h2, 32'h7FC00000, 1);
    end
  join

  t.test_case_end();

  t.test_case_begin("t_fp_inf");
  if(!t.run_test) return;

  fork
    begin
     
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      // inf + inf = inf
      //send('h0000_0070, 0, 32'h7F800000, 32'h7F800000, 5'h1, OP_FADD_S);

      // −inf − inf = −inf
     // send('h0000_0074, 1, 32'hFF800000, 32'hFF800000, 5'h2, OP_FADD_S);
    end

    begin    
      //recv('h0000_0070, 0, 5'h1, 32'h7F800000, 1);
      //recv('h0000_0074, 1, 5'h2, 32'hFF800000, 1);
    end
  join

  t.test_case_end();
endtask



//----------------------------------------------------------------------
// run_fp_test_cases
//----------------------------------------------------------------------

task run_fp_test_cases();
  test_case_fp_basic();
  test_case_fp_rounding();
  // test_case_edge();
  // test_case_subtraction();
  // test_case_fp_subnormal();
  // test_case_fp_extremes();
  // test_case_fp_normal();
endtask

`endif // FP_TEST_CASES_V


