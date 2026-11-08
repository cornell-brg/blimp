//========================================================================
// FPInstUnit.v
//========================================================================
// Floating-point miscellaneous instruction unit.
//
// Supports:
//   - FSGNJ.S
//   - FCVT.W.S
//   - FMV.X.W
//   - FMV.W.X
//
// Author: Sumaia Jewena
//========================================================================

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L1_FPINSTUNIT_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L1_FPINSTUNIT_V

`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"

import UArch::*;

module FPInstUnit (
  input  logic clk,
  input  logic rst,

  D__XIntf.X_intf D,
  X__WIntf.X_intf W
);

  localparam p_seq_num_bits   = D.p_seq_num_bits;
  localparam p_phys_addr_bits = D.p_phys_addr_bits;

  // --------------------------------------------------------------------
  // Pipeline register for D inputs
  // --------------------------------------------------------------------
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

  always_ff @(posedge clk) begin
    if ( rst )
      D_reg <= '0;
    else
      D_reg <= D_reg_next;
  end

  always_comb begin
    D_xfer = D.val & D.rdy;
    W_xfer = W.val & W.rdy;

    if ( D_xfer ) begin
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
    end
    else if ( W_xfer ) begin
      D_reg_next = '0;
    end
    else begin
      D_reg_next = D_reg;
    end
  end

  // --------------------------------------------------------------------
  // Float to Int conversion (FCVT.W.S)
  // --------------------------------------------------------------------
  logic signed [31:0] int_result;

  always_comb begin
    // Extract sign, exponent, mantissa
    logic        sign_fp;
    logic [7:0]  exp_fp;
    logic [31:0] mant_fp;       // 23-bit mantissa + implicit 1
    logic signed [31:0] shifted_mant;
    int shift_amt;

    shifted_mant = 32'd0;

    sign_fp = D_reg.op1[31];
    exp_fp  = D_reg.op1[30:23];
    mant_fp = {8'b0, 1'b1, D_reg.op1[22:0]};  // Add implicit leading 1

    // Calculate shift amount (exponent - bias - 23)
    shift_amt = int'(exp_fp) - 127 - 23;

    if ( exp_fp == 8'h00 ) begin
      // Zero or denormal
      int_result = 32'd0;
    end
    else if ( exp_fp == 8'hFF ) begin
      // NaN or Infinity -> saturate to max/min int
      int_result = sign_fp ? 32'h80000000 : 32'h7FFFFFFF;
    end
    else if ( shift_amt >= 8 ) begin
      // Overflow -> saturate
      int_result = sign_fp ? 32'h80000000 : 32'h7FFFFFFF;
    end
    else if ( shift_amt < -23 ) begin
      // Underflow to zero
      int_result = 32'd0;
    end
    else begin
      // Normal conversion
      if ( shift_amt >= 0 )
        shifted_mant = signed'(mant_fp) << shift_amt;
      else
        shifted_mant = signed'(mant_fp) >>> (-shift_amt);

      int_result = sign_fp ? -shifted_mant : shifted_mant;
    end
  end

  // --------------------------------------------------------------------
  // Operation select
  // --------------------------------------------------------------------
  always_comb begin
    unique case ( D_reg.uop )
      OP_FSGNJ_S : W.wdata = {D_reg.op2[31], D_reg.op1[30:0]};
      OP_FCVT_W_S: W.wdata = int_result;
      OP_FMV_X_W,
      OP_FMV_W_X : W.wdata = D_reg.op1;
      default    : W.wdata = 'x;
    endcase
  end

  // --------------------------------------------------------------------
  // Handshake - single-cycle style output protocol
  // --------------------------------------------------------------------
  assign D.rdy = W.rdy | !D_reg.val;
  assign W.val = D_reg.val;
  assign W.pc  = D_reg.pc;

  logic is_fpinst_wen;
  always_comb begin
    unique case ( D_reg.uop )
      OP_FSGNJ_S,
      OP_FCVT_W_S,
      OP_FMV_X_W,
      OP_FMV_W_X : is_fpinst_wen = 1'b1;
      default    : is_fpinst_wen = 1'b0;
    endcase
  end

  assign W.wen = is_fpinst_wen;

  assign W.seq_num = D_reg.seq_num;
  assign W.waddr   = D_reg.waddr;
  assign W.preg    = D_reg.preg;
  assign W.ppreg   = D_reg.ppreg;
  assign W.is_fp   = D_reg.is_fp;

  // --------------------------------------------------------------------
  // Trace utilities
  // --------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  int str_len;
  assign str_len = ceil_div_4(p_seq_num_bits) + 2 +
                   11 + 1 +
                   ceil_div_4(5) + 1 +
                   8 + 1 + 8 + 1 + 8;

  function string trace( int trace_level );
    string tr;
    if ( W.val & W.rdy ) begin
      if ( trace_level > 0 )
        tr = $sformatf("%h: %11s:%h:%h:%h:%h",
                       W.seq_num, D_reg.uop.name(),
                       W.waddr, D_reg.op1, D_reg.op2, W.wdata);
      else
        tr = $sformatf("%h", W.seq_num);
    end
    else begin
      if ( trace_level > 0 )
        tr = {str_len{" "}};
      else
        tr = {(ceil_div_4(p_seq_num_bits)){" "}};
    end
    return tr;
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L1_FPINSTUNIT_V
