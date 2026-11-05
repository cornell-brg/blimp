//=========================================================================
// FPU Multiplier - Consolidated Module
//=========================================================================
// Performs floating-point multiplication
// Original Author: Parker Schless
// Adapted to C2S2 BLIMP by: Emily Lan
// Consolidated from separate stage modules

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L8_FPUMULT_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L8_FPUMULT_V

`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"
`include "hw/execute/execute_units_l8/fpu/FPUMsg.v"

import UArch::*;

//=========================================================================
// FPUImul - Unsigned Integer Multiplier
//=========================================================================
// Booth-recoder unsigned integer multiplier

module FPUImul #(
  parameter integer p_opt_level = 0,
  parameter integer p_bitwidth  = 24,
  parameter integer p_groups    = (p_bitwidth + 1) / 2
) (
  input  logic [p_bitwidth-1:0]   a,
  input  logic [p_bitwidth-1:0]   b,
  output logic [2*p_bitwidth-1:0] out
);
  
  generate
    if (p_opt_level >= 4) begin
      logic [2*p_bitwidth-1:0] partial;
      logic [1:0]              digit;
      
      always_comb begin
        out = '0;

        // Skip logic if either operand is zero
        if (a == '0 || b == '0) begin
          out     = '0;
          digit   = '0;
          partial = '0;
        end else begin
          for (int i = 0; i < p_groups; i++) begin

            // Take two digits from b to get digit, create partial from this
            if (((i << 1) + 1) < p_bitwidth) digit = b[(i << 1) + 1 -: 2];
            else                             digit = {1'b0, b[i << 1]};
            case (digit)
              2'b00:   partial = '0;
              2'b01:   partial = a;
              2'b10:   partial = a << 1;
              2'b11:   partial = (a << 1) + a;
              default: partial = '0;
            endcase

            // Shift partial and add to result
            out = out + (partial << (i << 1));
          end
        end
      end
    end else begin
      assign out = a * b;
    end
  endgenerate

endmodule

//=========================================================================
// FPUMultGate - Data Gate Implementation
//=========================================================================
// Gate input message

module FPUMultGate #(
    
  parameter integer p_opt_level = 0,
  parameter integer p_expwidth  = 8,
  parameter integer p_frwidth   = 23,
  parameter type fpu_resp_t     = `FPU_RESP(8, 23),
  parameter integer p_opwidth   = 1 + p_expwidth + p_frwidth
) (
  input  fpu_resp_t             in0,
  input  fpu_resp_t             in1,
  input  logic                  dg_en,
  output fpu_resp_t             out0,
  output fpu_resp_t             out1
);

  generate
    if (p_opt_level == 0) begin
      assign out0 = in0;
      assign out1 = in1;
    end else if (p_opt_level == 1) begin
      assign out0 = dg_en ? in0 : '0;
      assign out1 = dg_en ? in1 : '0;
    end else begin
      /* verilator lint_off LATCH */
      always @(dg_en or in0) begin
        if (dg_en) 
          out0 = in0;
      end

      always @(dg_en or in1) begin
        if (dg_en)
          out1 = in1;
      end
      /* verilator lint_on LATCH */
    end
  endgenerate

endmodule

//=========================================================================
// FPUMultStage1 - Unpack operands and compute result sign
//=========================================================================

module FPUMultStage1 #(
  parameter integer p_expwidth      = 8,
  parameter integer p_frwidth       = 23,
  parameter integer p_opwidth       = 1 + p_expwidth + p_frwidth,
  parameter integer p_mult_sigwidth = 2*(p_frwidth+1),
  parameter integer p_exp_bias      = 2**(p_expwidth-1) - 1
) (
  input  logic [p_frwidth-1:0] fr0,
  input  logic [p_frwidth-1:0] fr1,
  input  logic                 sn0,
  input  logic                 sn1,
  output logic [p_frwidth:0]   sig0,
  output logic [p_frwidth:0]   sig1,
  output logic                 snR
);

  assign sig0 = {1'b1, fr0};
  assign sig1 = {1'b1, fr1};
  assign snR  = sn0 ^ sn1;

endmodule

//=========================================================================
// FPUMultStage2 - Multiply significands and compute exponent adjustment
//=========================================================================

module FPUMultStage2 #(
  parameter integer p_opt_level     = 0,
  parameter integer p_expwidth      = 8,
  parameter integer p_frwidth       = 23,
  parameter integer p_opwidth       = 1 + p_expwidth + p_frwidth,
  parameter integer p_mult_sigwidth = 2*(p_frwidth+1),
  parameter integer p_exp_bias      = 2**(p_expwidth-1) - 1
) (
  input  logic [p_frwidth:0] sig0,
  input  logic [p_frwidth:0] sig1,
  output logic [p_frwidth:0] sigR,
  output logic               expR_add
);

  logic [p_mult_sigwidth-1:0] sigR_im;
  logic sticky, guard, round, round_of;
  logic nearest_round, nearest_round_plus1;
  logic mult_msb_zero;

  FPUImul #(
    .p_opt_level (p_opt_level),
    .p_bitwidth  (p_frwidth+1)
  ) fpu_sig_mult (
    .a   (sig0),
    .b   (sig1),
    .out (sigR_im)
  );
  
  assign mult_msb_zero       = sigR_im[p_mult_sigwidth-1] == 1'b0;
  assign sticky              = mult_msb_zero ? 
                                  |sigR_im[p_frwidth-2:0] : |sigR_im[p_frwidth-1:0];
  assign guard               = sigR_im[p_frwidth];
  assign round               = mult_msb_zero ? 
                                  sigR_im[p_frwidth-1] : sigR_im[p_frwidth];
  assign nearest_round       = (round && sigR_im[p_frwidth]) || (round && sticky);
  assign nearest_round_plus1 = (round && sigR_im[p_frwidth+1]) || (round && sticky);
  assign sigR                = mult_msb_zero ? 
                                  (nearest_round ? 
                                    sigR_im[p_mult_sigwidth-2:p_frwidth] + 1'b1 : 
                                    sigR_im[p_mult_sigwidth-2:p_frwidth]) :
                                  (nearest_round_plus1 ? sigR_im[p_mult_sigwidth-1:p_frwidth+1] + 1'b1 : 
                                    sigR_im[p_mult_sigwidth-1:p_frwidth+1]);
  assign round_of            = mult_msb_zero ? 
                                  (nearest_round && 
                                    (sigR_im[p_mult_sigwidth-2:p_frwidth] == 
                                      {(p_frwidth+1){1'b1}})) :
                                  (nearest_round_plus1 && 
                                    (sigR_im[p_mult_sigwidth-1:p_frwidth+1] == 
                                      {(p_frwidth+1){1'b1}}));

  assign expR_add = (sigR_im[p_mult_sigwidth-1] == 1'b1) || round_of;

endmodule

//=========================================================================
// FPUMultStage3 - Compute final exponent and overflow/underflow flags
//=========================================================================

// module FPUMultStage3 #(
//   parameter integer p_expwidth      = 8,
//   parameter integer p_frwidth       = 23,
//   parameter integer p_opwidth       = 1 + p_expwidth + p_frwidth,
//   parameter integer p_mult_sigwidth = 2*(p_frwidth+1),
//   parameter integer p_exp_bias      = 2**(p_expwidth-1) - 1
// ) (
//   input  logic [p_expwidth-1:0] exp0,
//   input  logic [p_expwidth-1:0] exp1,
//   input  logic                  expR_add,
//   output logic [p_expwidth-1:0] expR,
//   output logic                  expR_of,
//   output logic                  expR_uf
// );

//   logic [p_expwidth:0]   expR_exp_sum;
//   logic [p_expwidth:0]   expR_im;

//   assign expR_exp_sum = exp0 + exp1;
//   //assign expR_im      = expR_exp_sum - p_exp_bias + expR_add;
//   assign expR_im = expR_exp_sum - (p_expwidth+1)'(p_exp_bias) + (p_expwidth+1)'(expR_add);
//   assign expR_of      = expR_im[p_expwidth] && !expR_uf;
//   //assign expR_uf      = expR_exp_sum < p_exp_bias;
//   assign expR_uf = expR_exp_sum < (p_expwidth+1)'(p_exp_bias);
//   assign expR         = expR_im[p_expwidth-1:0];

// endmodule

module FPUMultStage3 #(
  parameter integer p_expwidth      = 8,
  parameter integer p_frwidth       = 23,
  parameter integer p_opwidth       = 1 + p_expwidth + p_frwidth,
  parameter integer p_mult_sigwidth = 2*(p_frwidth+1),
  parameter integer p_exp_bias      = 2**(p_expwidth-1) - 1
) (
  input  logic [p_expwidth-1:0] exp0,
  input  logic [p_expwidth-1:0] exp1,
  input  logic                  expR_add,
  output logic [p_expwidth-1:0] expR,
  output logic                  expR_of,
  output logic                  expR_uf
);
  logic [p_expwidth:0]   expR_exp_sum;
  logic [p_expwidth:0]   expR_im;

  assign expR_exp_sum = exp0 + exp1;

  //assign expR_im      = expR_exp_sum - p_exp_bias + expR_add;
  assign expR_of      = expR_im[p_expwidth] && !expR_uf;
  //assign expR_uf      = expR_exp_sum < p_exp_bias;
  assign expR_im      = expR_exp_sum - (p_expwidth+1)'(p_exp_bias) + (p_expwidth+1)'(expR_add);
  assign expR_uf      = expR_exp_sum < (p_expwidth+1)'(p_exp_bias);
  
  assign expR         = expR_im[p_expwidth-1:0];

endmodule

//=========================================================================
// FPUMultStage4 - Output final value based on exceptional cases
//=========================================================================

module FPUMultStage4 #(
  parameter integer p_expwidth      = 8,
  parameter integer p_frwidth       = 23,
  parameter type fpu_resp_t         = `FPU_RESP(8, 23),
  parameter integer p_opwidth       = 1 + p_expwidth + p_frwidth,
  parameter integer p_mult_sigwidth = 2*(p_frwidth+1),
  parameter integer p_exp_bias      = 2**(p_expwidth-1) - 1
) (
  input  logic [p_expwidth-1:0] exp0,
  input  logic [p_expwidth-1:0] exp1,
  input  logic [p_expwidth-1:0] expR_in,
  input  logic [p_frwidth:0]    sigR_in,
  input  logic                  snR_in,
  input  logic                  expR_in_uf,
  input  logic                  expR_in_of,
  output fpu_resp_t             ostream_msg
);

  always_comb begin

    // If either operand is zero/denormal, result is zero
    if (exp0 == '0 || exp1 == '0)
      ostream_msg = '0;
    
    // Underflow
    else if (expR_in_uf)
      ostream_msg = '0;
    
    // Overflow
    else if (expR_in_of)
      ostream_msg = {1'b0, {p_expwidth{1'b1}}, {(p_frwidth){1'b0}}};
    
    // Standard case
    else
      ostream_msg = {snR_in, expR_in, sigR_in[p_frwidth-1:0]};
  end

endmodule

//=========================================================================
// FPUMult - Top-level FPU Multiplier
//=========================================================================

module FPUMult #(
  parameter integer p_opt_level     = 0,
  parameter integer p_expwidth      = 8,
  parameter integer p_frwidth       = 23,
  parameter type fpu_req_t          = `FPU_REQ(8, 23),
  parameter type fpu_resp_t         = `FPU_RESP(8, 23),
  parameter integer p_opwidth       = 1 + p_expwidth + p_frwidth,
  parameter integer p_mult_sigwidth = 2*(p_frwidth+1),
  parameter integer p_exp_bias      = 2**(p_expwidth-1) - 1
) (
  input  logic      clk,
  input  logic      rst,
  //input  logic      dg_en,
  // input  fpu_resp_t in0,
  // input  fpu_resp_t in1,
  // output fpu_resp_t ostream_msg,

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

  D_input D_reg;
  D_input D_reg_next;
  logic   D_xfer;
  logic   W_xfer;
  logic   dg_en;

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
        waddr:   D.waddr,
        uop:     D.uop,
        preg:    D.preg,
        ppreg:   D.ppreg,
        is_fp  : D.is_fp
      };
    else if ( W_xfer )
      D_reg_next = '0;
    else
      D_reg_next = D_reg;
  end

  //=======================================================================
  // Data Gate
  //=======================================================================
  fpu_resp_t in0, in1;           // Now local signals
  fpu_resp_t ostream_msg;  
  fpu_resp_t gated_in0;
  fpu_resp_t gated_in1;

  always_comb begin
    in0.sn  = D_reg.op1[p_opwidth-1];
    in0.exp = D_reg.op1[p_opwidth-2 -: p_expwidth];
    in0.fr  = D_reg.op1[p_frwidth-1:0];
    
    in1.sn  = D_reg.op2[p_opwidth-1];
    in1.exp = D_reg.op2[p_opwidth-2 -: p_expwidth];
    in1.fr  = D_reg.op2[p_frwidth-1:0];
  end

  FPUMultGate #(
    .p_opt_level (p_opt_level),
    .p_expwidth  (p_expwidth),
    .p_frwidth   (p_frwidth),
    .fpu_resp_t  (fpu_resp_t)
  ) gate (
    .in0   (in0),
    .in1   (in1),
    .dg_en (dg_en),
    .out0  (gated_in0),
    .out1  (gated_in1)
  );

  //=======================================================================
  // Stage 1
  //=======================================================================

  logic [p_frwidth:0] sig0_1, sig1_1;
  logic               snR_1;

  FPUMultStage1 #(
    .p_expwidth (p_expwidth),
    .p_frwidth  (p_frwidth)
  ) fpu_stage1 (
    .fr0  (gated_in0.fr),
    .fr1  (gated_in1.fr),
    .sn0  (gated_in0.sn),
    .sn1  (gated_in1.sn),
    .sig0 (sig0_1),
    .sig1 (sig1_1),
    .snR  (snR_1)
  );

  //=======================================================================
  // Stage 2
  //=======================================================================

  logic [p_frwidth:0] sigR_2;
  logic               expR_2_of;

  FPUMultStage2 #(
    .p_opt_level (p_opt_level),
    .p_expwidth  (p_expwidth),
    .p_frwidth   (p_frwidth)
  ) fpu_stage2 (
    .sig0     (sig0_1),
    .sig1     (sig1_1),
    .sigR     (sigR_2),
    .expR_add (expR_2_of)
  );

  //=======================================================================
  // Stage 3
  //=======================================================================

  logic [p_expwidth-1:0] expR_3;
  logic                  expR_3_of, expR_3_uf;

  FPUMultStage3 #(
    .p_expwidth (p_expwidth),
    .p_frwidth  (p_frwidth)
  ) fpu_stage3 (
    .exp0     (gated_in0.exp),
    .exp1     (gated_in1.exp),
    .expR_add (expR_2_of),
    .expR     (expR_3),
    .expR_of  (expR_3_of),
    .expR_uf  (expR_3_uf)
  );

  //=======================================================================
  // Stage 4
  //=======================================================================

  logic [p_expwidth-1:0] expR_4;
  logic [p_frwidth:0]    sigR_4;
  logic                  snR_4;

  FPUMultStage4 #(
    .p_expwidth (p_expwidth),
    .p_frwidth  (p_frwidth),
    .fpu_resp_t (fpu_resp_t)
  ) fpu_stage4 (
    .exp0        (gated_in0.exp),
    .exp1        (gated_in1.exp),
    .expR_in     (expR_3),
    .sigR_in     (sigR_2),
    .snR_in      (snR_1),
    .expR_in_uf  (expR_3_uf),
    .expR_in_of  (expR_3_of),
    .ostream_msg (ostream_msg)
  );

  always_comb begin
    W.wdata = {ostream_msg.sn, ostream_msg.exp, ostream_msg.fr};
  end

  assign dg_en = D_reg.val;

  assign D.rdy = W.rdy | (!D_reg.val);
  assign W.val = D_reg.val;

  assign W.pc      = D_reg.pc;
  assign W.wen     = 1'b1;
  assign W.seq_num = D_reg.seq_num;
  assign W.waddr   = D_reg.waddr;
  assign W.preg    = D_reg.preg;
  assign W.ppreg   = D_reg.ppreg;
  assign W.is_fp   = D_reg.is_fp;

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
        trace = $sformatf("%h: %11s:%h:%h:%h:%h", W.seq_num, D_reg.uop.name(), 
                          W.waddr, D_reg.op1, D_reg.op2, W.wdata );
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

`endif /* FPU_FPUMULT_V */