//========================================================================
// DecodeIssueUnitL3.v
//========================================================================
// A basic in-order, single-issue decoder with register renaming

`ifndef HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL3_V
`define HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL3_V

`ifndef SYNTHESIS
`include "asm/disassemble.v"
`endif

`include "defs/ISA.v"
`include "hw/decode_issue/InstDecoder.v"
`include "hw/decode_issue/ImmGen.v"
`include "hw/decode_issue/InstRouter.v"
`include "hw/decode_issue/Regfile.v"
`include "hw/decode_issue/RenameTable.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/CommitNotif.v"
`include "intf/CompleteNotif.v"

import ISA::*;

module DecodeIssueUnitL3 #(
  parameter p_num_pipes                                = 1,
  parameter p_num_phys_regs                            = 36,
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

  D__XIntf.D_intf Ex [p_num_pipes-1:0],

  //----------------------------------------------------------------------
  // Completion Notification
  //----------------------------------------------------------------------

  CompleteNotif.sub complete,

  //----------------------------------------------------------------------
  // Commit Notification
  //----------------------------------------------------------------------

  CommitNotif.sub   commit
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
    else if ( X_xfer )
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
  logic       decoder_wen;
  logic [4:0] decoder_waddr;
  rv_imm_type decoder_imm_sel;
  logic       decoder_op2_sel;

  // verilator lint_off UNUSEDSIGNAL
  logic [1:0] decoder_jal;
  logic       decoder_op3_sel;
  // verilator lint_on UNUSEDSIGNAL
  
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

  RenameTable #(
    .p_num_phys_regs (p_num_phys_regs)
  ) rename_table (
    .clk            (clk),
    .rst            (rst),

    .alloc_areg     (decoder_waddr),
    .alloc_preg     (alloc_preg),
    .alloc_ppreg    (alloc_ppreg),
    .alloc_en       (alloc_rdy & decoder_wen & X_xfer),
    .alloc_rdy      (alloc_rdy),

    .lookup_areg    ({decoder_raddr1, decoder_raddr0}),
    .lookup_preg    (lookup_preg),
    .lookup_pending (lookup_pending),
    .lookup_en      ({1'b1, 1'b1}),

    .complete       (complete),
    .commit         (commit)
  );

  Regfile #(
    .p_entry_bits (32),
    .p_num_regs   (p_num_phys_regs)
  ) regfile (
    .clk                (clk),
    .rst                (rst),
    .raddr              (lookup_preg),
    .rdata              ({rdata1, rdata0}),
    .waddr              (complete.preg),
    .wdata              (complete.wdata),
    .wen                (complete.wen & complete.val)
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
  // Route the instruction (set val/rdy for pipes) based on uop
  //----------------------------------------------------------------------

  InstRouter #(p_num_pipes, p_pipe_subsets) inst_router (
    .uop   (decoder_uop),
    .val   (F_reg.val & !stall_pending & decoder_val),
    .Ex    (Ex),
    .xfer  (X_xfer)
  );

  assign F.rdy = (X_xfer & !stall_pending & decoder_val) | (!F_reg.val);

  //----------------------------------------------------------------------
  // Pass remaining signals to pipes
  //----------------------------------------------------------------------
  
  logic [31:0] op1, op2;

  always_comb begin
    op1 = rdata0;
    if ( decoder_op2_sel )
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
      assign Ex[k].op3          = rdata1;
    end
  endgenerate

  logic [p_seq_num_bits-1:0] unused_seq_num_bits;
  assign unused_seq_num_bits = complete.seq_num;

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

`endif // HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL3_V
