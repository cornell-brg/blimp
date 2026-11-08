//========================================================================
// MultiplierL1.v
//========================================================================
// An execute unit for performing multiplication operations

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L1_MULTIPLIERL1_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L1_MULTIPLIERL1_V

`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"

import UArch::*;

module MultiplierL1 (
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
  
  //----------------------------------------------------------------------
  // Register inputs
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                      val;
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
    logic               [31:0] op1;
    logic               [31:0] op2;
    logic                [4:0] waddr;
    rv_uop                     uop;
  } D_input;

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
        op1:     '0, 
        op2:     '0,
        waddr:   '0,
        uop:     '0
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
        op1:     D.op1, 
        op2:     D.op2,
        waddr:   D.waddr,
        uop:     D.uop
      };
    else if ( W_xfer )
      D_reg_next = '{ 
        val:     1'b0, 
        pc:      '0,
        seq_num: '0,
        op1:     '0, 
        op2:     '0,
        waddr:   '0,
        uop:     '0
      };
    else
      D_reg_next = D_reg;
  end

  // verilator lint_on ENUMVALUE

  //----------------------------------------------------------------------
  // Arithmetic Operations
  //----------------------------------------------------------------------
  
  logic [31:0] op1, op2;
  assign op1 = D_reg.op1;
  assign op2 = D_reg.op2;

  rv_uop uop;
  assign uop = D_reg.uop;

  always_comb begin
    case( uop )
      OP_MUL:  W.wdata = op1 * op2;
      default: W.wdata = 'x;
    endcase
  end

  //----------------------------------------------------------------------
  // Assign remaining signals
  //----------------------------------------------------------------------

  assign D.rdy = W.rdy | (!D_reg.val);
  assign W.val = D_reg.val;

  assign W.pc      = D_reg.pc;
  assign W.wen     = 1'b1;
  assign W.seq_num = D_reg.seq_num;
  assign W.waddr   = D_reg.waddr;

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  int str_len;
  assign str_len = 11                         + 3 + // uop
                   ceil_div_4(p_seq_num_bits) + 1 + // seq_num
                   ceil_div_4(5)              + 1 + // waddr
                   8                          + 1 + // op1
                   8                          + 1 + // op2
                   8;                               // wdata

  function string trace( int trace_level );
    if( W.val & W.rdy ) begin
      if( trace_level > 0 )
        trace = $sformatf("%h: %11s:%h:%h:%h:%h", W.seq_num, D_reg.uop.name(), 
                          W.waddr, op1, op2, W.wdata );
      else
        trace = $sformatf("%h", W.seq_num);
    end else begin
      if( trace_level > 0 )
        trace = {str_len{" "}};
      else
        trace = {(ceil_div_4(p_seq_num_bits)){" "}};
    end
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L1_MULTIPLIERL1_V
