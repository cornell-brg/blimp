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

  localparam num_ops = 36;

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
    OP_REMU
  } rv_uop;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Supported operations
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Definitions of the subsets of an ISA that can be supported. We use a
  // one-hot encoding to specify combinations of operands that are
  // supported

  typedef logic [num_ops-1:0] rv_op_vec;

  // verilator lint_off UNUSEDPARAM
  localparam OP_ADD_VEC    = num_ops'(1 << OP_ADD    );
  localparam OP_SUB_VEC    = num_ops'(1 << OP_SUB    );
  localparam OP_AND_VEC    = num_ops'(1 << OP_AND    );
  localparam OP_OR_VEC     = num_ops'(1 << OP_OR     );
  localparam OP_XOR_VEC    = num_ops'(1 << OP_XOR    );
  localparam OP_SLT_VEC    = num_ops'(1 << OP_SLT    );
  localparam OP_SLTU_VEC   = num_ops'(1 << OP_SLTU   );
  localparam OP_SRA_VEC    = num_ops'(1 << OP_SRA    );
  localparam OP_SRL_VEC    = num_ops'(1 << OP_SRL    );
  localparam OP_SLL_VEC    = num_ops'(1 << OP_SLL    );
  localparam OP_LUI_VEC    = num_ops'(1 << OP_LUI    );
  localparam OP_AUIPC_VEC  = num_ops'(1 << OP_AUIPC  );
  localparam OP_LB_VEC     = num_ops'(1 << OP_LB     );
  localparam OP_LH_VEC     = num_ops'(1 << OP_LH     );
  localparam OP_LW_VEC     = num_ops'(1 << OP_LW     );
  localparam OP_LBU_VEC    = num_ops'(1 << OP_LBU    );
  localparam OP_LHU_VEC    = num_ops'(1 << OP_LHU    );
  localparam OP_SB_VEC     = num_ops'(1 << OP_SB     );
  localparam OP_SH_VEC     = num_ops'(1 << OP_SH     );
  localparam OP_SW_VEC     = num_ops'(1 << OP_SW     );
  localparam OP_JAL_VEC    = num_ops'(1 << OP_JAL    );
  localparam OP_JALR_VEC   = num_ops'(1 << OP_JALR   );
  localparam OP_BEQ_VEC    = num_ops'(1 << OP_BEQ    );
  localparam OP_BNE_VEC    = num_ops'(1 << OP_BNE    );
  localparam OP_BLT_VEC    = num_ops'(1 << OP_BLT    );
  localparam OP_BGE_VEC    = num_ops'(1 << OP_BGE    );
  localparam OP_BLTU_VEC   = num_ops'(1 << OP_BLTU   );
  localparam OP_BGEU_VEC   = num_ops'(1 << OP_BGEU   );
  localparam OP_MUL_VEC    = num_ops'(1 << OP_MUL    );
  localparam OP_MULH_VEC   = num_ops'(1 << OP_MULH   );
  localparam OP_MULHU_VEC  = num_ops'(1 << OP_MULHU  );
  localparam OP_MULHSU_VEC = num_ops'(1 << OP_MULHSU );
  localparam OP_DIV_VEC    = num_ops'(1 << OP_DIV    );
  localparam OP_DIVU_VEC   = num_ops'(1 << OP_DIVU   );
  localparam OP_REM_VEC    = num_ops'(1 << OP_REM    );
  localparam OP_REMU_VEC   = num_ops'(1 << OP_REMU   );

  localparam p_tinyrv1 = OP_ADD_VEC
                       | OP_MUL_VEC
                       | OP_LW_VEC
                       | OP_SW_VEC
                       | OP_JAL_VEC
                       | OP_JALR_VEC
                       | OP_BNE_VEC;
  // verilator lint_on UNUSEDPARAM

  function automatic logic in_subset( 
    logic [num_ops-1:0] subset, 
    logic [num_ops-1:0] op_vec
  );
    return (subset & op_vec) > 0;
  endfunction

endpackage

`endif  // DEFS_UARCH_V
