//========================================================================
// ControlFlowUnitL6.v
//========================================================================
// An execute unit for handling control flow operations (conditional
// and unconditional)

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L6_CONTROLFLOWUNITL6_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L6_CONTROLFLOWUNITL6_V

`include "defs/UArch.v"
`include "hw/common/FifoBypass.v"
`include "intf/D__XIntf.v"
`include "intf/SquashNotif.v"
`include "intf/X__WIntf.v"

import UArch::*;

module ControlFlowUnitL6 #(
  parameter p_d_intf_fifo_depth  = 4,
  parameter p_d_intf_fifo_bypass = 0
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

  localparam p_seq_num_bits   = D.p_seq_num_bits;
  localparam p_phys_addr_bits = D.p_phys_addr_bits;

  //----------------------------------------------------------------------
  // Bypass FIFO for D interface
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

  // verilator lint_off ENUMVALUE

  D_input fifo_in;
  assign fifo_in = '{
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

  // verilator lint_on ENUMVALUE

  logic fifo_full, fifo_empty, fifo_bypassing;
  logic fifo_push, fifo_pop;

  assign fifo_push = D.val & !fifo_full;
  assign fifo_pop  = !fifo_empty & W.rdy;

  D_input D_curr;

  FifoBypass #(
    .p_entry_bits ($bits(D_input)),
    .p_depth      (p_d_intf_fifo_depth),
    .p_bypass     (p_d_intf_fifo_bypass)
  ) d_fifo (
    .clk       (clk),
    .rst       (rst),
    .clear     (1'b0),
    .push      (fifo_push),
    .pop       (fifo_pop),
    .empty     (fifo_empty),
    .full      (fifo_full),
    .bypassing (fifo_bypassing),
    .wdata     (fifo_in),
    .rdata     (D_curr)
  );

  //----------------------------------------------------------------------
  // Determine squash condition
  //----------------------------------------------------------------------

  logic should_branch;

  always_comb begin
    case( D_curr.uop )
      OP_BEQ:   should_branch = ( D_curr.op1 == D_curr.op2 );
      OP_BNE:   should_branch = ( D_curr.op1 != D_curr.op2 );
      OP_BLT:   should_branch = ( $signed(D_curr.op1) <  $signed(D_curr.op2) );
      OP_BGE:   should_branch = ( $signed(D_curr.op1) >= $signed(D_curr.op2) );
      OP_BLTU:  should_branch = ( D_curr.op1 <  D_curr.op2 );
      OP_BGEU:  should_branch = ( D_curr.op1 >= D_curr.op2 );
      OP_JAL:   should_branch = 1'b0;
      OP_JALR:  should_branch = 1'b0;
      default:  should_branch = 1'bx;
    endcase
  end

  logic squash_sent;
  always_ff @( posedge clk ) begin
    if( rst )
      squash_sent <= 1'b0;
    else if( fifo_pop )
      squash_sent <= 1'b0;
    else if( !fifo_empty )
      squash_sent <= 1'b1;
  end

  // Squash until message is taken
  assign squash.val     = !fifo_empty & should_branch & !squash_sent;
  assign squash.target  = D_curr.pc + D_curr.imm;
  assign squash.seq_num = D_curr.seq_num;

  //----------------------------------------------------------------------
  // Determine register write
  //----------------------------------------------------------------------

  always_comb begin
    case( D_curr.uop )
      OP_BNE:  W.wen = 1'b0;
      OP_JAL:  W.wen = 1'b1;
      OP_JALR: W.wen = 1'b1;
      default: W.wen = 1'bx;
    endcase
  end

  assign W.wdata = D_curr.pc + 32'd4;

  //----------------------------------------------------------------------
  // Remaining signals
  //----------------------------------------------------------------------

  assign W.pc      = D_curr.pc;
  assign W.waddr   = D_curr.waddr;
  assign W.seq_num = D_curr.seq_num;
  assign W.preg    = D_curr.preg;
  assign W.ppreg   = D_curr.ppreg;

  //----------------------------------------------------------------------
  // Assign remaining signals
  //----------------------------------------------------------------------

  assign D.rdy = !fifo_full;
  assign W.val = !fifo_empty;

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
        trace = $sformatf("%11s:%h:%h:%h", D_curr.uop.name(),
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

  function string trace_json();
    if( !fifo_empty )
      trace_json = $sformatf("{\"uop\":\"%0s\",\"seq\":\"%h\",\"waddr\":\"%h\",\"wdata\":\"%h\",\"branch\":\"%b\",\"target\":\"%h\",\"val\":\"%b\",\"rdy\":\"%b\",\"xfer\":\"%b\"}",
        D_curr.uop.name(), W.seq_num, W.waddr, W.wdata,
        should_branch, squash.target,
        W.val, W.rdy, W.val & W.rdy );
    else
      trace_json = "null";
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L6_CONTROLFLOWUNITL6_V
