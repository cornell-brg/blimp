//========================================================================
// FDiv.v
//========================================================================
// Single-precision floating-point divider (FDIV.S).
//========================================================================

`ifndef HW_EXECUTE_EXECUTE_UNITS_L8_FDIV_V
`define HW_EXECUTE_EXECUTE_UNITS_L8_FDIV_V

`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"

import UArch::*;


module FPRound (
  input  logic        sign,
  input  logic [7:0]  exp,
  input  logic [23:0] mant,     // HAS IMPLICT 1
  input  logic        guard, round, sticky,
  output logic [31:0] round_result
);
// Guard, the MSB bit that will be dropped, if 0 it is less than 0.5, if 1 it is 0.5 or more
// Round; the 2nd MSB dropped bit, is worth 0.25. Helps break the tie if guard = 1;
// Sticky; the OR result of every bit after, we don't care abt the indiviudal bits, just if atleast one bit is high
// Say we round 3.14159 (PI) to two decimals
// Kept: 3.14
// Guard: 1
// Round: 5
// Sticky: High, b/c 9 is nonzero
// Tell us if what we are throwing away is half, less than half, or exactly half

// step1: Decide to round up or down
// step2 If rounding, add 1 to the mantissa
// step3: adding the 1 could have made our val spill over, i.e 9.99 -> 10.00, need to shift mantissa right, add 1 to exponent
// step4: Check if exponenet is too big or too small (inf or 0)
// step5: repack the value and return it?
// 1.4999 -> 1
// 1.5 -> 2
// 2.5 -> 2 // rounded down for nearest even
// 3.5 -> 4 // rounded up for nearest even
// Check overflow due to rounding, as well as regular overflow from our final result?
// I think we only hae to check once after the round?
  logic        increment; // 1 round up, 0 = round down / drop the bits
  logic [24:0] mant_sum;  // Mantissa after adding inc
  logic [24:0] mant_post; // Mantissa after potentially adjusting for spillover
  logic [9:0]  exp_post;  // Exponenet after potnetially adjusting for spillover
  assign increment = guard && (round || sticky || mant[0]); // mant[0] is the tiebreaker

  // Adjust mantissa and exponent if spillover
  assign mant_sum = mant + increment;
  always_comb begin
    // default vals
    exp_post = {2'b0, exp};
    mant_post = mant_sum;
    if(mant_sum[24] == 1'b1) begin // there was spillover, need to adjust the mantissa and exponent
      mant_post = mant_sum >> 1;
      exp_post = {2'b0, exp} + 1;
    end
    // Overflow / underflow check, after spillover adjustment
    if (exp_post > 10'd254) begin
      round_result = {sign, 8'd255, 23'b0};   // overflow becomes signed inf
    end
    else if (exp_post < 10'd1) begin
      round_result = {sign, 8'd0, 23'b0};     // underflow -> signed zero
    end
    else begin
      round_result = {sign, exp_post[7:0], mant_post[22:0]}; // No overflowm just return the packed result with sign bit, exp, and mantissa
    end
  end



endmodule


module FDiv (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // D <-> X Interface
  //----------------------------------------------------------------------

  D__XIntf.X_intf D,

  //----------------------------------------------------------------------
  // X <-> W Interface
  //----------------------------------------------------------------------

  X__WIntf.X_intf W
);

  localparam p_seq_num_bits   = D.p_seq_num_bits;
  localparam p_phys_addr_bits = D.p_phys_addr_bits;

  //----------------------------------------------------------------------
  // Register inputs
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                        val;
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                 [31:0] op1;
    logic                 [31:0] op2;
    logic                  [4:0] waddr;
    rv_uop                       uop;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
    logic                        is_fp;
  } D_input;

  D_input D_reg, D_reg_next;
  logic   D_xfer, W_xfer;

  always_ff @( posedge clk ) begin
    if ( rst )
      D_reg <= '0;
    else
      D_reg <= D_reg_next;
  end

  always_comb begin
    D_xfer = D.val & D.rdy;
    W_xfer = W.val & W.rdy;

    if ( D_xfer )
      D_reg_next = '{
        val    : 1'b1,
        pc     : D.pc,
        seq_num: D.seq_num,
        op1    : D.op1,
        op2    : D.op2,
        waddr  : D.waddr,
        uop    : D.uop,
        preg   : D.preg,
        ppreg  : D.ppreg,
        is_fp  : D.is_fp
      };
    else if ( W_xfer )
      D_reg_next = '0;
    else
      D_reg_next = D_reg;
  end

  //----------------------------------------------------------------------
  // DIVIDE LOGIC-- PUT ALL UR WORK HERE SHEHROZE!!
  //----------------------------------------------------------------------

  localparam p_expwidth = 8;
  localparam p_frwidth  = 23;
  localparam p_opwidth  = 1 + p_expwidth + p_frwidth;

  // Registers for the calculation stage
  logic [24:0] rem;
  logic [24:0] divisor;
  logic [25:0] quotient;
  logic [4:0]  count;
  logic [24:0] next_rem;
  logic [25:0] next_quotient;
  logic        sticky;
  logic [p_expwidth-1:0] exp_calc;
  logic [p_expwidth-1:0] exp_reg;
  logic sign_reg;
  logic [p_expwidth-1:0] next_exp;
  logic [31:0] result;

  // Special case handling signals
  logic is_special_case; // Will be the select for final output mux, for either the value from special case computation, or normal divison val
  logic [31:0] special_result;
  logic  is_special_case_reg;
  logic [31:0] special_result_reg;


  typedef enum {
    IDLE,
    UNPACK,
    CALC,
    NORMALIZE,
    ROUND,
    DONE
  } div_state_t;

  div_state_t cur_state;
  div_state_t next_state;
  logic calc_done;

  always_ff @( posedge clk ) begin
    if( rst )
      cur_state <= IDLE;
    else
      cur_state <= next_state;
  end
    //D_xfer tells us when a new instruction needs to be loaded in, W_xfer tells us when the output is ready receive.
  always_comb begin
    next_state = cur_state;
    case(cur_state) 
        IDLE: if(D_xfer) next_state = UNPACK;
        UNPACK: begin // If it's a special case, just go straight to done
          if(is_special_case)
            next_state = DONE;
          else
            next_state = CALC;
        end
        CALC: if(calc_done) next_state = NORMALIZE;
        NORMALIZE: next_state = ROUND;
        ROUND: next_state = DONE;
        DONE: begin
            if(W_xfer) begin
                if(D_xfer)
                    next_state = UNPACK; // prevents wasting a cycle as we can go directly to UNPACK
                else
                    next_state = IDLE;
            end
        end
    endcase
  end

  logic sn_dividend; // sign bits
  logic sn_divisor;
  logic [p_expwidth-1:0] exp_dividend; // exponent fields
  logic [p_expwidth-1:0] exp_divisor ;
  logic [p_frwidth-1:0]  fr_dividend ; // raw fraction bits, we haven't added the hidden 1 back yet.
  logic [p_frwidth-1:0]  fr_divisor  ;
  logic [p_frwidth:0] sig_dividend, sig_divisor;
  logic snR_unpack;

  // Special cases to handle:0/0, inf/inf, x/0, inf/x, NaN input, x/inf, 0/x 
  always_comb begin
    // need default values for everything to avoid inferred dlatches
    sn_dividend     = 1'b0;
    sn_divisor      = 1'b0;
    fr_dividend     = '0;
    fr_divisor      = '0;
    exp_dividend    = '0;
    exp_divisor     = '0;
    sig_dividend    = '0;
    sig_divisor     = '0;
    snR_unpack      = 1'b0;
    is_special_case = 1'b0;
    special_result  = 32'b0;

    if(cur_state == UNPACK) begin // Don't think we need this check, as these values won't latch if we aren't in UNPAC
            sn_dividend  = D_reg.op1[p_opwidth-1];
            sn_divisor   = D_reg.op2[p_opwidth-1];
            fr_dividend  = D_reg.op1[p_frwidth-1:0];
            fr_divisor   = D_reg.op2[p_frwidth-1:0];
            exp_dividend = D_reg.op1[p_opwidth-2 -: p_expwidth];
            exp_divisor  = D_reg.op2[p_opwidth-2 -: p_expwidth];
            sig_dividend = {1'b1, fr_dividend};
            sig_divisor  = {1'b1, fr_divisor};
            snR_unpack   = sn_dividend ^ sn_divisor;
            
            // CHECK FOR SPECIAL CASES
            is_special_case = 1;
            special_result = 0;
            // 0 / 0 is NAN
            if(exp_divisor == 0 && fr_divisor == 0 && exp_dividend == 0 && fr_dividend == 0) begin
                special_result = 32'h7FC0_0000; // NaN is exp = 255, and mantissa != 0
            end
            // Divide by zero
            else if(exp_divisor == 0 && fr_divisor == 0) begin // Check the raw fractioanl bits, before we add back the hidden 1
                special_result = {snR_unpack, 8'd255, 23'b0}; // signed infinity
            end // infinity divided by infinity
            else if(exp_divisor == 255 && fr_divisor == 0 && exp_dividend == 255 && fr_dividend == 0) begin
                special_result = 32'h7FC0_0000; // NaN 
            end // infinity / x
            else if(exp_dividend == 255 && fr_dividend == 0) begin
              special_result = {snR_unpack, 8'd255, 23'b0}; // return SIGNED infinity
            end // x / infinty -> signed zero
            else if(exp_divisor == 255 && fr_divisor == 0) begin
                special_result = {snR_unpack, 8'd0, 23'b0}; // signed zero
            end // 0 / x
            else if(exp_dividend == 0 && fr_dividend == 0) begin
                special_result = {snR_unpack, 8'd0, 23'b0}; // signed zero
            end
            else begin
              is_special_case = 0;
            end

    end
  end

  // Update the states of the calculation registers
  always_ff @(posedge clk) begin
      if ( rst ) begin
      rem      <= 25'b0;
      divisor  <= 25'b0;
      quotient <= 26'b0;
      count    <= 5'b0;
    end
    else if ( cur_state == UNPACK ) begin
      rem      <= {1'b0, sig_dividend};
      divisor  <= {1'b0, sig_divisor};
      quotient <= 26'b0;
      count    <= 5'b0;
      exp_reg  <= exp_calc;
      sign_reg <= snR_unpack;
      // need to now latch the special case value/result
      is_special_case_reg <= is_special_case;
      special_result_reg  <= special_result;
    end
    else if ( cur_state == CALC ) begin
      rem      <= next_rem;
      quotient <= next_quotient;
      count    <= count + 1;
    end
    else if ( cur_state == NORMALIZE ) begin
      quotient <= next_quotient_normalized;
      exp_reg  <= next_exp_normalized;
    end
  end

  // Iterative significand division
  assign calc_done = (count == 5'd25);
  assign exp_calc = exp_dividend - exp_divisor + 8'd127; // Add back the exponent normalizaiton
  assign sticky = (rem != 25'b0); // Check the sticky bit
  always_comb begin
    next_rem = rem; // Default values
    next_quotient = quotient;
    if (cur_state == CALC) begin
       if(rem >= divisor) begin
          next_rem = (rem - divisor) << 1;
          next_quotient = {quotient[24:0], 1'b1};
       end
       else begin
          next_rem = rem << 1;
          next_quotient = {quotient[24:0], 1'b0};
       end
    end
  end

  // Our value should now be in between 0.5 and 2. If it is less than 1, we need to shift left by 1, and
  // decrement our exponenet value by one.
  // Our value is less than 1 if MSB is 0
  logic [31:0] round_result;
  FPRound fp_round_inst (
  .sign   (sign_reg),
  .exp    (exp_reg),
  .mant   (quotient[25:2]),
  .guard  (quotient[1]),
  .round  (quotient[0]),
  .sticky (sticky),
  .round_result (round_result)
  );

  logic [25:0] next_quotient_normalized;
  logic [7:0]  next_exp_normalized;
  always_comb begin 
    next_quotient_normalized = quotient;
    next_exp_normalized = exp_calc;
    if(cur_state == NORMALIZE) begin
      if(quotient[25] == 1'b0) begin
        next_quotient_normalized = quotient << 1;
        next_exp_normalized = exp_calc - 1;
      end
    end
  end

  always_comb begin // Final result selection,
    if(is_special_case_reg)
      result = special_result_reg;
    else
      result = round_result;
  end



  // TODO: register the sign bit (snr_unpack) so it is stored and avaialble in ROUND
  // TODO: in ROUND, hook up FPround with sign/exp/mantissa/guard/round/sticky, output goes to result
  // TODO: fix wen, shouldn't just be 1
  // TODO: handle special cases (NaN/inf/zero/div0), they'd skip straight to DONE
  // TODO: hook into blimp (interface, writeback sel, ..? check what telse

  // Exceptions


  //----------------------------------------------------------------------
  // Outputs
  //----------------------------------------------------------------------

  assign D.rdy = W.rdy | !D_reg.val;
  assign W.val = D_reg.val;

  assign W.pc      = D_reg.pc;
  assign W.seq_num = D_reg.seq_num;
  assign W.waddr   = D_reg.waddr;
  assign W.preg    = D_reg.preg;
  assign W.ppreg   = D_reg.ppreg;
  assign W.is_fp   = D_reg.is_fp;
  assign W.wen     = D_reg.val;
  assign W.wdata   = result;

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  int str_len;
  assign str_len = ceil_div_4(p_seq_num_bits) + 2 + // seq_num
                   ceil_div_4(5)              + 1 + // waddr
                   8                          + 1 + // op1
                   8                          + 1 + // op2
                   8;                               // wdata

  function string trace( int trace_level );
    if ( W.val & W.rdy ) begin
      if ( trace_level > 0 )
        trace = $sformatf("%h:%h:%h:%h:%h", W.seq_num,
                          W.waddr, D_reg.op1, D_reg.op2, W.wdata);
      else
        trace = $sformatf("%h", W.seq_num);
    end else begin
      if ( trace_level > 0 )
        trace = {str_len{" "}};
      else
        trace = {(ceil_div_4(p_seq_num_bits)){" "}};
    end
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_UNITS_L8_FDIV_V

