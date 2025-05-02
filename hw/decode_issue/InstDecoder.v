//========================================================================
// InstDecode.v
//========================================================================
// A parametrized decoder to linearize opcodes

`ifndef HW_DECODE_ISSUE_INSTDECODER_V
`define HW_DECODE_ISSUE_INSTDECODER_V

`include "defs/ISA.v"
`include "defs/UArch.v"

import ISA::*;
import UArch::*;

module InstDecoder (
  input  logic [31:0] inst,

  output logic        val,
  output rv_uop       uop,
  output logic [4:0]  raddr0,
  output logic [4:0]  raddr1,
  output logic [4:0]  waddr,
  output logic        wen,
  output rv_imm_type  imm_sel,
  output logic        op2_sel,
  output logic [1:0]  jal,
  output logic        op3_sel
);

  //----------------------------------------------------------------------
  // cs
  //----------------------------------------------------------------------
  // A task to set control signals appropriately

  task automatic cs(
    input logic       cs_val,
    input rv_uop      cs_uop,
    input logic [1:0] cs_jal,
    input logic [4:0] cs_raddr0,
    input logic [4:0] cs_raddr1,
    input logic [4:0] cs_waddr,
    input logic       cs_wen,
    input rv_imm_type cs_imm_sel,
    input logic       cs_op2_sel,
    input logic       cs_op3_sel
  );
    val     = cs_val;
    uop     = cs_uop;
    jal     = cs_jal;
    raddr0  = cs_raddr0;
    raddr1  = cs_raddr1;
    waddr   = cs_waddr;
    wen     = cs_wen;
    imm_sel = cs_imm_sel;
    op2_sel = cs_op2_sel;
    op3_sel = cs_op3_sel;
  endtask

  //----------------------------------------------------------------------
  // Common control signal table entries
  //----------------------------------------------------------------------

  // verilator lint_off UNUSEDPARAM
  localparam y = 1'b1;
  localparam n = 1'b0;

  // op2_sel
  localparam op2_imm = 1'b1;
  localparam op2_rf  = 1'b0;
  localparam op2_x   = 1'bx;

  // raddr
  logic [4:0] rs1, rs2, rd;
  assign rs1    = inst[19:15];
  assign rs2    = inst[24:20];
  assign rd     = inst[11:7];
  localparam rx = 5'b0; // Never stalls

  // jump
  localparam j_n    = 2'd0;
  localparam j_jal  = 2'd1;
  localparam j_jalr = 2'd2;

  // op3_sel
  localparam op3_mem = 1'b0;
  localparam op3_br  = 1'b1;
  localparam op3_x   = 1'bx;
  // verilator lint_on UNUSEDPARAM

  //----------------------------------------------------------------------
  // Control Signal Table
  //----------------------------------------------------------------------

  generate
    always_comb begin
      casez ( inst ) //          uop          jal     raddr0 raddr1 waddr wen imm_sel            op2_sel  op3_sel
        `RVI_INST_ADD:    cs( y, OP_ADD,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVI_INST_SUB:    cs( y, OP_SUB,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVI_INST_AND:    cs( y, OP_AND,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVI_INST_OR:     cs( y, OP_OR,       j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVI_INST_XOR:    cs( y, OP_XOR,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVI_INST_SLT:    cs( y, OP_SLT,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVI_INST_SLTU:   cs( y, OP_SLTU,     j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVI_INST_SRA:    cs( y, OP_SRA,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVI_INST_SRL:    cs( y, OP_SRL,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVI_INST_SLL:    cs( y, OP_SLL,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );

        `RVI_INST_ADDI:   cs( y, OP_ADD,      j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_x   );
        `RVI_INST_ANDI:   cs( y, OP_AND,      j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_x   );
        `RVI_INST_ORI:    cs( y, OP_OR,       j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_x   );
        `RVI_INST_XORI:   cs( y, OP_XOR,      j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_x   );
        `RVI_INST_SLTI:   cs( y, OP_SLT,      j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_x   );
        `RVI_INST_SLTIU:  cs( y, OP_SLTU,     j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_x   );
        `RVI_INST_SRAI:   cs( y, OP_SRA,      j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_x   );
        `RVI_INST_SRLI:   cs( y, OP_SRL,      j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_x   );
        `RVI_INST_SLLI:   cs( y, OP_SLL,      j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_x   );
        `RVI_INST_LUI:    cs( y, OP_LUI,      j_n,    rx,    rx,    rd,   y,  IMM_U,             op2_imm, op3_x   );
        `RVI_INST_AUIPC:  cs( y, OP_AUIPC,    j_n,    rx,    rx,    rd,   y,  IMM_U,             op2_imm, op3_x   );

        `RVI_INST_LB:     cs( y, OP_LB,       j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_mem );
        `RVI_INST_LH:     cs( y, OP_LH,       j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_mem );
        `RVI_INST_LW:     cs( y, OP_LW,       j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_mem );
        `RVI_INST_LBU:    cs( y, OP_LBU,      j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_mem );
        `RVI_INST_LHU:    cs( y, OP_LHU,      j_n,    rs1,   rx,    rd,   y,  IMM_I,             op2_imm, op3_mem );
        `RVI_INST_SB:     cs( y, OP_SB,       j_n,    rs1,   rs2,   rx,   n,  IMM_S,             op2_imm, op3_mem );
        `RVI_INST_SH:     cs( y, OP_SH,       j_n,    rs1,   rs2,   rx,   n,  IMM_S,             op2_imm, op3_mem );
        `RVI_INST_SW:     cs( y, OP_SW,       j_n,    rs1,   rs2,   rx,   n,  IMM_S,             op2_imm, op3_mem );
        `RVI_INST_FENCE:  cs( y, OP_ADD,      j_n,    5'b0,  5'b0,  5'b0, n,  rv_imm_type'('x),  op2_rf,  op3_x   );

        `RVI_INST_JAL:    cs( y, OP_JAL,      j_jal,  rx,    rx,    rd,   y,  IMM_J,             op2_x,   op3_x   );
        `RVI_INST_JALR:   cs( y, OP_JALR,     j_jalr, rs1,   rx,    rd,   y,  IMM_I,             op2_x,   op3_x   );
        `RVI_INST_BEQ:    cs( y, OP_BEQ,      j_n,    rs1,   rs2,   rx,   n,  IMM_B,             op2_rf,  op3_br  );
        `RVI_INST_BNE:    cs( y, OP_BNE,      j_n,    rs1,   rs2,   rx,   n,  IMM_B,             op2_rf,  op3_br  );
        `RVI_INST_BLT:    cs( y, OP_BLT,      j_n,    rs1,   rs2,   rx,   n,  IMM_B,             op2_rf,  op3_br  );
        `RVI_INST_BGE:    cs( y, OP_BGE,      j_n,    rs1,   rs2,   rx,   n,  IMM_B,             op2_rf,  op3_br  );
        `RVI_INST_BLTU:   cs( y, OP_BLTU,     j_n,    rs1,   rs2,   rx,   n,  IMM_B,             op2_rf,  op3_br  );
        `RVI_INST_BGEU:   cs( y, OP_BGEU,     j_n,    rs1,   rs2,   rx,   n,  IMM_B,             op2_rf,  op3_br  );

        `RVM_INST_MUL:    cs( y, OP_MUL,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVM_INST_MULH:   cs( y, OP_MULH,     j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVM_INST_MULHU:  cs( y, OP_MULHU,    j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVM_INST_MULHSU: cs( y, OP_MULHSU,   j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVM_INST_DIV:    cs( y, OP_DIV,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVM_INST_DIVU:   cs( y, OP_DIVU,     j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVM_INST_REM:    cs( y, OP_REM,      j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        `RVM_INST_REMU:   cs( y, OP_REMU,     j_n,    rs1,   rs2,   rd,   y,  rv_imm_type'('x),  op2_rf,  op3_x   );
        default:          cs( n, rv_uop'('x), j_n,    'x,    'x,    'x,   n,  rv_imm_type'('x),  'x,      'x      );
      endcase
    end
  endgenerate

endmodule

`endif // HW_DECODE_ISSUE_INSTDECODER_V
