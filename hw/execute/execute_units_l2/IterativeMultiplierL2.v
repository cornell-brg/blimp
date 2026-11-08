//========================================================================
// IterativeMultiplierL2.v
//========================================================================
// A multiplier with a parametrizable latency

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L2_ITERATIVEMULTIPLIERL2_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L2_ITERATIVEMULTIPLIERL2_V

`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"

import UArch::*;

//------------------------------------------------------------------------
// IterativeMultiplyStepL2
//------------------------------------------------------------------------
// Computes one "step" of the multiplication, looking at the next N bits

module IterativeMultiplyStepL2 #(
  parameter p_num_bits = 4
)(
  input  logic [31:0] a,
  input  logic [31:0] b,

  output logic [31:0] out
);

  logic [31:0] partial_products [p_num_bits];

  genvar i;
  generate
    for( i = 0; i < p_num_bits; i = i + 1 ) begin
      logic select;
      assign select = 1'( ( a >> i ) & 32'h00000001 );

      assign partial_products[i] = select ? b << i : '0;
    end
  endgenerate

  always_comb begin
    out = '0;
    for( int j = 0; j < p_num_bits; j = j + 1 ) begin
      out = out + partial_products[j];
    end
  end
endmodule

//------------------------------------------------------------------------
// IterativeMultiplier
//------------------------------------------------------------------------

module IterativeMultiplierL2 #(
  parameter p_num_cycles = 8
)(
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

  always_ff @( posedge clk ) begin
    if ( rst )
      D_reg <= '{ 
        val:     1'b0, 
        pc:      '0,
        seq_num: '0,
        waddr:   '0,
        uop:     '0,
        preg:    '0,
        ppreg:   '0
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
        ppreg:   D.ppreg
      };
    else if ( W_xfer )
      D_reg_next = '{ 
        val:     1'b0, 
        pc:      '0,
        seq_num: '0,
        waddr:   '0,
        uop:     '0,
        preg:    '0,
        ppreg:   '0
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
    CALC,
    DONE
  } mul_state_t;

  mul_state_t curr_state;
  mul_state_t next_state;

  always_ff @( posedge clk ) begin
    if( rst )
      curr_state <= IDLE;
    else
      curr_state <= next_state;
  end

  logic [4:0] num_partial_products;
  
  always_comb begin
    next_state = curr_state;

    case( curr_state )
      IDLE: if( D_xfer )                               next_state = CALC;
      CALC: if( num_partial_products == p_num_cycles - 1 ) next_state = DONE;
      DONE: if( W_xfer ) begin
        if( D_xfer )
          next_state = CALC;
        else
          next_state = IDLE;
      end
    endcase
  end

  always_ff @( posedge clk ) begin
    if( curr_state == CALC ) begin
      num_partial_products <= num_partial_products + 5'b1;
    end else if( next_state == CALC ) begin
      num_partial_products <= '0;
    end
  end

  //----------------------------------------------------------------------
  // Calculation
  //----------------------------------------------------------------------

  // Bits to calculate each operation
  localparam p_num_bits = 32 / p_num_cycles;

  logic [31:0] opa, opb;
  logic [31:0] next_opa, next_opb;

  always_ff @( posedge clk ) begin
    if( curr_state == CALC ) begin
      opa <= next_opa;
      opb <= next_opb;
    end else if( next_state == CALC ) begin
      opa <= D.op1;
      opb <= D.op2;
    end
  end

  always_comb begin
    next_opa = ( opa >> p_num_bits );
    next_opb = ( opb << p_num_bits );
  end

  logic [31:0] step_result;
  IterativeMultiplyStepL2 #( p_num_bits ) multiply_step (
    .a   (opa),
    .b   (opb),
    .out (step_result)
  );

  logic [31:0] result;
  always_ff @( posedge clk ) begin
    if( curr_state == CALC ) begin
      result <= result + step_result;
    end else if( next_state == CALC ) begin
      result <= '0;
    end
  end

  //----------------------------------------------------------------------
  // Assign outputs
  //----------------------------------------------------------------------

  assign D.rdy = ( curr_state == IDLE ) || ( ( curr_state == DONE ) & W.rdy );
  
  assign W.val     = ( curr_state == DONE );
  assign W.pc      = D_reg.pc;
  assign W.seq_num = D_reg.seq_num;
  assign W.waddr   = D_reg.waddr;
  assign W.wdata   = result;
  assign W.preg    = D_reg.preg;
  assign W.ppreg   = D_reg.ppreg;
  assign W.wen     = 1'b1;

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
                   2                          + 1 + // waddr
                   8                          + 1 + // op1
                   8                          + 1 + // op2
                   8;                               // wdata

  function string trace( int trace_level );
    if( curr_state != IDLE ) begin
      if( trace_level > 0 )
        trace = $sformatf("%h: %1s:%h:%h:%h:%h", W.seq_num,
                         ( curr_state == IDLE ) ? "I" : ( curr_state == CALC ) ? "C" : "D", 
                         W.waddr, opa, opb, result );
      else
        trace = $sformatf("%h: %1s", W.seq_num,
                         ( curr_state == IDLE ) ? "I" : ( curr_state == CALC ) ? "C" : "D" );
    end else begin
      if( trace_level > 0 )
        trace = {str_len{" "}};
      else
        trace = {(ceil_div_4(p_seq_num_bits) + 3){" "}};
    end
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L2_PIPELINEDMULTIPLIERL2_V
