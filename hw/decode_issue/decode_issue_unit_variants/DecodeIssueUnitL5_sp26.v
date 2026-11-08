//========================================================================
// DecodeIssueUnitL5.v 
//========================================================================
// An in-order, single-issue decoder with register renaming

`ifndef HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL5_V
`define HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL5_V

/* verilator lint_off UNOPTFLAT */

`ifndef SYNTHESIS
`include "asm/disassemble.v" 
`endif

`include "defs/ISA.v"
`include "hw/decode_issue/InstDecoder.v"
`include "hw/decode_issue/ImmGen.v"
`include "hw/decode_issue/InstRouter.v"
`include "hw/decode_issue/Regfile.v"
`include "hw/decode_issue/RegfileFPU.v"
`include "hw/decode_issue/RenameTable.v"
`include "hw/util/SeqAge.v"
`include "intf/F__DIntf.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"
`include "intf/SquashNotif.v"

import ISA::*;

module DecodeIssueUnitL5_sp26 #(
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

  CommitNotif.sub commit,

  //----------------------------------------------------------------------
  // Squash Notification (one to request, one to receive)
  //----------------------------------------------------------------------

  SquashNotif.pub squash_pub,
  SquashNotif.sub squash_sub,

  input logic debug_stall
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
      F_reg <= '{ val: 1'b0, inst: '0, pc: '0, seq_num: '0 };
    else
      F_reg <= F_reg_next;
  end

  always_comb begin
    F_xfer = F.val & F.rdy;

    if ( F_xfer )
      F_reg_next = '{ val: 1'b1, inst: F.inst, pc: F.pc, seq_num: F.seq_num };
    else if ( X_xfer | should_squash )
      F_reg_next = '{ val: 1'b0, inst: '0, pc: '0, seq_num: '0 };
    else
      F_reg_next = F_reg;
  end


  //----------------------------------------------------------------------
  // Decoder signals 
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

  //----------------------------------------------------------------------
  // Detect if instruction uses FP registers
  // RISC-V FP instructions have opcode =  (0x53)
  //----------------------------------------------------------------------

  // Identify FP instruction types (including mixed-register FMV)
  logic is_fp_alu, is_flw, is_fsw, is_fmv_x_w, is_fmv_w_x, is_fsgnj;
  logic need_int_rs1, need_int_rs2, need_fp_rs1, need_fp_rs2;
  logic fp_writes_rd;

  assign is_fp_alu   = (decoder_uop == OP_FADD_S) ||
                        (decoder_uop == OP_FSUB_S) ||
                        (decoder_uop == OP_FMUL_S);
  assign is_fsgnj    = (decoder_uop == OP_FSGNJ_S);
  assign is_flw      = (decoder_uop == OP_FLW);
  assign is_fsw      = (decoder_uop == OP_FSW);
  assign is_fmv_x_w  = (decoder_uop == OP_FMV_X_W);  // FP→INT
  assign is_fmv_w_x  = (decoder_uop == OP_FMV_W_X);  // INT→FP
  
  // Which register file supplies each architectural operand
  assign need_fp_rs1  = is_fp_alu || is_fsgnj || is_fmv_x_w ||
                      (decoder_uop == OP_FCVT_W_S);  

  assign need_fp_rs2  = is_fp_alu || is_fsgnj || is_fsw; 

  assign need_int_rs1 = !(need_fp_rs1); 
  assign need_int_rs2 = !(is_fp_alu || is_fsgnj || is_fsw || is_fmv_x_w || is_fmv_w_x);

  // FP destination register for: FP ALU, FSGNJ, FLW, FMV.W.X
  assign fp_writes_rd = is_fp_alu || is_fsgnj || is_flw || is_fmv_w_x;

  //----------------------------------------------------------------------
  // Instantiate Decoder, Regfile, ImmGen
  //----------------------------------------------------------------------
  
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

  //----------------------------------------------------------------------
  // Integer Register File Infra
  //----------------------------------------------------------------------

  logic [31:0] rdata0_int, rdata1_int; 
  logic [p_phys_addr_bits-1:0] alloc_preg_int, alloc_ppreg_int; 
  logic                        alloc_rdy_int; 
  logic [p_phys_addr_bits-1:0] lookup_preg_int    [2];
  logic                        lookup_pending_int [2]; 

  // Integer Rename Table
  RenameTable #(
    .p_num_phys_regs (p_num_phys_regs)
  ) rename_table (
    .clk            (clk),
    .rst            (rst),

    .alloc_areg     (decoder_waddr),
    .alloc_preg     (alloc_preg_int),
    .alloc_ppreg    (alloc_ppreg_int),
    .alloc_en       (alloc_rdy_int & decoder_wen & X_xfer & !should_squash
                    & !fp_writes_rd),
    .alloc_rdy      (alloc_rdy_int),

    .lookup_areg    ({decoder_raddr1, decoder_raddr0}),
    .lookup_preg    (lookup_preg_int),
    .lookup_pending (lookup_pending_int),
    .lookup_en      ({need_int_rs2, need_int_rs1}),

    .complete       (complete),
    .commit         (commit)
  );

  Regfile #(
    .p_entry_bits (32),
    .p_num_regs   (p_num_phys_regs)
  ) regfile (
    .clk                (clk),
    .rst                (rst),
    .raddr              (lookup_preg_int),
    .rdata              ({rdata1_int, rdata0_int}),
    .waddr              (complete.preg),
    .wdata              (complete.wdata),
    // Changed: domain-select via complete.is_fp
    .wen                (complete.wen & complete.val & ~complete.is_fp)
  );

  //----------------------------------------------------------------------
  // Floating-point Register File Infra
  //----------------------------------------------------------------------

  logic [31:0] rdata0_fp, rdata1_fp;
  logic [p_phys_addr_bits-1:0] alloc_preg_fp, alloc_ppreg_fp;
  logic                        alloc_rdy_fp;
  logic [p_phys_addr_bits-1:0] lookup_preg_fp    [2];
  logic                        lookup_pending_fp [2];

  // Floating Rename Table
  RenameTable #( 
    .p_num_phys_regs (p_num_phys_regs),
    .p_is_fp_domain  (1)
  ) rename_table_fp (
    .clk            (clk),
    .rst            (rst),

    .alloc_areg     (decoder_waddr),
    .alloc_preg     (alloc_preg_fp),
    .alloc_ppreg    (alloc_ppreg_fp),
    .alloc_en       (alloc_rdy_fp & decoder_wen & X_xfer & !should_squash & fp_writes_rd),
    .alloc_rdy      (alloc_rdy_fp),

    .lookup_areg    ({decoder_raddr1, decoder_raddr0}),
    .lookup_preg    (lookup_preg_fp),
    .lookup_pending (lookup_pending_fp),
    .lookup_en      ({need_fp_rs2, need_fp_rs1}),

    .complete       (complete),
    .commit         (commit)
  );

  RegfileFPU #(
    .p_entry_bits (32),
    .p_num_regs   (p_num_phys_regs)
  ) regfile_fpu (
    .clk   (clk),
    .rst   (rst),
    .raddr (lookup_preg_fp),
    .rdata ({rdata1_fp, rdata0_fp}),
    .waddr (complete.preg),
    .wdata (complete.wdata),
    // Changed: domain-select via complete.is_fp
    .wen   (complete.wen & complete.val & complete.is_fp)
  );

  //----------------------------------------------------------------------
  // Multiplexer to select between integer and FP register data
  //----------------------------------------------------------------------

  logic [p_phys_addr_bits-1:0] final_alloc_preg, final_alloc_ppreg;
  logic                        final_stall_pending;

  // Mixed-reg selection (FLW/FSW use int rs1 + fp rs2)
  logic [31:0] rs1_val, rs2_val;

  always_comb begin
    // Operand values (rs1 is port0, rs2 is port1)
    rs1_val = need_fp_rs1 ? rdata0_fp : rdata0_int;
    rs2_val = need_fp_rs2 ? rdata1_fp : rdata1_int;

    rdata0 = rs1_val;
    rdata1 = rs2_val;

    // Destination physical register allocation depends on who writes rd
    if ( fp_writes_rd ) begin
      final_alloc_preg  = alloc_preg_fp;
      final_alloc_ppreg = alloc_ppreg_fp;
    end else begin
      final_alloc_preg  = alloc_preg_int;
      final_alloc_ppreg = alloc_ppreg_int;
    end

    // Stall only on the lookups you actually enabled + required allocation
    final_stall_pending =
        (need_int_rs1 & lookup_pending_int[0]) |
        (need_int_rs2 & lookup_pending_int[1]) |
        (need_fp_rs1  & lookup_pending_fp [0]) |
        (need_fp_rs2  & lookup_pending_fp [1]) |
        (decoder_wen  & X_xfer &
         (fp_writes_rd ? !alloc_rdy_fp : !alloc_rdy_int));
  end

  logic stall_pending;
  assign stall_pending = final_stall_pending;

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
  
  SeqAge seq_age (
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

  assign F.rdy = ~debug_stall &
                 ((X_xfer & !stall_pending & decoder_val) | 
                 should_squash                           |
                 (!F_reg.val));

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
      assign Ex[k].preg         = final_alloc_preg;
      assign Ex[k].ppreg        = final_alloc_ppreg;
      assign Ex[k].is_fp        = fp_writes_rd;

      always_comb begin
        if( decoder_op3_sel ) // Branch - need immediate
          Ex[k].op3.branch_imm = imm;
        else // Memory needs register data
          Ex[k].op3.mem_data = rs2_val;
      end
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

`endif // HW_DECODEISSUE_DECODEISSUEUNITVARIANTS_DECODEISSUEUNITL5_V
