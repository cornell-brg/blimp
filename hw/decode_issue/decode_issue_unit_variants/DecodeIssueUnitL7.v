//========================================================================
// DecodeIssueUnitL7.v
//========================================================================
// An in-order, single-issue decoder with register renaming and support for
// superscalar backend

`ifndef HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL7_V
`define HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL7_V

`ifndef SYNTHESIS
`include "asm/disassemble.v"
`endif

`include "defs/ISA.v"
`include "hw/decode_issue/InstDecoder.v"
`include "hw/decode_issue/ImmGen.v"
`include "hw/decode_issue/SSInstRouter.v"
`include "hw/decode_issue/SSRegfileL2.v"
`include "hw/decode_issue/SSRenameTableL2.v"
`include "hw/decode_issue/IssueQueueInOrder.v"
`include "hw/util/SSSeqAge.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/SquashNotif.v"

import ISA::*;

module DecodeIssueUnitL7 #(
  parameter p_num_pipes                                = 1,
  parameter p_num_phys_regs                            = 36,
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

  F__DIntf.D_intf F,

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

  F_input F_reg;
  F_input F_reg_next;
  logic   F_xfer;
  logic   IQ_xfer;

  logic should_squash;

  always_ff @( posedge clk ) begin
    if ( rst )
      F_reg <= '{ val: 1'b0, inst: '0, pc: '0, seq_num: '0 };
    else
      F_reg <= F_reg_next;
  end

  always_comb begin
    F_xfer = F.val & F.rdy;

    if ( F_xfer )
      F_reg_next = '{ val: 1'b1, inst: F.inst, pc: F.pc, seq_num: F.seq_num };
    else if ( IQ_xfer | should_squash )
      F_reg_next = '{ val: 1'b0, inst: '0, pc: '0, seq_num: '0 };
    else
      F_reg_next = F_reg;
  end

  //----------------------------------------------------------------------
  // Instantiate Decoder, Regfile, ImmGen
  //----------------------------------------------------------------------

  logic       decoder_val;
  rv_uop      decoder_uop;
  logic [4:0] decoder_raddr0;
  logic [4:0] decoder_raddr1;
  logic [4:0] decoder_waddr;
  logic       decoder_wen;
  rv_imm_type decoder_imm_sel;
  logic       decoder_op2_sel;
  logic [1:0] decoder_jal;
  logic       decoder_op3_sel;
  
  InstDecoder decoder (
    .val     (decoder_val),
    .inst    (F_reg.inst),
    .uop     (decoder_uop),
    .raddr0  (decoder_raddr0),
    .raddr1  (decoder_raddr1),
    .waddr   (decoder_waddr),
    .wen     (decoder_wen),
    .imm_sel (decoder_imm_sel),
    .op2_sel (decoder_op2_sel),
    .jal     (decoder_jal),
    .op3_sel (decoder_op3_sel)
  );

  logic [p_phys_addr_bits-1:0] alloc_preg, alloc_ppreg;
  logic                        alloc_rdy;

  logic [p_phys_addr_bits-1:0] lookup_new_inst_preg [2];
  logic                        lookup_new_inst_en   [2];

  logic [p_phys_addr_bits-1:0] lookup_iq_preg    [p_num_pipes][2];
  logic                        lookup_iq_en      [p_num_pipes][2];
  logic                        lookup_iq_pending [p_num_pipes][2];

  assign lookup_new_inst_en = '{1'b1, 1'b1};

  SSRenameTableL2 #(
    .p_num_phys_regs    (p_num_phys_regs),
    .p_num_lookup_ports (p_num_pipes),
    .p_num_be_lanes     (p_num_be_lanes)
  ) rename_table (
    .clk            (clk),
    .rst            (rst),

    .alloc_areg     (decoder_waddr),
    .alloc_preg     (alloc_preg),
    .alloc_ppreg    (alloc_ppreg),
    .alloc_en       (alloc_rdy & decoder_wen & IQ_xfer & !should_squash),
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

  SSRegfileL2 #(
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

  logic [31:0] imm;

  ImmGen imm_gen (
    .inst    (F_reg.inst),
    .imm_sel (decoder_imm_sel),
    .imm     (imm)
  );

  //----------------------------------------------------------------------
  // Squashing
  //----------------------------------------------------------------------

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
  
  logic [p_seq_num_bits-1:0] oldest_seq_num;

  SSSeqAge #(
    .p_num_be_lanes  (p_num_be_lanes),
    .p_seq_num_bits  (p_seq_num_bits),
    .p_num_phys_regs (p_num_phys_regs)
  ) seq_age (
    .*
  );

  assign should_squash = squash_sub.val & 
                         seq_age.is_older( squash_sub.seq_num, F_reg.seq_num );

  //----------------------------------------------------------------------
  // Route the instruction to issue queue based on uop
  //----------------------------------------------------------------------

  logic                        iq_rdy         [p_num_pipes];
  logic [$clog2(p_iq_depth):0] iq_avail_slots [p_num_pipes];
  logic                        iq_val         [p_num_pipes];

  SSInstRouter #(
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

  assign F.rdy = (IQ_xfer & alloc_rdy & decoder_val) | 
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

`endif // HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL7_V
