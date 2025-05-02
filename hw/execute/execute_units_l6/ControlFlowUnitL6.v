//========================================================================
// ControlFlowUnitL6.v
//========================================================================
// An execute unit for handling control flow operations (conditional
// and unconditional)

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L6_CONTROLFLOWUNITL6_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L6_CONTROLFLOWUNITL6_V

`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/SquashNotif.v"
`include "intf/X__WIntf.v"

import UArch::*;

module ControlFlowUnitL6 #(
  parameter p_seq_num_bits   = 5,
  parameter p_phys_addr_bits = 6
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

  X__WIntf.X_intf W,

  //----------------------------------------------------------------------
  // Squash Notification
  //----------------------------------------------------------------------

  SquashNotif.pub squash
);
  
  //----------------------------------------------------------------------
  // Register inputs
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                        val;
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                 [31:0] op1;
    logic                 [31:0] op2;
    logic                 [31:0] imm;
    logic                  [4:0] waddr;
    rv_uop                       uop;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
  } D_input;

  D_input D_reg;
  D_input D_reg_next;
  logic   D_xfer;
  logic   W_xfer;

  // verilator lint_off ENUMVALUE

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
        val:     1'b1, 
        pc:      D.pc,
        seq_num: D.seq_num,
        op1:     D.op1,
        op2:     D.op2,
        imm:     D.op3.branch_imm,
        waddr:   D.waddr,
        uop:     D.uop,
        preg:    D.preg,
        ppreg:   D.ppreg
      };
    else if ( W_xfer )
      D_reg_next = '0;
    else
      D_reg_next = D_reg;
  end

  // verilator lint_on ENUMVALUE

  //----------------------------------------------------------------------
  // Determine squash condition
  //----------------------------------------------------------------------

  logic should_branch;
  
  always_comb begin
    case( D_reg.uop )
      OP_BEQ:   should_branch = ( D_reg.op1 == D_reg.op2 );
      OP_BNE:   should_branch = ( D_reg.op1 != D_reg.op2 );
      OP_BLT:   should_branch = ( $signed(D_reg.op1) <  $signed(D_reg.op2) );
      OP_BGE:   should_branch = ( $signed(D_reg.op1) >= $signed(D_reg.op2) );
      OP_BLTU:  should_branch = ( D_reg.op1 <  D_reg.op2 );
      OP_BGEU:  should_branch = ( D_reg.op1 >= D_reg.op2 );
      OP_JAL:   should_branch = 1'b0;
      OP_JALR:  should_branch = 1'b0;
      default:  should_branch = 1'bx;
    endcase
  end

  logic squash_sent;
  always_ff @( posedge clk ) begin
    if( rst )
      squash_sent <= 1'b0;
    else if( D_xfer )
      squash_sent <= 1'b0;
    else
      squash_sent <= 1'b1;
  end

  // Squash until message is taken
  assign squash.val     = D_reg.val & should_branch & !squash_sent;
  assign squash.target  = D_reg.pc + D_reg.imm;
  assign squash.seq_num = D_reg.seq_num;

  //----------------------------------------------------------------------
  // Determine register write
  //----------------------------------------------------------------------

  always_comb begin
    case( D_reg.uop )
      OP_BNE:  W.wen = 1'b0;
      OP_JAL:  W.wen = 1'b1;
      OP_JALR: W.wen = 1'b1;
      default: W.wen = 1'bx;
    endcase
  end

  assign W.wdata = D_reg.pc + 32'd4;

  //----------------------------------------------------------------------
  // Remaining signals
  //----------------------------------------------------------------------
  
  assign W.pc      = D_reg.pc;
  assign W.waddr   = D_reg.waddr;
  assign W.seq_num = D_reg.seq_num;
  assign W.preg    = D_reg.preg;
  assign W.ppreg   = D_reg.ppreg;

  //----------------------------------------------------------------------
  // Assign remaining signals
  //----------------------------------------------------------------------

  assign D.rdy = W.rdy | (!D_reg.val);
  assign W.val = D_reg.val;

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  int str_len;
  assign str_len = 11                         + 1 + // uop
                   ceil_div_4(p_seq_num_bits) + 1 + // seq_num
                   ceil_div_4(5)              + 1 + // waddr
                   8;                               // wdata

  function string trace( int trace_level );
    if( W.val & W.rdy ) begin
      if( trace_level > 0 )
        trace = $sformatf("%11s:%h:%h:%h", D_reg.uop.name(),
                        W.seq_num, W.waddr, W.wdata );
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

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L6_CONTROLFLOWUNITL6_V
