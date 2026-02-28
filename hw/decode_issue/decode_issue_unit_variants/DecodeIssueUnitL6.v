//========================================================================
// DecodeIssueUnitL6.v
//========================================================================
// An in-order, single-issue decoder with register renaming and support for
// superscalar backend

`ifndef HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL6_V
`define HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL6_V

`ifndef SYNTHESIS
`include "asm/disassemble.v"
`endif

`include "defs/ISA.v"
`include "hw/decode_issue/InstDecoder.v"
`include "hw/decode_issue/ImmGen.v"
`include "hw/decode_issue/InstRouter.v"
`include "hw/decode_issue/SSRegfileL1.v"
`include "hw/decode_issue/SSRenameTableL1.v"
`include "hw/util/SSSeqAge.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/SquashNotif.v"

import ISA::*;

module DecodeIssueUnitL6 #(
  parameter p_num_pipes                                = 1,
  parameter p_num_phys_regs                            = 36,
  parameter p_num_be_lanes                             = 2,
  parameter rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{default: p_tinyrv1}
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
  logic   X_xfer;

  logic should_squash;

  always_ff @( posedge clk ) begin
    if ( rst )
      F_reg <= '{ val: 1'b0, inst: 'x, pc: 'x, seq_num: 'x };
    else
      F_reg <= F_reg_next;
  end

  always_comb begin
    F_xfer = F.val & F.rdy;

    if ( F_xfer )
      F_reg_next = '{ val: 1'b1, inst: F.inst, pc: F.pc, seq_num: F.seq_num };
    else if ( X_xfer | should_squash )
      F_reg_next = '{ val: 1'b0, inst: 'x, pc: 'x, seq_num: 'x };
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

  logic [31:0] rdata0, rdata1;

  logic [p_phys_addr_bits-1:0] alloc_preg, alloc_ppreg;
  logic                        alloc_rdy;
  logic [p_phys_addr_bits-1:0] lookup_preg    [2];
  logic                        lookup_pending [2];

  SSRenameTableL1 #(
    .p_num_phys_regs (p_num_phys_regs),
    .p_num_be_lanes  (p_num_be_lanes)
  ) rename_table (
    .clk            (clk),
    .rst            (rst),

    .alloc_areg     (decoder_waddr),
    .alloc_preg     (alloc_preg),
    .alloc_ppreg    (alloc_ppreg),
    .alloc_en       (alloc_rdy & decoder_wen & X_xfer & !should_squash),
    .alloc_rdy      (alloc_rdy),

    .lookup_areg    ({decoder_raddr0, decoder_raddr1}),
    .lookup_preg    (lookup_preg),
    .lookup_pending (lookup_pending),
    .lookup_en      ({1'b1, 1'b1}),

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

  SSRegfileL1 #(
    .p_entry_bits   (32),
    .p_num_regs     (p_num_phys_regs),
    .p_num_be_lanes (p_num_be_lanes)
  ) regfile (
    .clk                (clk),
    .rst                (rst),
    .raddr              (lookup_preg),
    .rdata              ({rdata0, rdata1}),
    .waddr              (complete_preg),
    .wdata              (complete_wdata),
    .wen                (complete_wen_and_val)
  );

  logic stall_pending;
  assign stall_pending = !alloc_rdy | lookup_pending[0] | lookup_pending[1];

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
  always_comb begin
    case( decoder_jal )
      2'd1:    jump_target = F_reg.pc + imm;                // JAL
      2'd2:    jump_target = (rdata0 + imm) & 32'hFFFFFFFE; // JALR
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

  assign squash_pub.val     = (decoder_jal != 0) & F_reg.val & !squash_sent & !stall_pending;
  assign squash_pub.target  = jump_target;
  assign squash_pub.seq_num = F_reg.seq_num;

  //----------------------------------------------------------------------
  // Determine whether we need to squash ourself
  //----------------------------------------------------------------------
  
  SSSeqAge #(
    .p_num_be_lanes (p_num_be_lanes)
  ) seq_age (
    .*
  );

  assign should_squash = squash_sub.val & 
                         seq_age.is_older( squash_sub.seq_num, F_reg.seq_num );

  //----------------------------------------------------------------------
  // Route the instruction (set val/rdy for pipes) based on uop
  //----------------------------------------------------------------------

  InstRouter #(p_num_pipes, p_pipe_subsets) inst_router (
    .uop   (decoder_uop),
    .val   (F_reg.val & !stall_pending & decoder_val & !should_squash),
    .Ex    (Ex),
    .xfer  (X_xfer)
  );

  assign F.rdy = (X_xfer & !stall_pending & decoder_val) | 
                 should_squash                           |
                 (!F_reg.val);

  //----------------------------------------------------------------------
  // Pass remaining signals to pipes
  //----------------------------------------------------------------------
  
  logic [31:0] op1, op2;

  always_comb begin
    op1 = rdata0;
    if( decoder_op2_sel )
      op2 = imm;
    else
      op2 = rdata1;
  end

  genvar k;
  generate
    for( k = 0; k < p_num_pipes; k = k + 1 ) begin: pipe_signals
      assign Ex[k].pc           = F_reg.pc;
      assign Ex[k].op1          = op1;
      assign Ex[k].op2          = op2;
      assign Ex[k].uop          = decoder_uop;
      assign Ex[k].waddr        = decoder_waddr;
      assign Ex[k].seq_num      = F_reg.seq_num;
      assign Ex[k].preg         = alloc_preg;
      assign Ex[k].ppreg        = alloc_ppreg;

      always_comb begin
        if( decoder_op3_sel ) // Branch - need immediate
          Ex[k].op3.branch_imm = imm;
        else // Memory needs register data
          Ex[k].op3.mem_data = rdata1;
      end
    end
  endgenerate

  logic [p_seq_num_bits-1:0] unused_seq_num_bits [p_num_be_lanes];
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

`endif // HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL6_V
