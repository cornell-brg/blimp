//========================================================================
// IterativeMulDivRemL7.v
//========================================================================
// An iterative unit capable of computing a multiply, division, or
// remainder

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L7_ITERATIVEMULDIVREML7_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L7_ITERATIVEMULDIVREML7_V

`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"

import UArch::*;

//------------------------------------------------------------------------
// IterativeMulDivRemStepL7
//------------------------------------------------------------------------
// Computes one "step" of the multiplication, based on our operation

module IterativeMulDivRemStepL7 (
  input  logic [63:0] a,
  input  logic [63:0] b,
  input  logic [32:0] b_shift, // Used for division/remainder
  input  rv_uop       uop,
  input  logic [63:0] result,

  output logic [63:0] next_a,
  output logic [63:0] next_b,
  output logic [32:0] next_b_shift,
  output logic [63:0] next_result,
  output logic        done
);

  logic [63:0] abs_a;       // Absolute value of a
  logic [63:0] adj_b;       // Value of b to take from a
  logic [63:0] adj_b_shift; // Value to add to the result

  always_comb begin
    if( a[63] ) begin
      abs_a       = ~a + 1;
      adj_b       = ~b + 1;
      adj_b_shift = ~{31'b0, b_shift} + 1;
    end else begin
      abs_a       = a;
      adj_b       = b;
      adj_b_shift = {31'b0, b_shift};
    end
  end
  
  always_comb begin
    case( uop )
      OP_MUL:    next_a = a << 1;
      OP_MULH:   next_a = a << 1;
      OP_MULHU:  next_a = a << 1;
      OP_MULHSU: next_a = a << 1;
      OP_DIV:    next_a = ( abs_a >= b ) ? a - adj_b : a;
      OP_DIVU:   next_a = (     a >= b ) ? a - b     : a;
      OP_REM:    next_a = ( abs_a >= b ) ? a - adj_b : a;
      OP_REMU:   next_a = (     a >= b ) ? a - b     : a;
      default:   next_a = 'x;
    endcase
  end

  always_comb begin
    case( uop )
      OP_MUL:    next_b = b >> 1;
      OP_MULH:   next_b = b >> 1;
      OP_MULHU:  next_b = b >> 1;
      OP_MULHSU: next_b = b >> 1;
      OP_DIV:    next_b = b >> 1;
      OP_DIVU:   next_b = b >> 1;
      OP_REM:    next_b = b >> 1;
      OP_REMU:   next_b = b >> 1;
      default:   next_b = 'x;
    endcase
  end

  always_comb begin
    next_b_shift = b_shift >> 1;
  end

  always_comb begin
    case( uop )
      OP_MUL:    next_result = ( b[0] ) ? result + a : result;
      OP_MULH:   next_result = ( b[0] ) ? result + a : result;
      OP_MULHU:  next_result = ( b[0] ) ? result + a : result;
      OP_MULHSU: next_result = ( b[0] ) ? result + a : result;
      OP_DIV:    next_result = ( abs_a >= b ) ? result + adj_b_shift        : result;
      OP_DIVU:   next_result = (     a >= b ) ? result | { 31'b0, b_shift } : result; // Same as addition (one-hot)
      OP_REM:    next_result = next_a;
      OP_REMU:   next_result = next_a;
      default:   next_result = 'x;
    endcase

    // Handling divide-by-zero
    if( b == '0 ) begin
      case( uop )
        OP_DIV:  next_result = {64{1'b1}};
        OP_DIVU: next_result = {64{1'b1}};
        OP_REM:  next_result = a;
        OP_REMU: next_result = a;
        default: begin end // Don't change
      endcase
    end

    // // Handling overflow
    // if( ( b[63:32] == 'hffffffff ) & ( a[31:0] == 'h80000000) ) begin
    //   case( uop )
    //     OP_DIV: next_result = {32'b0, 'h80000000};
    //     OP_REM: next_result = '0;
    //     default: begin end // Don't change
    //   endcase
    // end
  end

  always_comb begin
    case( uop )
      OP_MUL:    done = ( next_b == '0 );
      OP_MULH:   done = ( next_b == '0 );
      OP_MULHU:  done = ( next_b == '0 );
      OP_MULHSU: done = ( next_b == '0 );
      OP_DIV:    done = ( next_b_shift == '0 ) | ( next_a == '0 );
      OP_DIVU:   done = ( next_b_shift == '0 ) | ( next_a == '0 );
      OP_REM:    done = ( next_b_shift == '0 ) | ( next_a == '0 );
      OP_REMU:   done = ( next_b_shift == '0 ) | ( next_a == '0 );
      default:   done = 'x;
    endcase

    // Handling divide-by-zero
    if( b == '0 ) begin
      case( uop )
        OP_DIV:  done = 1'b1;
        OP_DIVU: done = 1'b1;
        OP_REM:  done = 1'b1;
        OP_REMU: done = 1'b1;
        default: begin end // Don't change
      endcase
    end

    // // Handling overflow
    // if( ( b[63:32] == 'hffffffff ) & ( a[31:0] == 'h80000000) ) begin
    //   case( uop )
    //     OP_DIV: done = 1'b1;
    //     OP_REM: done = 1'b1;
    //     default: begin end // Don't change
    //   endcase
    // end
  end
endmodule

//------------------------------------------------------------------------
// IterativeMulDivRemL7
//------------------------------------------------------------------------

module IterativeMulDivRemL7 (
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
    logic                  [4:0] waddr;
    rv_uop                       uop;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
    logic                        is_fp;
  } D_input;

  typedef struct packed {
    logic                      val;
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
  } W_input;

  D_input D_reg;
  D_input D_reg_next;
  logic   D_xfer;
  logic   W_xfer;

  // verilator lint_off ENUMVALUE

  //synopsys sync_set_reset "rst"
  always_ff @( posedge clk ) begin
    if ( rst )
      D_reg <= '{ 
        val:     1'b0, 
<<<<<<< HEAD
        pc:      '0,
        seq_num: '0,
        waddr:   '0,
        uop:     rv_uop'('0),
        preg:    '0,
        ppreg:   '0
=======
        pc:      'x,
        seq_num: 'x,
        waddr:   'x,
        uop:     'x,
        preg:    'x,
        ppreg:   'x,
        is_fp:   1'b0
>>>>>>> origin/blimp-v9-infra/rtl
      };
    else
      D_reg <= D_reg_next;
  end

  always_comb begin
    D_xfer = D.val & D.rdy;
    W_xfer = W.val & W.rdy;

    if ( D_xfer )
      D_reg_next = '{ 
        val:     1'b1, 
        pc:      D.pc,
        seq_num: D.seq_num,
        waddr:   D.waddr,
        uop:     D.uop,
        preg:    D.preg,
        ppreg:   D.ppreg,
        is_fp:   D.is_fp
      };
    else if ( W_xfer )
      D_reg_next = '{ 
        val:     1'b0, 
<<<<<<< HEAD
        pc:      '0,
        seq_num: '0,
        waddr:   '0,
        uop:     rv_uop'('0),
        preg:    '0,
        ppreg:   '0
=======
        pc:      'x,
        seq_num: 'x,
        waddr:   'x,
        uop:     'x,
        preg:    'x,
        ppreg:   'x,
        is_fp:   1'b0
>>>>>>> origin/blimp-v9-infra/rtl
      };
    else
      D_reg_next = D_reg;
  end

  // verilator lint_on ENUMVALUE

  //----------------------------------------------------------------------
  // State Machine
  //----------------------------------------------------------------------

  typedef enum {
    IDLE,
    SWAP_SIGN,
    CALC,
    RESTORE_SIGN,
    DONE
  } mul_state_t;

  mul_state_t curr_state;
  mul_state_t next_state;

  //synopsys sync_set_reset "rst"
  always_ff @( posedge clk ) begin
    if( rst )
      curr_state <= IDLE;
    else
      curr_state <= next_state;
  end

  logic calc_done;
  logic need_to_sign_restore;
  
  always_comb begin
    next_state = curr_state;

    case( curr_state )
      IDLE: if( D_xfer ) begin
        if ( 
          D.op2[31] &
          ( D.uop == OP_DIV | D.uop == OP_REM )
        )    next_state = SWAP_SIGN;
        else next_state = CALC;
      end

      SWAP_SIGN: next_state = CALC;

      CALC: if( calc_done ) begin
        if( need_to_sign_restore ) next_state = RESTORE_SIGN;
        else                       next_state = DONE;
      end

      RESTORE_SIGN: next_state = DONE;

      DONE: if( W_xfer ) begin
        if( D_xfer ) begin
          if ( 
            D.op2[31] &
            ( D.uop == OP_DIV | D.uop == OP_REM )
          )    next_state = SWAP_SIGN;
          else next_state = CALC;
        end else
          next_state = IDLE;
      end
    endcase
  end

  logic  initialize;
  assign initialize = ( next_state == SWAP_SIGN ) |
                      (( next_state == CALC ) & !( curr_state == SWAP_SIGN ) & !( curr_state == CALC ));

  //----------------------------------------------------------------------
  // Initial values for opa and opb
  //----------------------------------------------------------------------

  logic [63:0] init_opa, init_opb;

  always_comb begin
    case( D.uop )
      OP_MUL:    init_opa = { 32'b0,           D.op1 };
      OP_MULH:   init_opa = { {32{D.op1[31]}}, D.op1 };
      OP_MULHU:  init_opa = { 32'b0,           D.op1 };
      OP_MULHSU: init_opa = { {32{D.op1[31]}}, D.op1 };
      OP_DIV:    init_opa = { {32{D.op1[31]}}, D.op1 };
      OP_DIVU:   init_opa = { 32'b0,           D.op1 };
      OP_REM:    init_opa = { {32{D.op1[31]}}, D.op1 };
      OP_REMU:   init_opa = { 32'b0,           D.op1 };
      default:   init_opa = 'x;
    endcase
  end

  always_comb begin
    case( D.uop )
      OP_MUL:    init_opb = { 32'b0,           D.op2 };
      OP_MULH:   init_opb = { {32{D.op2[31]}}, D.op2 };
      OP_MULHU:  init_opb = { 32'b0,           D.op2 };
      OP_MULHSU: init_opb = { 32'b0,           D.op2 };
      OP_DIV:    init_opb = { D.op2,           32'b0 };
      OP_DIVU:   init_opb = { D.op2,           32'b0 };
      OP_REM:    init_opb = { D.op2,           32'b0 };
      OP_REMU:   init_opb = { D.op2,           32'b0 };
      default:   init_opb = 'x;
    endcase
  end

  //----------------------------------------------------------------------
  // Calculation
  //----------------------------------------------------------------------

  always_ff @( posedge clk ) begin
    if( initialize )
      need_to_sign_restore <= 1'b0;
    else if( curr_state == SWAP_SIGN )
      // Need to ensure that the sign is the same as dividend
      need_to_sign_restore <= ( D_reg.uop == OP_REM );
  end

  logic [63:0] opa,      opb;
  logic [63:0] next_opa, next_opb;       // per-step results from the step block
  logic [32:0] b_shift,  next_b_shift;
  logic [63:0] result,   next_result;

  // Selected flop-input (next value) for each datapath register, computed by the
  // always_comb blocks below. Distinct from next_opa/next_opb/... which are only
  // the CALC-state candidate coming out of IterativeMulDivRemStepL7.
  logic [63:0] opa_next, opb_next;
  logic [32:0] b_shift_next;
  logic [63:0] result_next;

  // opa next-value logic
  always_comb begin
    if( curr_state == CALC ) begin
      opa_next = next_opa;
    end else if( curr_state == SWAP_SIGN ) begin
      // Need to make sure that opb is positive
      opa_next = ~opa + 1;
    end else if( initialize ) begin
      opa_next = init_opa;
    end else begin
      opa_next = opa;
    end
  end

  //synopsys sync_set_reset "rst"
  always_ff @( posedge clk ) begin
    if( rst ) opa <= '0;
    else      opa <= opa_next;
  end

  // opb next-value logic
  always_comb begin
    if( curr_state == CALC ) begin
      opb_next = next_opb;
    end else if( curr_state == SWAP_SIGN ) begin
      // Need to make sure that opb is positive
      opb_next = ~opb + 1;
    end else if( initialize ) begin
      opb_next = init_opb;
    end else begin
      opb_next = opb;
    end
  end

  //synopsys sync_set_reset "rst"
  always_ff @( posedge clk ) begin
    if( rst ) opb <= '0;
    else      opb <= opb_next;
  end

  // b_shift next-value logic
  always_comb begin
    if( curr_state == CALC ) begin
      b_shift_next = next_b_shift;
    end else if( initialize ) begin
      b_shift_next = { 1'b1, 32'b0 };
    end else begin
      b_shift_next = b_shift;
    end
  end

  //synopsys sync_set_reset "rst"
  always_ff @( posedge clk ) begin
    if( rst ) b_shift <= '0;
    else      b_shift <= b_shift_next;
  end

  // result next-value logic
  always_comb begin
    if( curr_state == CALC ) begin
      result_next = next_result;
    end else if( curr_state == RESTORE_SIGN ) begin
      // Need to fix sign for remainder
      result_next = ~result + 1;
    end else if( initialize ) begin
      result_next = 64'b0;
    end else begin
      result_next = result;
    end
  end

  //synopsys sync_set_reset "rst"
  always_ff @( posedge clk ) begin
    if( rst ) result <= '0;
    else      result <= result_next;
  end

  IterativeMulDivRemStepL7 mul_div_rem_step (
    .a       (opa),
    .b       (opb),
    .b_shift (b_shift),
    .uop     (D_reg.uop),
    .result  (result),

    .next_a       (next_opa),
    .next_b       (next_opb),
    .next_b_shift (next_b_shift),
    .next_result  (next_result),
    .done         (calc_done)
  );

  //----------------------------------------------------------------------
  // Assign outputs
  //----------------------------------------------------------------------

  assign D.rdy = ( curr_state == IDLE ) || ( ( curr_state == DONE ) & W.rdy );
  
  assign W.val     = ( curr_state == DONE );
  assign W.pc      = D_reg.pc;
  assign W.seq_num = D_reg.seq_num;
  assign W.waddr   = D_reg.waddr;
  assign W.preg    = D_reg.preg;
  assign W.ppreg   = D_reg.ppreg;
  assign W.wen     = 1'b1;
  assign W.is_fp   = D_reg.is_fp;

  always_comb begin
    case( D_reg.uop )
      OP_MUL:    W.wdata = result[31:0];
      OP_MULH:   W.wdata = result[63:32];
      OP_MULHU:  W.wdata = result[63:32];
      OP_MULHSU: W.wdata = result[63:32];
      OP_DIV:    W.wdata = result[31:0];
      OP_DIVU:   W.wdata = result[31:0];
      OP_REM:    W.wdata = result[31:0];
      OP_REMU:   W.wdata = result[31:0];
      default:   W.wdata = 'x;
    endcase
  end

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS

  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  int str_len;
  assign str_len = ceil_div_4(p_seq_num_bits) + 2 + // seq_num
                   1                          + 1 + // state
                   1                          + 1 + // sign-restore
                   2                          + 1 + // waddr
                   8                          + 1 + // op1
                   8                          + 1 + // op2
                   16;                              // result

  function string state_str();
    if( curr_state == IDLE )
      return "I";
    if( curr_state == SWAP_SIGN )
      return "S";
    if( curr_state == CALC )
      return "C";
    if( curr_state == RESTORE_SIGN )
      return "R";
    else // Done
      return "D";
  endfunction

  function string trace( int trace_level );
    if( curr_state != IDLE ) begin
      if( trace_level > 0 )
        trace = $sformatf("%h: %1s:%h:%h:%h:%h:%h", W.seq_num,
                         state_str(), need_to_sign_restore,
                         W.waddr, opa[31:0], opb[31:0], result );
      else
        trace = $sformatf("%h: %1s", W.seq_num, state_str());
    end else begin
      if( trace_level > 0 )
        trace = {str_len{" "}};
      else
        trace = {(ceil_div_4(p_seq_num_bits) + 3){" "}};
    end
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L7_PIPELINEDMULTIPLIERL7_V
