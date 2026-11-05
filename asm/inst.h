//========================================================================
// inst.h
//========================================================================
// The instructions that are supported by the assembler, as well as
// functions to operate on the specifications

#ifndef INST_H
#define INST_H

#include <cstdint>
#include <string>
#include <vector>

enum inst_name_t {
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Register-Register Arithmetic
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  ADD,
  SUB,
  AND,
  OR,
  XOR,
  SLT,
  SLTU,
  SRA,
  SRL,
  SLL,

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Register-Immediate Arithmetic
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  ADDI,
  ANDI,
  ORI,
  XORI,
  SLTI,
  SLTIU,
  SRAI,
  SRLI,
  SLLI,
  LUI,
  AUIPC,

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Memory
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  LB,
  LH,
  LW,
  LBU,
  LHU,
  SB,
  SH,
  SW,
  FENCE,

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Unconditional Control Flow
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  JAL,
  JALR,
  BEQ,
  BNE,
  BLT,
  BGE,
  BLTU,
  BGEU,

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // System Calls
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  ECALL,
  EBREAK,

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // M-Extension
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  MUL,
  MULH,
  MULHSU,
  MULHU,
  DIV,
  DIVU,
  REM,
  REMU,

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // CSR
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  CSRRW,
  CSRRS,
  CSRRC,

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Floating Point
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  FADD_S,
  FSUB_S,
  FMUL_S,
  FLW,
  FSW,
  FSGNJ_S,
  FCVT_W_S,
  FMV_X_W,
  FMV_W_X
  
};

typedef struct {
  inst_name_t name;
  std::string assembly;
  uint32_t    match;
  uint32_t    mask;
} inst_spec_t;

//------------------------------------------------------------------------
// Instruction Specifications
//------------------------------------------------------------------------

