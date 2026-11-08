//========================================================================
// fp_test_cases.sv
//========================================================================
// Author: Sumaia Jewena, Rohan Kalluraya
//========================================================================
// Coverage:
//   - Normalized addition/subtraction
//   - Exponent alignment (small/large deltas)
//   - Sign handling
//   - Normalization (left/right shifts)
//   - Guard/Round/Sticky rounding (RNE)
//   - Tie-to-even behavior
//   - Subnormal operands
//   - Zero and signed zero
//   - Overflow to infinity
//   - Underflow handling
//   - NaN propagation
//   - Random differential testing (C reference model)
//
// Rounding Mode: Round to Nearest, Ties to Even (RNE)
// ================================================================
`ifndef FP_TEST_CASES_SV
`define FP_TEST_CASES_SV


// Import the C functions via DPI
import "DPI-C" function int c_gold_fadd(int a, int b);
import "DPI-C" function int c_gold_fsub(int a, int b);

//----------------------------------------------------------------------
// test_case_fp_basic
//----------------------------------------------------------------------
// Integer addition test cases
//----------------------------------------------------------------------

task test_case_fp_basic();
  t.test_case_begin("test_case_fp_basic");
  if (!t.run_test) return;

  //Testing OP_FADD_S
  fork
    begin
      //   pc  seq_num op1     op2     waddr uop
      send('0, 0,      32'h3f800000,  32'h40000000,  5'h1, OP_FADD_S); 
      // 1.0 + 2.0 = 3.0
      send('1, 1,      32'h40b00000,  32'h40100000,  5'h4, OP_FADD_S); 
      // 5.5 + 2.25 = 7.75
      send('0, 2,      32'h41200000,  32'h3f000000,  5'h4, OP_FADD_S); 
      // 10.0 + 0.5 = 10.5
      send('1, 3,      32'h42c80000,  32'h41a00000,  5'h2, OP_FADD_S); 
      // 100.0 + 20.0 = 120.0
    end

    begin
      //   pc  seq_num waddr wdata        wen
      recv('0, 0,      5'h1,  32'h40400000, 1); // 3.0
      recv('1, 1,      5'h4,  32'h40f80000, 1); // 7.75
      recv('0, 2,      5'h4,  32'h41280000, 1); // 10.5
      recv('1, 3,      5'h2,  32'h42f00000, 1); // 120.0
    end

  join

  //Testing OP_FSUB_S
  fork
    begin
      // Case 5: 1.0 - (-2.0) = 3.0
      // 32'h40000000 -> 32'hC0000000
      send('h4, 4, 32'h3f800000, 32'hC0000000, 5'h5, OP_FSUB_S); 

      // Case 6: 5.5 - (-2.25) = 7.75
      // 32'h40100000 -> 32'hC0100000
      send('h5, 5, 32'h40b00000, 32'hC0100000, 5'h6, OP_FSUB_S); 

      // Case 7: 10.0 - (-0.5) = 10.5
      // 32'h3f000000 -> 32'hBf000000
      send('h6, 6, 32'h41200000, 32'hBf000000, 5'h7, OP_FSUB_S); 

      // Case 8: 100.0 - (-20.0) = 120.0
      // 32'h41a00000 -> 32'hC1a00000
      send('h7, 7, 32'h42c80000, 32'hC1a00000, 5'h8, OP_FSUB_S); 
    end

    begin
      // Expected results match the original additions since A - (-B) = A + B
      recv('h4, 4, 5'h5, 32'h40400000, 1); // 3.0
      recv('h5, 5, 5'h6, 32'h40f80000, 1); // 7.75
      recv('h6, 6, 5'h7, 32'h41280000, 1); // 10.5
      recv('h7, 7, 5'h8, 32'h42f00000, 1); // 120.0
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_fp_rounding
//----------------------------------------------------------------------

task test_case_fp_rounding();

  //Testing OP_FADD_S

  t.test_case_begin("test_case_fp_rounding_grs");
  if (!t.run_test) return;

  fork
    begin
      // GRS 110: Greater than halfway -> Round UP
      send('1, 1, 32'h3F000003, 32'h40400000, 5'h10, OP_FADD_S); 
      
      // GRS 111: Greater than halfway -> Round UP
      send('1, 3, 32'h3E800007, 32'h40400000, 5'h12, OP_FADD_S); 
      
      // GRS 101: Greater than halfway (sticky set) -> Round UP
      send('1, 4, 32'h3E800005, 32'h40400000, 5'h13, OP_FADD_S); 

      // GRS 011: Less than halfway -> Round DOWN (Truncate)
      send('1, 2, 32'h3E800003, 32'h40400000, 5'h11, OP_FADD_S); 
      
      // GRS 110: Greater than halfway -> Round UP
      send('1, 5, 32'h3E800006, 32'h40400000, 5'h14, OP_FADD_S); 
    end

    begin 
      recv('1, 1, 5'h10, 32'h40600001, 1); 
      recv('1, 3, 5'h12, 32'h40500001, 1); 
      recv('1, 4, 5'h13, 32'h40500001, 1); 
      recv('1, 2, 5'h11, 32'h40500000, 1); 
      recv('1, 5, 5'h14, 32'h40500001, 1); 
    end
  join

  //Testing OP_FSUB_S

  fork
    begin
      // Using '0 (PC=0) and '1 (PC=7) with seq_nums 0 through 4
      send('0, 0, 32'h3F000003, 32'hC0400000, 5'h10, OP_FSUB_S); 
      
      send('1, 1, 32'h3E800007, 32'hC0400000, 5'h12, OP_FSUB_S); 
      
      send('0, 2, 32'h3E800005, 32'hC0400000, 5'h13, OP_FSUB_S); 
      
      send('1, 3, 32'h3E800003, 32'hC0400000, 5'h11, OP_FSUB_S); 
      
      send('0, 4, 32'h3E800006, 32'hC0400000, 5'h14, OP_FSUB_S); 
    end

    begin 
      // Matching PC values and seq_nums (0, 1, 2, 3, 4)
      recv('0, 0, 5'h10, 32'h40600001, 1); 
      recv('1, 1, 5'h12, 32'h40500001, 1); 
      recv('0, 2, 5'h13, 32'h40500001, 1); 
      recv('1, 3, 5'h11, 32'h40500000, 1); 
      recv('0, 4, 5'h14, 32'h40500001, 1); 
    end
  join

  t.test_case_end();

  t.test_case_begin("test_case_fp_rounding_ties");
  if (!t.run_test) return;

  fork
    begin
      // Case 1: GRS = 100, LSB is 1 -> Round UP to even
      send('1, 0, 32'h3E000008, 32'h40400001, 5'h15, OP_FADD_S); 
      
      // Case 2: GRS = 100, LSB is 0 -> Round DOWN to even (Tie-break)
      send('1, 1, 32'h3E000008, 32'h40400000, 5'h16, OP_FADD_S); 
      
      // Case 3: GRS = 010 -> Round DOWN (less than halfway)
      send('1, 2, 32'h3E000004, 32'h40400000, 5'h17, OP_FADD_S); 
      
      // Case 4: GRS = 011 -> Round DOWN (less than halfway)
      send('1, 3, 32'h3E000005, 32'h40400000, 5'h18, OP_FADD_S); 
      
      // Case 5: GRS = 011 -> Round DOWN (less than halfway)
      send('1, 4, 32'h3E000006, 32'h40400000, 5'h19, OP_FADD_S); 
      
      // Case 6: GRS = 001 -> Round DOWN (less than halfway)
      send('1, 5, 32'h3E000002, 32'h40400000, 5'h1A, OP_FADD_S); 
    end

    begin 
      // Expected results based on GRS bit analysis
      recv('1, 0, 5'h15, 32'h40480002, 1); // Case 1: Rounded up
      recv('1, 1, 5'h16, 32'h40480000, 1); // Case 2: Tie-break to even
      recv('1, 2, 5'h17, 32'h40480000, 1); // Case 3: Truncated
      recv('1, 3, 5'h18, 32'h40480000, 1); // Case 4: Truncated
      recv('1, 4, 5'h19, 32'h40480000, 1); // Case 5: Truncated
      recv('1, 5, 5'h1A, 32'h40480000, 1); // Case 6: Truncated
    end
  join

  //Subtraction

  fork
    begin
      // Case 1: GRS = 100, LSB is 1 -> Round UP to even
      // 32'h40400001 -> 32'hC0400001
      send('h1, 0, 32'h3E000008, 32'hC0400001, 5'h15, OP_FSUB_S); 
      
      // Case 2: GRS = 100, LSB is 0 -> Round DOWN to even (Tie-break)
      // 32'h40400000 -> 32'hC0400000
      send('h2, 1, 32'h3E000008, 32'hC0400000, 5'h16, OP_FSUB_S); 
      
      // Case 3: GRS = 010 -> Round DOWN
      send('h3, 2, 32'h3E000004, 32'hC0400000, 5'h17, OP_FSUB_S); 
      
      // Case 4: GRS = 011 -> Round DOWN
      send('h4, 3, 32'h3E000005, 32'hC0400000, 5'h18, OP_FSUB_S); 
      
      // Case 5: GRS = 011 -> Round DOWN
      send('h5, 4, 32'h3E000006, 32'hC0400000, 5'h19, OP_FSUB_S); 
      
      // Case 6: GRS = 001 -> Round DOWN
      send('h6, 5, 32'h3E000002, 32'hC0400000, 5'h1A, OP_FSUB_S); 
    end

    begin 
      // Results are identical to the addition counterparts
      recv('h1, 0, 5'h15, 32'h40480002, 1); // Rounded up
      recv('h2, 1, 5'h16, 32'h40480000, 1); // Tie-break to even (Truncated)
      recv('h3, 2, 5'h17, 32'h40480000, 1); // Truncated
      recv('h4, 3, 5'h18, 32'h40480000, 1); // Truncated
      recv('h5, 4, 5'h19, 32'h40480000, 1); // Truncated
      recv('h6, 5, 5'h1A, 32'h40480000, 1); // Truncated
    end
  join

  t.test_case_end();
endtask

task test_case_edge();
  t.test_case_begin("test_case_edge");
  if (!t.run_test) return;

  fork
    begin
      send('0, 0, 32'h3f800000, 32'hbf7fffff, 5'h1, OP_FADD_S); // 1.0 + (-0.99999994)

      // One input dominates; tests right-shift alignment path
      send('1, 1, 32'h42c80000, 32'h00000001, 5'h4, OP_FADD_S); // 100.0 + 1e-20 

      // Mantissa overflow; normalization after addition pushes result to next exponent
      send('0, 2, 32'h3F000003, 32'h405FFFFF, 5'h4, OP_FADD_S); // 0.5000002 + 3.4999998

      // Mantisa underflow; forces left-shift normalization
      send('1, 3, 32'h00800000, 32'h00400000, 5'h2, OP_FADD_S); // smallest normals
    end

    begin
      recv('0, 0,      5'h1, 32'h33800000, 1); // ~2^-24

      // One input dominates; tests right-shift alignment path
      recv('1, 1,      5'h4, 32'h42c80000, 1); // 100.0 

      // Mantissa overflow
      recv('0, 2,      5'h4, 32'h40800000, 1); // 4.0

      // Mantissa underflow
      recv('1, 3,      5'h2, 32'h00c00000, 1);

    end

  join

  //Subtraction

  fork
    begin
      // Case 0: Almost subtracting equal numbers (became 1.0 - 0.99999994)
      send('0, 0, 32'h3f800000, 32'h3f7fffff, 5'h1, OP_FSUB_S); 

      // Case 1: One input dominates (became 100.0 - (-1e-20))
      send('1, 1, 32'h42c80000, 32'h80000001, 5'h4, OP_FSUB_S); 

      // Case 2: Mantissa overflow (became 0.5000002 - (-3.4999998))
      send('0, 2, 32'h3F000003, 32'hC05FFFFF, 5'h4, OP_FSUB_S); 

      // Case 3: Mantissa underflow (became smallest normal - (-smaller normal))
      send('1, 3, 32'h00800000, 32'h80400000, 5'h2, OP_FSUB_S); 
    end

    begin
      // Recv blocks remain identical as the mathematical results are the same
      recv('0, 0,      5'h1, 32'h33800000, 1); // ~2^-24
      recv('1, 1,      5'h4, 32'h42c80000, 1); // 100.0 
      recv('0, 2,      5'h4, 32'h40800000, 1); // 4.0
      recv('1, 3,      5'h2, 32'h00c00000, 1);
    end
  join

t.test_case_end();
endtask

task test_case_exponent_differences ();
  t.test_case_begin("test_case_exponent_differences");
  if(!t.run_test) return;

  fork
    begin
      // POS MEDIUM + NEG SMALL
      //   pc  seq_num op1            op2            waddr uop
      send('0, 0,      32'h36800000,  32'h81800000,  5'h1, OP_FADD_S); //3.8146973E-6 - 4.7019774E-38

      
      send('1, 1,      32'h40b00000,  32'h40100000,  5'h4, OP_FADD_S); // 5.5 + 2.25 = 7.75

    end
    begin
      //   pc  seq_num waddr wdata        wen
      recv('0, 0,      5'h1,  32'h36800000, 1); // 3.8146973E-6
      recv('1, 1,      5'h4,  32'h40f80000, 1); // 7.75
    end
  join

  //Subtraction

  fork
    begin
      // Case 0: POS MEDIUM - POS SMALL (Result remains ~3.8146973E-6)
      // Sign bit of op2 changed from 8 (1000) to 0 (0000)
      send('0, 0,      32'h36800000,  32'h01800000,  5'h1, OP_FSUB_S); 

      // Case 1: 5.5 - (-2.25) = 7.75
      // Sign bit of op2 changed from 4 (0100) to C (1100)
      send('1, 1,      32'h40b00000,  32'hc0100000,  5'h4, OP_FSUB_S); 
    end

    begin
      // Results remain identical to the FADD version
      recv('0, 0,      5'h1,  32'h36800000, 1); // 3.8146973E-6
      recv('1, 1,      5'h4,  32'h40f80000, 1); // 7.75
    end
  join

  t.test_case_end();
endtask

task test_case_overflow();
  t.test_case_begin("test_case_overflow");
  if(!t.run_test) return;

  fork
    begin
      //   pc        seq_num  op1(hex)       op2(hex)       waddr  uop
      
      // 1. Max Normal + Max Normal -> +Inf (Your original case)
      send('h0000_0060, 0, 32'h7F7FFFFF, 32'h7F7FFFFF, 5'h1, OP_FADD_S);
      
      // 2. Norm + Inf -> +Inf
      send('h0000_0064, 1, 32'h40000000, 32'h7F800000, 5'h2, OP_FADD_S); // 2.0 + Inf
      
      // 3. Inf + Norm -> +Inf
      send('h0000_0068, 2, 32'h7F800000, 32'h40A00000, 5'h3, OP_FADD_S); // Inf + 5.0
      
      // 4. Inf + Inf -> +Inf
      send('h0000_006C, 3, 32'h7F800000, 32'h7F800000, 5'h4, OP_FADD_S);
    end

    begin
      //   pc        seq_num  waddr  expected_data  expected_flags
      recv('h0000_0060, 0, 5'h1, 32'h7F800000, 1); // Expected +Inf, Overflow flag set
      recv('h0000_0064, 1, 5'h2, 32'h7F800000, 1); // Expected +Inf, No new overflow (already Inf)
      recv('h0000_0068, 2, 5'h3, 32'h7F800000, 1); // Expected +Inf
      recv('h0000_006C, 3, 5'h4, 32'h7F800000, 1); // Expected +Inf
    end
  join

  //Subraction

  fork
    begin
      //   pc        seq_num  op1(hex)       op2(hex)       waddr  uop
      
      // 1. Max Normal - (-Max Normal) -> +Inf
      // 7F7FFFFF (Pos) - FF7FFFFF (Neg)
      send('h0000_0060, 0, 32'h7F7FFFFF, 32'hFF7FFFFF, 5'h1, OP_FSUB_S);
      
      // 2. Norm - (-Inf) -> +Inf
      // 40000000 (2.0) - FF800000 (-Inf)
      send('h0000_0064, 1, 32'h40000000, 32'hFF800000, 5'h2, OP_FSUB_S);
      
      // 3. Inf - (-Norm) -> +Inf
      // 7F800000 (Inf) - C0A00000 (-5.0)
      send('h0000_0068, 2, 32'h7F800000, 32'hC0A00000, 5'h3, OP_FSUB_S);
      
      // 4. Inf - (-Inf) -> +Inf
      // 7F800000 (Inf) - FF800000 (-Inf)
      send('h0000_006C, 3, 32'h7F800000, 32'hFF800000, 5'h4, OP_FSUB_S);
    end

    begin
      // Results and flags remain identical to the FADD version
      recv('h0000_0060, 0, 5'h1, 32'h7F800000, 1); 
      recv('h0000_0064, 1, 5'h2, 32'h7F800000, 1); 
      recv('h0000_0068, 2, 5'h3, 32'h7F800000, 1); 
      recv('h0000_006C, 3, 5'h4, 32'h7F800000, 1); 
    end
  join

  t.test_case_end();
endtask

task test_case_zero();
  t.test_case_begin("test_case_zero_operand");
if (!t.run_test) return;

fork

  begin
    // --------------------------
    // SUBNORM + ZERO
    // --------------------------
    send(1, '0, 32'h00000001, 32'h00000000, 5'h1, OP_FADD_S);

    // --------------------------
    // SUBNORM + ZERO
    // --------------------------
    send(2, '0, 32'h00010000, 32'h00000000, 5'h2, OP_FADD_S);

    // --------------------------
    // NEG_SMALL + ZERO
    // --------------------------
    send(3, '0, 32'h87000001, 32'h00000000, 5'h3, OP_FADD_S);

    // --------------------------
    // NEG SUBNORM + ZERO
    // --------------------------
    send(4, '0, 32'h80010000, 32'h00000000, 5'h4, OP_FADD_S);

    // --------------------------
    // ZERO + POS_SMALL
    // --------------------------
    send(5, '0, 32'h00000000, 32'h07000000, 5'h5, OP_FADD_S);
end

begin
    // --------------------------
    // Recv Results
    // --------------------------
    recv(1, '0, 5'h1, 32'h00000001, 1); // pos_small + 0 = pos_small
    recv(2, '0, 5'h2, 32'h00010000, 1); // pos_medium + 0 = pos_medium
    recv(3, '0, 5'h3, 32'h87000001, 1); // neg_small + 0 = neg_small
    recv(4, '0, 5'h4, 32'h80010000, 1); // neg_medium + 0 = neg_medium
    recv(5, '0, 5'h5, 32'h07000000, 1); // 0 + pos_small = pos_small
end

join

t.test_case_end();

endtask


task test_case_fp_normal();
t.test_case_begin("t_fp_pos_neg");
  if(!t.run_test) return;

  fork
    begin
     
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      // pos (10.5) + neg (−2.25) = 8.25
      send('h0000_0020, 0, 32'h41280000, 32'hC0200000, 5'h1, OP_FADD_S);

      // pos (3.0) + neg (−10.0) = −7.0
      send('h0000_0024, 1, 32'h40400000, 32'hC1200000, 5'h2, OP_FADD_S);

      // pos (5.0) + neg (−5.0) = 0.0
      send('h0000_0028, 2, 32'h40A00000, 32'hC0A00000, 5'h3, OP_FADD_S);
      
    end

    begin
      recv('h0000_0020, 0, 5'h1, 32'h41040000, 1); // 8.25
      recv('h0000_0024, 1, 5'h2, 32'hC0E00000, 1); // −7.0
      recv('h0000_0028, 2, 5'h3, 32'h00000000, 1); // +0.0
    end
  join

  //Subtraction

  fork
    begin
        // -------------------------------------------------------
        // POS_SMALL - ZERO (Identity)
        // -------------------------------------------------------
        send(1, '0, 32'h00000001, 32'h00000000, 5'h1, OP_FSUB_S);

        // -------------------------------------------------------
        // POS_MEDIUM - ZERO (Identity)
        // -------------------------------------------------------
        send(2, '0, 32'h00010000, 32'h00000000, 5'h2, OP_FSUB_S);

        // -------------------------------------------------------
        // NEG_SMALL - ZERO (Identity)
        // -------------------------------------------------------
        send(3, '0, 32'h80000001, 32'h00000000, 5'h3, OP_FSUB_S);

        // -------------------------------------------------------
        // NEG_MEDIUM - ZERO (Identity)
        // -------------------------------------------------------
        send(4, '0, 32'h80010000, 32'h00000000, 5'h4, OP_FSUB_S);
    end

    begin
        // -------------------------------------------------------
        // Recv Results (Unchanged)
        // -------------------------------------------------------
        recv(1, '0, 5'h1, 32'h00000001, 1); 
        recv(2, '0, 5'h2, 32'h00010000, 1); 
        recv(3, '0, 5'h3, 32'h80000001, 1); 
        recv(4, '0, 5'h4, 32'h80010000, 1); 
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
      send('h0000_0030, 0, 32'h3F800000, 32'h3A800000, 5'h1, OP_FADD_S);

      // 2. GRS = 010 (Guard=0, Round=1, Sticky=0) -> Round Down (Truncate)
      // 1.0 + 1.0*2^-25 (Shift 25)
      // Exp: 127-25 = 102 (0x66) -> 0x33000000
      send('h0000_0034, 1, 32'h3F800000, 32'h33000000, 5'h2, OP_FADD_S);

      // 3. GRS = 011 (Guard=0, Round=1, Sticky=1) -> Round Up
      // 1.0 + (1.0 + epsilon)*2^-25
      // We use 0x33000001 so the LSB contributes to Sticky
      send('h0000_0038, 2, 32'h3F800000, 32'h33000001, 5'h3, OP_FADD_S);

      //------------------------------------------------------------------
      // TIE-BREAKING CASES (Guard=1, Round=0, Sticky=0)
      //------------------------------------------------------------------

      // 4. GRS = 100, LSB=0 (Tie -> Round to Even -> Stay 0)
      // Op1: 1.5 (0x3FC00000) - LSB is 0
      // Op2: 1.0*2^-24 (Shift 24 relative to 1.5's Exp 127)
      // Exp: 127-24 = 103 (0x67) -> 0x33800000
      send('h0000_003C, 3, 32'h3FC00000, 32'h33800000, 5'h4, OP_FADD_S);

      // 5. GRS = 100, LSB=1 (Tie -> Round to Even -> Round Up +1)
      // Op1: 1.5 + 1ULP (0x3FC00001) - LSB is 1
      // Op2: Same as above (0x33800000)
      send('h0000_0040, 4, 32'h3FC00001, 32'h33800000, 5'h5, OP_FADD_S);

      //------------------------------------------------------------------
      // REMAINING COMBINATIONS
      //------------------------------------------------------------------

      // 6. GRS = 101 (Guard=1, Sticky=1) -> Round Up
      // Shift 24. Op2 needs sticky bit. 0x33800001
      send('h0000_0044, 5, 32'h3F800000, 32'h33800001, 5'h6, OP_FADD_S);

      // 7. GRS = 110 (Guard=1, Round=1) -> Round Up
      // Shift 24. We need Mantissa 0.5 (Binary 1.1)
      // Op2: 1.5 * 2^-24. Hex 0x33C00000
      send('h0000_0048, 6, 32'h3F800000, 32'h33C00000, 5'h7, OP_FADD_S);

      // 8. GRS = 111 (All 1s) -> Round Up
      // Shift 24. Mantissa 0.5 + epsilon. 0x33C00001
      send('h0000_004C, 7, 32'h3F800000, 32'h33C00001, 5'h8, OP_FADD_S);
    end

    //====================================================================
    // Receive Thread
    //====================================================================
    begin
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
    end
  join

  //Subtraction

  fork
    //====================================================================
    // Send Thread: Subtraction with Negative Op2 (Effective Addition)
    //====================================================================
    begin
      // 1. GRS = 000 (Exact fit)
      // 1.0 - (-1.0*2^-10)
      send('h0000_0030, 0, 32'h3F800000, 32'hBA800000, 5'h1, OP_FSUB_S);

      // 2. GRS = 010 (Round Down / Truncate)
      // 1.0 - (-1.0*2^-25)
      send('h0000_0034, 1, 32'h3F800000, 32'hB3000000, 5'h2, OP_FSUB_S);

      // 3. GRS = 011 (Round Up)
      // 1.0 - (-(1.0 + eps)*2^-25)
      send('h0000_0038, 2, 32'h3F800000, 32'hB3000001, 5'h3, OP_FSUB_S);

      // 4. GRS = 100, LSB=0 (Tie -> Round to Even)
      send('h0000_003C, 3, 32'h3FC00000, 32'hB3800000, 5'h4, OP_FSUB_S);

      // 5. GRS = 100, LSB=1 (Tie -> Round to Even -> Up)
      send('h0000_0040, 4, 32'h3FC00001, 32'hB3800000, 5'h5, OP_FSUB_S);

      // 6. GRS = 101 (Round Up)
      send('h0000_0044, 5, 32'h3F800000, 32'hB3800001, 5'h6, OP_FSUB_S);

      // 7. GRS = 110 (Round Up)
      send('h0000_0048, 6, 32'h3F800000, 32'hB3C00000, 5'h7, OP_FSUB_S);

      // 8. GRS = 111 (Round Up)
      send('h0000_004C, 7, 32'h3F800000, 32'hB3C00001, 5'h8, OP_FSUB_S);
    end

    //====================================================================
    // Receive Thread: Results are identical to FADD
    //====================================================================
    begin
      recv('h0000_0030, 0, 5'h1, 32'h3F800400, 1); 
      recv('h0000_0034, 1, 5'h2, 32'h3F800000, 1); 
      recv('h0000_0038, 2, 5'h3, 32'h3F800001, 1); 
      recv('h0000_003C, 3, 5'h4, 32'h3FC00000, 1); 
      recv('h0000_0040, 4, 5'h5, 32'h3FC00002, 1); 
      recv('h0000_0044, 5, 5'h6, 32'h3F800001, 1);
      recv('h0000_0048, 6, 5'h7, 32'h3F800001, 1);
      recv('h0000_004C, 7, 5'h8, 32'h3F800001, 1);
    end
  join

  t.test_case_end();

  t.test_case_begin("t_fp_exponent differences");
  if(!t.run_test) return;

  fork
    begin
     
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      // large exp diff: 2^125 + 2^5 ≈ 2^125 (alignment drop)
      send('h0000_0050, 0, 32'h5E800000, 32'h41000000, 5'h1, OP_FADD_S);
      // exps 23 vs 56
      send('h0000_0054, 1, 32'h4B000000, 32'h4E800000, 5'h2, OP_FADD_S);
      // exps 1 vs 100
      send('h0000_0058, 2, 32'h3F800000, 32'h57000000, 5'h3, OP_FADD_S);
      // equal exps : no alignment shift
      send('h0000_005C, 3, 32'h41C00000, 32'h41A00000, 5'h4, OP_FADD_S);      
    end

    begin
      recv('h0000_0050, 0, 5'h1, 32'h5E800000, 1);
      recv('h0000_0054, 1, 5'h2, 32'h4E800000, 1);
      recv('h0000_0058, 2, 5'h3, 32'h57000000, 1);
      recv('h0000_005C, 3, 5'h4, 32'h42300000, 1); // 24.0 + 20.0 = 44.0

    end
  join

  //Subtraction
  
  fork
    begin
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      
      // 1. Large exp diff: 2^125 - (-2^5)
      // Change 32'h41000000 -> 32'hC1000000
      send('h0000_0050, 0, 32'h5E800000, 32'hC1000000, 5'h1, OP_FSUB_S);

      // 2. Exps 23 vs 56: Small - (-Large)
      // Change 32'h4E800000 -> 32'hCE800000
      send('h0000_0054, 1, 32'h4B000000, 32'hCE800000, 5'h2, OP_FSUB_S);

      // 3. Exps 1 vs 100: Small - (-Large)
      // Change 32'h57000000 -> 32'hD7000000
      send('h0000_0058, 2, 32'h3F800000, 32'hD7000000, 5'h3, OP_FSUB_S);

      // 4. Equal exps: 24.0 - (-20.0) = 44.0
      // Change 32'h41A00000 -> 32'hC1A00000
      send('h0000_005C, 3, 32'h41C00000, 32'hC1A00000, 5'h4, OP_FSUB_S);      
    end

    begin
      // Expected results remain exactly the same as the FADD cases
      recv('h0000_0050, 0, 5'h1, 32'h5E800000, 1);
      recv('h0000_0054, 1, 5'h2, 32'h4E800000, 1);
      recv('h0000_0058, 2, 5'h3, 32'h57000000, 1);
      recv('h0000_005C, 3, 5'h4, 32'h42300000, 1); // Result is 44.0
    end
  join

  t.test_case_end();
endtask

task test_case_fp_extremes();

t.test_case_begin("t_fp_underflow");
  if(!t.run_test) return;

  fork
    begin
      // Smallest negative subnormal + Smallest negative subnormal
      send('h0000_0064, 0, 32'h807FFFFF, 32'h807FFFFF, 5'h1, OP_FADD_S); 

      // // 1. Positive denormal + Negative denormal (Close to zero)
      // // Result: Should be a tiny denormal or signed zero
      send('h0000_0068, 1, 32'h00000001, 32'h80000002, 5'h2, OP_FADD_S);

      // Positive subnormal + Negative subnormal 
      // Result: Tiny negative -> Flushed to Negative Zero
      send('h0000_006C, 2, 32'h01000000, 32'h81000001, 5'h3, OP_FADD_S);

      // Small normal minus a large subnormal (leading to underflow)
      // Op1: 00800000 (Smallest normal)
      // Op2: 007FFFFF (Largest subnormal)
      // Op: FSUB_S
      send('h0000_0070, 3, 32'h00800000, 32'h007FFFFF, 5'h4, OP_FSUB_S);

      // Op1: 007FFFFF (Largest subnormal)
      // Op2: 00800000 (Smallest normal)
      // Op: FSUB_S
      // Result: Tiny negative value -> Flushed to Negative Zero
      send('h0000_0074, 4, 32'h007FFFFF, 32'h00800000, 5'h5, OP_FSUB_S);
      
    end

    begin
      // PC 64: Negative Normal
      recv('h0000_0064, 0, 5'h1, 32'h80FFFFFE, 1); 
      
      // // PC 68: Result is effectively 0.0 or a very small negative denormal
      recv('h0000_0068, 1, 5'h2, 32'h80000000, 1); //answer is F5000000

      // Expecting Negative Zero 
      recv('h0000_006C, 2, 5'h3, 32'h80000000, 1);

      // PC 70: Expecting positive zero (32'h00000000) and underflow=1
      recv('h0000_0070, 3, 5'h4, 32'h00000000, 1); //Result is 75000000

      // PC 74: Expecting negative zero (32'h80000000) and underflow=1
      recv('h0000_0074, 4, 5'h5, 32'h80000000, 1); //Result is F5000000
    end
  join

  //Subtraction

  fork
    begin
      // 0. Smallest negative subnormal - (+Smallest negative subnormal)
      // Result: Effectively Addition (807FFFFF + 807FFFFF)
      // Sign bit of op2 changed from 8 to 0
      send('h0000_0064, 0, 32'h807FFFFF, 32'h007FFFFF, 5'h1, OP_FSUB_S); 

      // 1. Positive denormal - (+Negative denormal)
      // Result: Effectively Addition (00000001 + 80000002)
      // Sign bit of op2 changed from 8 to 0
      send('h0000_0068, 1, 32'h00000001, 32'h00000002, 5'h2, OP_FSUB_S);

      // 2. Positive subnormal - (+Negative subnormal)
      // Result: Effectively Addition (01000000 + 81000001)
      // Sign bit of op2 changed from 8 to 0
      send('h0000_006C, 2, 32'h01000000, 32'h01000001, 5'h3, OP_FSUB_S);

      // 3. Small normal minus a large subnormal (leading to underflow)
      // Already FSUB_S, kept as is to test identity subtraction path
      send('h0000_0070, 3, 32'h00800000, 32'h007FFFFF, 5'h4, OP_FSUB_S);

      // 4. Largest subnormal minus smallest normal
      // Already FSUB_S, kept as is
      send('h0000_0074, 4, 32'h007FFFFF, 32'h00800000, 5'h5, OP_FSUB_S);
    end

    begin
      // Results remain consistent with the original logic
      recv('h0000_0064, 0, 5'h1, 32'h80FFFFFE, 1); 
      recv('h0000_0068, 1, 5'h2, 32'h80000000, 1); 
      recv('h0000_006C, 2, 5'h3, 32'h80000000, 1);
      recv('h0000_0070, 3, 5'h4, 32'h00000000, 1); 
      recv('h0000_0074, 4, 5'h5, 32'h80000000, 1); 
    end
  join

  t.test_case_end();

  t.test_case_begin("t_fp_nan");
  if(!t.run_test) return;

  fork
    begin
      //   pc        seq_num  op1(hex)       op2(hex)  waddr  uop
      // NaN + number = NaN
      send('h0000_0068, 0, 32'h7FC00000, 32'h3F800000, 5'h1, OP_FADD_S);
      // +inf - inf = NaN
      send('h0000_006C, 1, 32'h7F800000, 32'hFF800000, 5'h2, OP_FADD_S);
      
      // Number + NaN = NaN
      send('h0000_0070, 2, 32'h3F800000, 32'h7FC00000, 5'h3, OP_FADD_S);
    end

    begin
      recv('h0000_0068, 0, 5'h1, 32'h7FC00000, 1); // Expect NaN, Invalid flag
      recv('h0000_006C, 1, 5'h2, 32'h7FC00000, 1); // Expect NaN, Invalid flag
      recv('h0000_0070, 2, 5'h3, 32'h7FC00000, 1); // Expect NaN, Invalid flag
    end
  join

  //Subtraction

  fork
    begin
      // 0. NaN - number = NaN
      // 32'h7FC00000 (NaN) - 32'h3F800000 (1.0)
      send('h0000_0068, 0, 32'h7FC00000, 32'h3F800000, 5'h1, OP_FSUB_S);

      // 1. +inf - (+inf) = NaN
      // To get the same "Invalid" result as (+inf + -inf), we subtract like signs.
      // Changed 32'hFF800000 (-inf) -> 32'h7F800000 (+inf)
      send('h0000_006C, 1, 32'h7F800000, 32'h7F800000, 5'h2, OP_FSUB_S);
      
      // 2. Number - NaN = NaN
      // 32'h3F800000 (1.0) - 32'h7FC00000 (NaN)
      send('h0000_0070, 2, 32'h3F800000, 32'h7FC00000, 5'h3, OP_FSUB_S);
    end

    begin
      // Expected results remain the same: Quiet NaN and Invalid Operation flag
      recv('h0000_0068, 0, 5'h1, 32'h7FC00000, 1); 
      recv('h0000_006C, 1, 5'h2, 32'h7FC00000, 1); 
      recv('h0000_0070, 2, 5'h3, 32'h7FC00000, 1); 
    end
  join

  t.test_case_end();

endtask

task test_case_fp_random(input int num_tests);

  // Pre-generate outside the fork
  logic [31:0] ops1 [1024];
  logic [31:0] ops2 [1024];
  logic [31:0] exps [1024];

  t.test_case_begin("test_case_fp_random");
  if (!t.run_test) return;

  for (int i = 0; i < num_tests; i++) begin
    ops1[i] = $urandom();
    ops2[i] = $urandom();
    exps[i] = c_gold_fadd(ops1[i], ops2[i]);
  end

  fork
    begin
      for (int i = 0; i < num_tests; i++) begin
        automatic int addr = 'h0000_0068 + (32'(i) * 4);
        automatic logic [8:0] seq = i[8:0];
        /* verilator lint_off WIDTHTRUNC */
        send(addr, seq, ops1[i], ops2[i], 5'h1, OP_FADD_S);
        /* verilator lint_on WIDTHTRUNC */
      end
    end
    begin
      for (int i = 0; i < num_tests; i++) begin
        automatic int addr = 'h0000_0068 + (32'(i) * 4);
        automatic logic [8:0] seq = i[8:0];
        /* verilator lint_off WIDTHTRUNC */
        recv(addr, seq, 5'h1, exps[i], 1);
        /* verilator lint_on WIDTHTRUNC */
      end
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
  test_case_edge();
  test_case_exponent_differences();
  test_case_zero();
  test_case_overflow();
  test_case_fp_extremes();
  test_case_fp_random(500); //can't be more than 1024

endtask

`endif // FP_TEST_CASES_SV

