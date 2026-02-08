//========================================================================
// InstRouterIQ.v
//========================================================================
// A router for instructions in a decode unit, to send instructions to the
// correct issue queue. This is similar to InstRouter, but with some additional
// logic to handle multiple queues that can support the same instruction, and
// using the available slot information from the queues to determine where to
// send instructions.

`ifndef HW_DECODE_INSTROUTERIQ_V
`define HW_DECODE_INSTROUTERIQ_V

`include "defs/UArch.v"

import UArch::*;

//------------------------------------------------------------------------
// InstRouterIQUnit
//------------------------------------------------------------------------
// An individual instruction router for a specific pipe

module InstRouterIQUnit #(
  parameter p_isa_subset = p_tinyrv1
) (
  input  rv_uop                    uop,
  input  logic                     uop_val,
  input  logic                     rdy,
  output logic                     pipe_rdy
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

  assign pipe_rdy = val_uop & uop_val;

endmodule

module PipePicker #(
  parameter int p_num_pipes      = 8,
  parameter int p_iq_entry_bits  = 4,
  parameter int p_pipe_idx_width = $clog2(p_num_pipes)
) (
  input  logic                       pipe_rdy         [p_num_pipes],
  input  logic [p_iq_entry_bits-1:0] pipe_avail_slots [p_num_pipes],
  output logic                       gnt_pipe         [p_num_pipes],
  output logic                       any_gnt
);
  logic [p_iq_entry_bits-1:0]  sel_slots;
  logic [p_pipe_idx_width-1:0] sel_pipe;

  always_comb begin

    // Initialize
    any_gnt   = 1'b0;
    sel_slots = '0;
    sel_pipe  = '0;
    for (int i = 0; i < p_num_pipes; i++)
      gnt_pipe[i] = 1'b0;

    // Iterate in increasing index order; ties keep first due to strict ">"
    for (int i = 0; i < p_num_pipes; i++) begin
      if (pipe_rdy[i]) begin
        if (!any_gnt || (pipe_avail_slots[i] > sel_slots)) begin
          any_gnt = 1'b1;
          sel_pipe = logic'(i);
          sel_slots = pipe_avail_slots[i];
        end
      end
    end

    // If at least one pipe is ready, grant the one with the most available
    // slots
    gnt_pipe[sel_pipe] = 1'b1;
  end

endmodule

//------------------------------------------------------------------------
// InstRouterIQ
//------------------------------------------------------------------------

module InstRouterIQ #(
  parameter p_num_pipes                                = 3,
  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1},
  parameter p_iq_depth                                 = 8,
  parameter p_iq_entry_bits                            = $clog2(p_iq_depth)
) (
  input  rv_uop uop,
  input  logic  val,
  output logic  xfer,

  input  logic                       pipe_rdy         [p_num_pipes],
  input  logic [p_iq_entry_bits-1:0] pipe_avail_slots [p_num_pipes],
  output logic                       pipe_val         [p_num_pipes]
);

  logic pipe_rdy_filtered [p_num_pipes];
  
  // Router units
  genvar i;
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: inst_router_units
      InstRouterIQUnit #(
        .p_isa_subset (p_pipe_subsets[i])
      ) router_unit (
        .uop           (uop),
        .uop_val       (val),
        .rdy           (pipe_rdy[i]),
        .pipe_rdy      (pipe_rdy_filtered[i])
      );
    end
  endgenerate

  // Choose the pipe based on operand support and available slots
  PipePicker #(
    .p_num_pipes     (p_num_pipes),
    .p_iq_entry_bits (p_iq_entry_bits)
  ) pipe_picker (
    .pipe_rdy    (pipe_rdy_filtered),
    .avail_slots (pipe_avail_slots),
    .gnt_pipe    (pipe_val),
    .any_gnt     (xfer)
  );

endmodule

`endif // HW_DECODE_INSTROUTERIQ_V
