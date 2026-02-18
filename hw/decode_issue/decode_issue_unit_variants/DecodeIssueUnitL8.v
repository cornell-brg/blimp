//========================================================================
// DecodeIssueUnitL8.v
//========================================================================
// An in-order, single-issue decoder with register renaming and support for
// superscalar backend

`ifndef HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V
`define HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V

`ifndef SYNTHESIS
`include "asm/disassemble.v"
`endif

`include "defs/ISA.v"
`include "hw/decode_issue/InstDecoder.v"
`include "hw/decode_issue/ImmGen.v"
`include "hw/decode_issue/InstRouterIQ.v"
`include "hw/decode_issue/M2Regfile.v"
`include "hw/decode_issue/M2RenameTable.v"
`include "hw/decode_issue/IssueQueueInOrder.v"
`include "hw/util/MSeqAge.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/SquashNotif.v"

import ISA::*;

module DecodeIssueUnitL8 #(
  parameter p_num_pipes                                = 1,
  parameter p_num_phys_regs                            = 36,
  parameter p_num_fe_lanes                             = 2,
  parameter p_num_be_lanes                             = 2,
  parameter p_iq_depth                                 = 8,
  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1},
  parameter rv_op_vec p_ctrl_subset                    = OP_JAL_VEC  |
                                                         OP_JALR_VEC |
                                                         OP_BEQ_VEC  |
                                                         OP_BNE_VEC  |
                                                         OP_BLT_VEC  |
                                                         OP_BGE_VEC  |
                                                         OP_BLTU_VEC |
                                                         OP_BGEU_VEC
) (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // F <-> D Interface
  //----------------------------------------------------------------------

  F__DIntf.D_intf F [p_num_fe_lanes],

  //----------------------------------------------------------------------
  // D <-> X Interface
  //----------------------------------------------------------------------

  D__XIntf.D_intf Ex [p_num_pipes],

  //----------------------------------------------------------------------
  // Completion Notification
  //----------------------------------------------------------------------

  CompleteNotif.sub complete [p_num_be_lanes],

  //----------------------------------------------------------------------
  // Commit Notification
  //----------------------------------------------------------------------

  CommitNotif.sub commit [p_num_be_lanes],

  //----------------------------------------------------------------------
  // Squash Notification (one to request, one to receive)
  //----------------------------------------------------------------------

  SquashNotif.pub squash_pub,
  SquashNotif.sub squash_sub
);

  localparam p_seq_num_bits   = F.p_seq_num_bits;
  localparam p_phys_addr_bits = $clog2( p_num_phys_regs );
  
  //----------------------------------------------------------------------
  // Pipeline registers for F interface
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                      val;
    logic               [31:0] inst;
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
  } F_input;

  F_input F_reg      [p_num_fe_lanes];
  F_input F_reg_next [p_num_fe_lanes];
  logic   F_xfer     [p_num_fe_lanes];
  logic   F_xfer_all;
  logic   IQ_xfer    [p_num_fe_lanes];
  logic   IQ_xfer_all;

  logic should_squash;

  genvar i;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: F_REG_GEN
      always_ff @( posedge clk ) begin
        if ( rst )
          F_reg[i] <= '{ val: 1'b0, inst: 'x, pc: 'x, seq_num: 'x };
        else
          F_reg[i] <= F_reg_next[i];
      end

      always_comb begin
        F_xfer[i] = F[i].val & F[i].rdy;

        if ( F_xfer[i] )
          F_reg_next = '{ val: 1'b1, inst: F.inst, pc: F.pc, seq_num: F.seq_num };
        else if ( IQ_xfer | should_squash )
          F_reg_next = '{ val: 1'b0, inst: 'x, pc: 'x, seq_num: 'x };
        else
          F_reg_next = F_reg;
      end
    end
  endgenerate

  always_comb begin
    F_xfer_all  = 1'b1;
    IQ_xfer_all = 1'b1;
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      F_xfer_all &= F_xfer[i];
      IQ_xfer_all &= IQ_xfer[i];
    end
  end

  //----------------------------------------------------------------------
  // Instantiate Decoder, Regfile, ImmGen
  //----------------------------------------------------------------------

  logic       decoder_val     [p_num_fe_lanes];
  rv_uop      decoder_uop     [p_num_fe_lanes];
  logic [4:0] decoder_raddr0  [p_num_fe_lanes];
  logic [4:0] decoder_raddr1  [p_num_fe_lanes];
  logic [4:0] decoder_waddr   [p_num_fe_lanes];
  logic       decoder_wen     [p_num_fe_lanes];
  rv_imm_type decoder_imm_sel [p_num_fe_lanes];
  logic       decoder_op2_sel [p_num_fe_lanes];
  logic [1:0] decoder_jal     [p_num_fe_lanes];
  logic       decoder_op3_sel [p_num_fe_lanes];
  
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: DECODER_GEN
      InstDecoder decoder (
        .val     (decoder_val[i]),
        .inst    (F_reg[i].inst),
        .uop     (decoder_uop[i]),
        .raddr0  (decoder_raddr0[i]),
        .raddr1  (decoder_raddr1[i]),
        .waddr   (decoder_waddr[i]),
        .wen     (decoder_wen[i]),
        .imm_sel (decoder_imm_sel[i]),
        .op2_sel (decoder_op2_sel[i]),
        .jal     (decoder_jal[i]),
        .op3_sel (decoder_op3_sel[i])
      );
    end
  endgenerate

  logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes];
  logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes];
  logic                        alloc_rdy   [p_num_fe_lanes];
  logic                        alloc_rdy_all;

  logic [p_phys_addr_bits-1:0] lookup_new_inst_preg [2][p_num_fe_lanes];
  logic                        lookup_new_inst_en   [2][p_num_fe_lanes];

  logic [p_phys_addr_bits-1:0] lookup_iq_preg    [p_num_pipes][2];
  logic                        lookup_iq_en      [p_num_pipes][2];
  logic                        lookup_iq_pending [p_num_pipes][2];

  logic alloc_en [p_num_fe_lanes];

  always_comb begin
    alloc_rdy_all = 1'b1;
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      lookup_new_inst_en[0][i] = 1'b1;
      lookup_new_inst_en[1][i] = 1'b1;
      alloc_rdy_all &= alloc_rdy[i];
      alloc_en[i] = alloc_rdy_all & decoder_wen[i] & IQ_xfer_all & !should_squash;
    end
  end

  // TODO: implement M3RenameTable with multiple allocation ports instead of
  // just replicating the logic for each FE lane

  M3RenameTable #(
    .p_num_phys_regs    (p_num_phys_regs),
    .p_num_lookup_ports (p_num_pipes),
    .p_num_fe_lanes     (p_num_fe_lanes),
    .p_num_be_lanes     (p_num_be_lanes)
  ) rename_table (
    .clk            (clk),
    .rst            (rst),

    .alloc_areg     (decoder_waddr),
    .alloc_preg     (alloc_preg),
    .alloc_ppreg    (alloc_ppreg),
    .alloc_en       (alloc_en),
    .alloc_rdy      (alloc_rdy),

    .lookup_new_inst_areg    ('{decoder_raddr0, decoder_raddr1}),
    .lookup_new_inst_en      (lookup_new_inst_en),
    .lookup_new_inst_preg    (lookup_new_inst_preg),

    .lookup_iq_preg    (lookup_iq_preg),
    .lookup_iq_en      (lookup_iq_en),
    .lookup_iq_pending (lookup_iq_pending),

    .complete       (complete),
    .commit         (commit)
  );

  logic [p_phys_addr_bits-1:0] complete_preg        [p_num_be_lanes];
  logic [31:0]                 complete_wdata       [p_num_be_lanes];
  logic                        complete_wen_and_val [p_num_be_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin: COMPLETE_SIGNALS_GEN
      assign complete_preg[i]        = complete[i].preg;
      assign complete_wdata[i]       = complete[i].wdata;
      assign complete_wen_and_val[i] = complete[i].wen & complete[i].val;
    end
  endgenerate

  logic [p_phys_addr_bits-1:0] raddr [p_num_pipes][2];
  logic [31:0]                 rdata [p_num_pipes][2];

  M2Regfile #(
    .p_entry_bits       (32),
    .p_num_regs         (p_num_phys_regs),
    .p_num_lookup_ports (p_num_pipes),
    .p_num_be_lanes     (p_num_be_lanes)
  ) regfile (
    .clk                (clk),
    .rst                (rst),
    .raddr              (raddr),
    .rdata              (rdata),
    .waddr              (complete_preg),
    .wdata              (complete_wdata),
    .wen                (complete_wen_and_val)
  );

  logic [31:0] imm [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin
      ImmGen imm_gen (
        .inst    (F_reg[i].inst),
        .imm_sel (decoder_imm_sel[i]),
        .imm     (imm[i])
      );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Squashing
  //----------------------------------------------------------------------

  // TODO: need to get oldest jump instruction in current instruction window if
  // multiple jump instructions

  logic [31:0] jump_target;
  logic [31:0] jump_base;
  always_comb begin
    case( decoder_jal )
      2'd1:    jump_target = F_reg.pc + imm;                   // JAL
      2'd2:    jump_target = (jump_base + imm) & 32'hFFFFFFFE; // JALR
      default: jump_target = 'x;
    endcase
  end

  logic squash_sent;
  always_ff @( posedge clk ) begin
    if( rst )
      squash_sent <= 1'b0;
    else if( F_xfer )
      squash_sent <= 1'b0;
    else if( squash_pub.val )
      squash_sent <= 1'b1;
  end

  assign squash_pub.val     = (decoder_jal != 0) & F_reg.val & !squash_sent & alloc_rdy;
  assign squash_pub.target  = jump_target;
  assign squash_pub.seq_num = F_reg.seq_num;

  //----------------------------------------------------------------------
  // Determine whether we need to squash ourself
  //----------------------------------------------------------------------
  
  MSeqAge #(
    .p_num_be_lanes (p_num_be_lanes)
  ) seq_age (
    .*
  );

  // TODO: should squash should check oldest instruction in IW

  assign should_squash = squash_sub.val & 
                         seq_age.is_older( squash_sub.seq_num, F_reg.seq_num );

  //----------------------------------------------------------------------
  // Route the instruction to issue queue based on uop
  //----------------------------------------------------------------------

  logic                        iq_rdy         [p_num_pipes];
  logic [$clog2(p_iq_depth):0] iq_avail_slots [p_num_pipes];
  logic                        iq_val         [p_num_pipes];

  // TODO: Need multi-instruction arbiter for multiple FE lanes, only issue
  // instructions up to and including the branch

  InstRouterIQ #(
    .p_num_pipes     (p_num_pipes),
    .p_pipe_subsets  (p_pipe_subsets),
    .p_iq_depth      (p_iq_depth)
  ) inst_router (
    .uop            (decoder_uop),
    .val            (F_reg.val & decoder_val & !should_squash & alloc_rdy),
    .iq_rdy         (iq_rdy),
    .iq_avail_slots (iq_avail_slots),
    .iq_val         (iq_val),
    .xfer           (IQ_xfer)
  );

  // TODO: not ready to receive new IW unless all instructions in current IW are
  // transferred to IQs

  assign F.rdy = (IQ_xfer_all & alloc_rdy & decoder_val) | 
                 should_squash                       | 
                 (!F_reg.val);

  //----------------------------------------------------------------------
  // Issue queues (bypass any for control subset)
  //----------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_pipes; i++ ) begin: IQ_GEN
      IssueQueueInOrder #(
        .p_depth        (p_iq_depth),
        .p_num_regs     (p_num_phys_regs),
        .p_seq_num_bits (p_seq_num_bits),
        .p_num_be_lanes (p_num_be_lanes),
        .p_bypass       (p_pipe_subsets[p_num_pipes-i-1] == p_ctrl_subset)
      ) issue_queue (
        .clk                     (clk),
        .rst                     (rst),

        // Insert
        .ins_msg_pc              (F_reg.pc),
        .ins_msg_preg            (lookup_new_inst_preg),
        .ins_msg_decoder_uop     (decoder_uop),
        .ins_msg_decoder_waddr   (decoder_waddr),
        .ins_msg_imm             (imm),
        .ins_msg_decoder_op2_sel (decoder_op2_sel),
        .ins_msg_decoder_op3_sel (decoder_op3_sel),
        .ins_msg_seq_num         (F_reg.seq_num),
        .ins_msg_alloc_preg      (alloc_preg),
        .ins_msg_alloc_ppreg     (alloc_ppreg),
        .ins_en                  (iq_val[i]),
        .ins_rdy                 (iq_rdy[i]),
        .avail_slots             (iq_avail_slots[i]),

        // Dequeue 
        .Ex                      (Ex[i]),

        // Rename Table Access 
        .rt_lookup_preg          (lookup_iq_preg[i]),
        .rt_lookup_pending       (lookup_iq_pending[i]),
        .rt_lookup_en            (lookup_iq_en[i]),

        // Register File Access 
        .rf_raddr                (raddr[i]),
        .rf_rdata                (rdata[i]),

        // Complete interface 
        .complete                (complete)
      );

      // assuming exactly one CTRL_XU - possibly improve this?
      if ( p_pipe_subsets[p_num_pipes-i-1] == p_ctrl_subset ) begin
        assign jump_base = rdata[i][0];
      end
    end
  endgenerate

  logic [p_seq_num_bits-1:0] unused_seq_num_bits [p_num_be_lanes];
  genvar k;
  generate
    for( k = 0; k < p_num_be_lanes; k = k + 1 ) begin: UNUSED_COMPLETE_SEQ_NUM
      assign unused_seq_num_bits[k] = complete[k].seq_num;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS  
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  function string trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    if( F_reg.val & F.rdy )
      trace = $sformatf("%x: %-30s", F_reg.seq_num, disassemble(F_reg.inst, F_reg.pc) );
    else
      trace = {(32 + ceil_div_4( p_seq_num_bits )){" "}};
  endfunction
`endif

endmodule

`endif // HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL8_V
