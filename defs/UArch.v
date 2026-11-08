//========================================================================
// UArch.v
//========================================================================
// Common definitions to use as part of the Blimp microarchitecture
// framework

`ifndef DEFS_UARCH_V
`define DEFS_UARCH_V

package UArch;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Micro-opcodes
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // A linearization of opcodes to indicate a specific instruction type

  parameter num_ops = 48;

  typedef enum logic [$clog2(num_ops)-1:0] {
    // Arithmetic
    OP_ADD,
    OP_SUB,
    OP_AND,
    OP_OR,
    OP_XOR,
    OP_SLT,
    OP_SLTU,
    OP_SRA,
    OP_SRL,
    OP_SLL,
    OP_LUI,
    OP_AUIPC,

    // Memory
    OP_LB,
    OP_LH,
    OP_LW,
    OP_LBU,
    OP_LHU,
    OP_SB,
    OP_SH,
    OP_SW,

    // Control Flow
    OP_JAL,
    OP_JALR,
    OP_BEQ,
    OP_BNE,
    OP_BLT,
    OP_BGE,
    OP_BLTU,
    OP_BGEU,
    
    // M-Extension
    OP_MUL,
    OP_MULH,
    OP_MULHU,
    OP_MULHSU,
    OP_DIV,
    OP_DIVU,
    OP_REM,
    OP_REMU,

    // CSR
    OP_CSRRW,
    OP_CSRRS,
    OP_CSRRC,

    // FP
    OP_FADD_S,
    OP_FSUB_S,
    OP_FMUL_S,
    OP_FLW,
    OP_FSW,
    OP_FSGNJ_S,
    OP_FCVT_W_S,
    OP_FMV_X_W,
    OP_FMV_W_X
    
  } rv_uop;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Supported operations
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Definitions of the subsets of an ISA that can be supported. We use a
  // one-hot encoding to specify combinations of operands that are
  // supported

  typedef logic [num_ops-1:0] rv_op_vec;

  // verilator lint_off UNUSEDPARAM
  parameter OP_ADD_VEC    = num_ops'(1 << OP_ADD    );
  parameter OP_SUB_VEC    = num_ops'(1 << OP_SUB    );
  parameter OP_AND_VEC    = num_ops'(1 << OP_AND    );
  parameter OP_OR_VEC     = num_ops'(1 << OP_OR     );
  parameter OP_XOR_VEC    = num_ops'(1 << OP_XOR    );
  parameter OP_SLT_VEC    = num_ops'(1 << OP_SLT    );
  parameter OP_SLTU_VEC   = num_ops'(1 << OP_SLTU   );
  parameter OP_SRA_VEC    = num_ops'(1 << OP_SRA    );
  parameter OP_SRL_VEC    = num_ops'(1 << OP_SRL    );
  parameter OP_SLL_VEC    = num_ops'(1 << OP_SLL    );
  parameter OP_LUI_VEC    = num_ops'(1 << OP_LUI    );
  parameter OP_AUIPC_VEC  = num_ops'(1 << OP_AUIPC  );
  parameter OP_LB_VEC     = num_ops'(1 << OP_LB     );
  parameter OP_LH_VEC     = num_ops'(1 << OP_LH     );
  parameter OP_LW_VEC     = num_ops'(1 << OP_LW     );
  parameter OP_LBU_VEC    = num_ops'(1 << OP_LBU    );
  parameter OP_LHU_VEC    = num_ops'(1 << OP_LHU    );
  parameter OP_SB_VEC     = num_ops'(1 << OP_SB     );
  parameter OP_SH_VEC     = num_ops'(1 << OP_SH     );
  parameter OP_SW_VEC     = num_ops'(1 << OP_SW     );
  parameter OP_JAL_VEC    = num_ops'(1 << OP_JAL    );
  parameter OP_JALR_VEC   = num_ops'(1 << OP_JALR   );
  parameter OP_BEQ_VEC    = num_ops'(1 << OP_BEQ    );
  parameter OP_BNE_VEC    = num_ops'(1 << OP_BNE    );
  parameter OP_BLT_VEC    = num_ops'(1 << OP_BLT    );
  parameter OP_BGE_VEC    = num_ops'(1 << OP_BGE    );
  parameter OP_BLTU_VEC   = num_ops'(1 << OP_BLTU   );
  parameter OP_BGEU_VEC   = num_ops'(1 << OP_BGEU   );
  parameter OP_MUL_VEC    = num_ops'(1 << OP_MUL    );
  parameter OP_MULH_VEC   = num_ops'(1 << OP_MULH   );
  parameter OP_MULHU_VEC  = num_ops'(1 << OP_MULHU  );
  parameter OP_MULHSU_VEC = num_ops'(1 << OP_MULHSU );
  parameter OP_DIV_VEC    = num_ops'(1 << OP_DIV    );
  parameter OP_DIVU_VEC   = num_ops'(1 << OP_DIVU   );
  parameter OP_REM_VEC    = num_ops'(1 << OP_REM    );
  parameter OP_REMU_VEC   = num_ops'(1 << OP_REMU   );
  parameter OP_FADD_VEC   = num_ops'(1 << OP_FADD_S );
  parameter OP_FSUB_VEC   = num_ops'(1 << OP_FSUB_S );
  parameter OP_FMUL_VEC   = num_ops'(1 << OP_FMUL_S );
  parameter OP_FLW_VEC    = num_ops'(1 << OP_FLW    );
  parameter OP_FSW_VEC    = num_ops'(1 << OP_FSW    );
  parameter OP_FSGNJ_VEC  = num_ops'(1 << OP_FSGNJ_S);
  parameter OP_FCVT_W_S_VEC = num_ops'(1 << OP_FCVT_W_S);
  parameter OP_FMV_X_W_VEC = num_ops'(1 << OP_FMV_X_W);
  parameter OP_FMV_W_X_VEC = num_ops'(1 << OP_FMV_W_X);

  parameter p_tinyrv1 = OP_ADD_VEC
                      | OP_MUL_VEC
                      | OP_LW_VEC
                      | OP_SW_VEC
                      | OP_JAL_VEC
                      | OP_JALR_VEC
                      | OP_BNE_VEC
                      | OP_FADD_VEC
                      | OP_FSUB_VEC
                      | OP_FLW_VEC
                      | OP_FSW_VEC;
  // verilator lint_on UNUSEDPARAM

  function automatic logic in_subset( 
    logic [num_ops-1:0] subset, 
    logic [num_ops-1:0] op_vec
  );
    return (subset & op_vec) > 0;
  endfunction

endpackage

`endif  // DEFS_UARCH_V
