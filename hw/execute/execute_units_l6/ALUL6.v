//========================================================================
// ALUL6.v
//========================================================================
// An execute unit for performing arithmetic operations

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L6_ALUL6_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L6_ALUL6_V

`include "defs/UArch.v"
`include "hw/common/FifoBypass.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"

import UArch::*;

module ALUL6 #(
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

  X__WIntf.X_intf W
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
  // Arithmetic Operations
  //----------------------------------------------------------------------

  logic [31:0] op1, op2;
  assign op1 = D_curr.op1;
  assign op2 = D_curr.op2;

  rv_uop uop;
  assign uop = D_curr.uop;

  always_comb begin
    case( uop )
      OP_ADD:   W.wdata = op1 + op2;
      OP_SUB:   W.wdata = op1 - op2;
      OP_AND:   W.wdata = op1 & op2;
      OP_OR:    W.wdata = op1 | op2;
      OP_XOR:   W.wdata = op1 ^ op2;
      OP_SLT:   W.wdata = { 31'b0, ($signed(op1) <  $signed(op2))};
      OP_SLTU:  W.wdata = { 31'b0, (op1          <  op2         )};
      OP_SRA:   W.wdata = $signed(op1) >>> op2[4:0];
      OP_SRL:   W.wdata = op1           >> op2[4:0];
      OP_SLL:   W.wdata = op1           << op2[4:0];
      OP_LUI:   W.wdata = op2;
      OP_AUIPC: W.wdata = D_curr.pc + op2;
      default:  W.wdata = 'x;
    endcase
  end

  //----------------------------------------------------------------------
  // Assign remaining signals
  //----------------------------------------------------------------------

  assign D.rdy = !fifo_full;
  assign W.val = !fifo_empty;

  assign W.pc      = D_curr.pc;
  assign W.wen     = 1'b1;
  assign W.seq_num = D_curr.seq_num;
  assign W.waddr   = D_curr.waddr;
  assign W.preg    = D_curr.preg;
  assign W.ppreg   = D_curr.ppreg;

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  int str_len;
  assign str_len = ceil_div_4(p_seq_num_bits) + 2 + // seq_num
                   11                         + 1 + // uop
                   ceil_div_4(5)              + 1 + // waddr
                   8                          + 1 + // op1
                   8                          + 1 + // op2
                   8;                               // wdata

  function string trace( int trace_level );
    if( W.val & W.rdy ) begin
      if( trace_level > 0 )
        trace = $sformatf("%h: %11s:%h:%h:%h:%h", W.seq_num, D_curr.uop.name(),
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

  function string trace_json();
    if( !fifo_empty )
      trace_json = $sformatf("{\"seq\":\"%h\",\"uop\":\"%0s\",\"waddr\":\"%h\",\"op1\":\"%h\",\"op2\":\"%h\",\"wdata\":\"%h\",\"val\":\"%b\",\"rdy\":\"%b\",\"xfer\":\"%b\"}",
        W.seq_num, D_curr.uop.name(), W.waddr, op1, op2, W.wdata,
        W.val, W.rdy, W.val & W.rdy );
    else
      trace_json = "null";
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L6_ALUL6_V
