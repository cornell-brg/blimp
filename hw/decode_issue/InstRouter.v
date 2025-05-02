//========================================================================
// InstRouter.v
//========================================================================
// A router for instructions in a decode unit, to send instructions to the
// correct pipe

`ifndef HW_DECODE_INSTROUTER_V
`define HW_DECODE_INSTROUTER_V

`include "defs/UArch.v"

import UArch::*;

//------------------------------------------------------------------------
// InstRouterUnit
//------------------------------------------------------------------------
// An individual instruction router for a specific pipe

module InstRouterUnit #(
  parameter p_isa_subset = p_tinyrv1
) (
  input  rv_uop uop,
  input  logic  uop_val,
  input  logic  already_found,
  input  logic  rdy,

  output logic  val,
  output logic  been_found
);

  logic val_uop;
  
  generate
    always_comb begin
      val_uop = 0;

      if( in_subset(p_isa_subset, OP_ADD_VEC    ) ) val_uop |= ( uop == OP_ADD    );
      if( in_subset(p_isa_subset, OP_SUB_VEC    ) ) val_uop |= ( uop == OP_SUB    );
      if( in_subset(p_isa_subset, OP_AND_VEC    ) ) val_uop |= ( uop == OP_AND    );
      if( in_subset(p_isa_subset, OP_OR_VEC     ) ) val_uop |= ( uop == OP_OR     );
      if( in_subset(p_isa_subset, OP_XOR_VEC    ) ) val_uop |= ( uop == OP_XOR    );
      if( in_subset(p_isa_subset, OP_SLT_VEC    ) ) val_uop |= ( uop == OP_SLT    );
      if( in_subset(p_isa_subset, OP_SLTU_VEC   ) ) val_uop |= ( uop == OP_SLTU   );
      if( in_subset(p_isa_subset, OP_SRA_VEC    ) ) val_uop |= ( uop == OP_SRA    );
      if( in_subset(p_isa_subset, OP_SRL_VEC    ) ) val_uop |= ( uop == OP_SRL    );
      if( in_subset(p_isa_subset, OP_SLL_VEC    ) ) val_uop |= ( uop == OP_SLL    );
      if( in_subset(p_isa_subset, OP_LUI_VEC    ) ) val_uop |= ( uop == OP_LUI    );
      if( in_subset(p_isa_subset, OP_AUIPC_VEC  ) ) val_uop |= ( uop == OP_AUIPC  );

      if( in_subset(p_isa_subset, OP_LB_VEC     ) ) val_uop |= ( uop == OP_LB     );
      if( in_subset(p_isa_subset, OP_LH_VEC     ) ) val_uop |= ( uop == OP_LH     );
      if( in_subset(p_isa_subset, OP_LW_VEC     ) ) val_uop |= ( uop == OP_LW     );
      if( in_subset(p_isa_subset, OP_LBU_VEC    ) ) val_uop |= ( uop == OP_LBU    );
      if( in_subset(p_isa_subset, OP_LHU_VEC    ) ) val_uop |= ( uop == OP_LHU    );
      if( in_subset(p_isa_subset, OP_SB_VEC     ) ) val_uop |= ( uop == OP_SB     );
      if( in_subset(p_isa_subset, OP_SH_VEC     ) ) val_uop |= ( uop == OP_SH     );
      if( in_subset(p_isa_subset, OP_SW_VEC     ) ) val_uop |= ( uop == OP_SW     );

      if( in_subset(p_isa_subset, OP_JAL_VEC    ) ) val_uop |= ( uop == OP_JAL    );
      if( in_subset(p_isa_subset, OP_JALR_VEC   ) ) val_uop |= ( uop == OP_JALR   );
      if( in_subset(p_isa_subset, OP_BEQ_VEC    ) ) val_uop |= ( uop == OP_BEQ    );
      if( in_subset(p_isa_subset, OP_BNE_VEC    ) ) val_uop |= ( uop == OP_BNE    );
      if( in_subset(p_isa_subset, OP_BLT_VEC    ) ) val_uop |= ( uop == OP_BLT    );
      if( in_subset(p_isa_subset, OP_BGE_VEC    ) ) val_uop |= ( uop == OP_BGE    );
      if( in_subset(p_isa_subset, OP_BLTU_VEC   ) ) val_uop |= ( uop == OP_BLTU   );
      if( in_subset(p_isa_subset, OP_BGEU_VEC   ) ) val_uop |= ( uop == OP_BGEU   );

      if( in_subset(p_isa_subset, OP_MUL_VEC    ) ) val_uop |= ( uop == OP_MUL    );
      if( in_subset(p_isa_subset, OP_MULH_VEC   ) ) val_uop |= ( uop == OP_MULH   );
      if( in_subset(p_isa_subset, OP_MULHSU_VEC ) ) val_uop |= ( uop == OP_MULHSU );
      if( in_subset(p_isa_subset, OP_MULHU_VEC  ) ) val_uop |= ( uop == OP_MULHU  );
      if( in_subset(p_isa_subset, OP_DIV_VEC    ) ) val_uop |= ( uop == OP_DIV    );
      if( in_subset(p_isa_subset, OP_DIVU_VEC   ) ) val_uop |= ( uop == OP_DIVU   );
      if( in_subset(p_isa_subset, OP_REM_VEC    ) ) val_uop |= ( uop == OP_REM    );
      if( in_subset(p_isa_subset, OP_REMU_VEC   ) ) val_uop |= ( uop == OP_REMU   );
    end
  endgenerate

  assign val        = (val_uop & uop_val) & (!already_found);
  assign been_found = (val_uop & rdy)     | already_found;

endmodule

//------------------------------------------------------------------------
// InstRouter
//------------------------------------------------------------------------

module InstRouter #(
  parameter p_num_pipes                                = 3,
  parameter p_phys_addr_bits                           = 6,
  parameter p_seq_num_bits                             = 5,
  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1}
) (
  input rv_uop    uop,
  input  logic    val,
  output logic    xfer,

  input  logic                 [31:0] ex_pc,
  input  logic                 [31:0] ex_op1,
  input  logic                 [31:0] ex_op2,
  input  rv_uop                       ex_uop,
  input  logic                  [4:0] ex_waddr,
  input  logic   [p_seq_num_bits-1:0] ex_seq_num,
  input  logic [p_phys_addr_bits-1:0] ex_preg,
  input  logic [p_phys_addr_bits-1:0] ex_ppreg,
  input  logic                 [31:0] ex_op3,

  D__XIntf.D_intf Ex [p_num_pipes-1:0]
);

  // verilator lint_off UNUSEDSIGNAL
  logic found [p_num_pipes:0];
  // verilator lint_on UNUSEDSIGNAL
  assign found[0] = 1'b0;
  
  logic [p_num_pipes-1:0] xfer_vec;
  
  genvar i;
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: inst_router_units
      InstRouterUnit #(p_pipe_subsets[i]) router_unit (
        .uop           (uop),
        .uop_val       (val),
        .already_found (found[i]),
        .rdy           (Ex[i].rdy),
        .val           (Ex[i].val),
        .been_found    (found[i+1])
      );

      assign xfer_vec[i] = Ex[i].val & Ex[i].rdy;
      assign Ex[i].pc           = ex_pc;
      assign Ex[i].op1          = ex_op1;
      assign Ex[i].op2          = ex_op2;
      assign Ex[i].uop          = ex_uop;
      assign Ex[i].waddr        = ex_waddr;
      assign Ex[i].seq_num      = ex_seq_num;
      assign Ex[i].preg         = ex_preg;
      assign Ex[i].ppreg        = ex_ppreg;
      assign Ex[i].op3          = ex_op3;
    end
  endgenerate

  assign xfer = (|xfer_vec);

endmodule

`endif // HW_DECODE_INSTROUTER_V