const inst_spec_t inst_specs[] = {

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Register-Register Arithmetic
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    { ADD, "add    rd, rs1, rs2", 0x00000033, 0xFE00707F },
    { SUB, "sub    rd, rs1, rs2", 0x40000033, 0xFE00707F },
    { AND, "and    rd, rs1, rs2", 0x00007033, 0xFE00707F },
    { OR, "or     rd, rs1, rs2", 0x00006033, 0xFE00707F },
    { XOR, "xor    rd, rs1, rs2", 0x00004033, 0xFE00707F },
    { SLT, "slt    rd, rs1, rs2", 0x00002033, 0xFE00707F },
    { SLTU, "sltu   rd, rs1, rs2", 0x00003033, 0xFE00707F },
    { SRA, "sra    rd, rs1, rs2", 0x40005033, 0xFE00707F },
    { SRL, "srl    rd, rs1, rs2", 0x00005033, 0xFE00707F },
    { SLL, "sll    rd, rs1, rs2", 0x00001033, 0xFE00707F },

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Register-Immediate Arithmetic
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    { ADDI, "addi   rd, rs1, imm_i", 0x00000013, 0x0000707F },
    { ANDI, "andi   rd, rs1, imm_i", 0x00007013, 0x0000707F },
    { ORI, "ori    rd, rs1, imm_i", 0x00006013, 0x0000707F },
    { XORI, "xori   rd, rs1, imm_i", 0x00004013, 0x0000707F },
    { SLTI, "slti   rd, rs1, imm_i", 0x00002013, 0x0000707F },
    { SLTIU, "sltiu  rd, rs1, imm_i", 0x00003013, 0x0000707F },
    { SRAI, "srai   rd, rs1, imm_is", 0x40005013, 0xFE00707F },
    { SRLI, "srli   rd, rs1, imm_is", 0x00005013, 0xFE00707F },
    { SLLI, "slli   rd, rs1, imm_is", 0x00001013, 0xFE00707F },
    { LUI, "lui    rd, imm_u", 0x00000037, 0x0000007F },
    { AUIPC, "auipc  rd, imm_u", 0x00000017, 0x0000007F },

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Memory
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    { LB, "lb     rd, imm_i(rs1)", 0x00000003, 0x0000707F },
    { LH, "lh     rd, imm_i(rs1)", 0x00001003, 0x0000707F },
    { LW, "lw     rd, imm_i(rs1)", 0x00002003, 0x0000707F },
    { LBU, "lbu    rd, imm_i(rs1)", 0x00004003, 0x0000707F },
    { LHU, "lhu    rd, imm_i(rs1)", 0x00005003, 0x0000707F },
    { SB, "sb     rs2, imm_s(rs1)", 0x00000023, 0x0000707F },
    { SH, "sh     rs2, imm_s(rs1)", 0x00001023, 0x0000707F },
    { SW, "sw     rs2, imm_s(rs1)", 0x00002023, 0x0000707F },
    { FENCE, "fence  pred, succ", 0x0000000F, 0x0000707F },

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Control Flow
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    { JAL, "jal    rd, addr_j", 0x0000006F, 0x0000007F },
    { JALR, "jalr   rd, rs1, imm_i", 0x00000067, 0x0000707F },
    { BEQ, "beq    rs1, rs2, addr_b", 0x00000063, 0x0000707F },
    { BNE, "bne    rs1, rs2, addr_b", 0x00001063, 0x0000707F },
    { BLT, "blt    rs1, rs2, addr_b", 0x00004063, 0x0000707F },
    { BGE, "bge    rs1, rs2, addr_b", 0x00005063, 0x0000707F },
    { BLTU, "bltu   rs1, rs2, addr_b", 0x00006063, 0x0000707F },
    { BGEU, "bgeu   rs1, rs2, addr_b", 0x00007063, 0x0000707F },

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // System Calls
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    { ECALL, "ecall", 0x00000073, 0xFFFFFFFF },
    { EBREAK, "ebreak", 0x00100073, 0xFFFFFFFF },

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // M-Extension
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    { MUL, "mul    rd, rs1, rs2", 0x02000033, 0xFE00707F },
    { MULH, "mulh   rd, rs1, rs2", 0x02001033, 0xFE00707F },
    { MULHSU, "mulhsu rd, rs1, rs2", 0x02002033, 0xFE00707F },
    { MULHU, "mulhu  rd, rs1, rs2", 0x02003033, 0xFE00707F },
    { DIV, "div    rd, rs1, rs2", 0x02004033, 0xFE00707F },
    { DIVU, "divu   rd, rs1, rs2", 0x02005033, 0xFE00707F },
    { REM, "rem    rd, rs1, rs2", 0x02006033, 0xFE00707F },
    { REMU, "remu   rd, rs1, rs2", 0x02007033, 0xFE00707F },

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // CSR
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    { CSRRW,  "csrrw   rd, csr, rs1",  0x00001073, 0x0000707F }, 
    { CSRRS,  "csrrs   rd, csr, rs1",  0x00002073, 0x0000707F }, 
    { CSRRC,  "csrrc   rd, csr, rs1",  0x00003073, 0x0000707F }, 

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Floating Point
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    { FADD_S,   "fadd.s   frd, frs1, frs2", 0x00000053, 0xFE00007F },
    { FSUB_S,   "fsub.s   frd, frs1, frs2", 0x08000053, 0xFE00007F },
    { FMUL_S,   "fmul.s   frd, frs1, frs2", 0x10000053, 0xFE00007F },

    // flw: FP destination, INT base register
    { FLW,      "flw      frd, imm_i(rs1)", 0x00002007, 0x0000707F },

    // fsw: FP source, INT base register
    { FSW,      "fsw      frs2, imm_s(rs1)", 0x00002027, 0x0000707F },

    { FSGNJ_S,  "fsgnj.s  frd, frs1, frs2", 0x20000053, 0xFE00707F },

    // fcvt.w.s: INT destination, FP source
    { FCVT_W_S, "fcvt.w.s rd,  frs1",       0xC0000053, 0xFE00007F },

    // moves:
    { FMV_X_W,  "fmv.x.w  rd,  frs1",       0xE0000053, 0xFFF0707F },
    { FMV_W_X,  "fmv.w.x  frd, rs1",        0xF0000053, 0xFFF0707F },
  };

//------------------------------------------------------------------------
// Parse a given assembly into tokens
//------------------------------------------------------------------------

std::vector<std::string> tokenize( const std::string& assembly );

//------------------------------------------------------------------------
// Find the appropriate specification
//------------------------------------------------------------------------

const inst_spec_t* get_inst_spec( const std::string& inst_name );
const inst_spec_t* get_inst_spec( uint32_t inst_bin );

//------------------------------------------------------------------------
// Operate on specifications
//------------------------------------------------------------------------

std::string inst_spec_name( const inst_spec_t* spec );

#endif  // INST_H
