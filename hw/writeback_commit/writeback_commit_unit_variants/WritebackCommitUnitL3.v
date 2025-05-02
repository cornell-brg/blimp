//========================================================================
// WritebackCommitUnitL2.v
//========================================================================
// A writeback unit that reorders messages based on sequence number
// (including physical register specifiers)

`ifndef HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL3_V
`define HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL3_V

`include "hw/writeback_commit/ROB.v"
`include "hw/util/SeqArb.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"
`include "intf/X__WIntf.v"

module WritebackCommitUnitL3 #(
  parameter p_num_pipes      = 1,
  parameter p_seq_num_bits   = 5,
  parameter p_phys_addr_bits = 6
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // X <-> W Interface
  //----------------------------------------------------------------------

  X__WIntf.W_intf Ex [p_num_pipes-1:0],

  //----------------------------------------------------------------------
  // Completion Interface
  //----------------------------------------------------------------------

  CompleteNotif.pub complete,

  //----------------------------------------------------------------------
  // Commit Interface
  //----------------------------------------------------------------------

  CommitNotif.pub   commit
);

  //----------------------------------------------------------------------
  // Select which pipe to get from
  //----------------------------------------------------------------------

  logic                 [31:0] Ex_pc      [p_num_pipes-1:0];
  logic   [p_seq_num_bits-1:0] Ex_seq_num [p_num_pipes-1:0];
  logic                  [4:0] Ex_waddr   [p_num_pipes-1:0];
  logic                 [31:0] Ex_wdata   [p_num_pipes-1:0];
  logic                        Ex_wen     [p_num_pipes-1:0];
  logic [p_phys_addr_bits-1:0] Ex_preg    [p_num_pipes-1:0];
  logic [p_phys_addr_bits-1:0] Ex_ppreg   [p_num_pipes-1:0];
  logic                        Ex_val     [p_num_pipes-1:0];
  logic                        Ex_rdy     [p_num_pipes-1:0];

  genvar i;
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: UNPACK_FROM_INTF
      assign Ex_pc[i]      = Ex[i].pc;
      assign Ex_seq_num[i] = Ex[i].seq_num;
      assign Ex_waddr[i]   = Ex[i].waddr;
      assign Ex_wdata[i]   = Ex[i].wdata;
      assign Ex_wen[i]     = Ex[i].wen;
      assign Ex_preg[i]    = Ex[i].preg;
      assign Ex_ppreg[i]   = Ex[i].ppreg;
      assign Ex_val[i]     = Ex[i].val;
      assign Ex[i].rdy     = Ex_rdy[i];
    end
  endgenerate

  logic  Ex_gnt [p_num_pipes-1:0];

  CommitNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (commit.p_phys_addr_bits)
  ) arb_commit();

  SeqArb #(
    .p_seq_num_bits (p_seq_num_bits),
    .p_num_arb      (p_num_pipes)
  ) ex_arb (
    .clk     (clk),
    .rst     (rst),
    .seq_num (Ex_seq_num),
    .val     (Ex_val),
    .gnt     (Ex_gnt),
    .commit  (arb_commit)
  );

  logic                 [31:0] Ex_pc_masked      [p_num_pipes-1:0];
  logic   [p_seq_num_bits-1:0] Ex_seq_num_masked [p_num_pipes-1:0];
  logic                  [4:0] Ex_waddr_masked   [p_num_pipes-1:0];
  logic                 [31:0] Ex_wdata_masked   [p_num_pipes-1:0];
  logic                        Ex_wen_masked     [p_num_pipes-1:0];
  logic [p_phys_addr_bits-1:0] Ex_preg_masked    [p_num_pipes-1:0];
  logic [p_phys_addr_bits-1:0] Ex_ppreg_masked   [p_num_pipes-1:0];
  logic                        Ex_val_masked     [p_num_pipes-1:0];

  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: MASK
      assign Ex_pc_masked[i]      = Ex_pc[i]      & {32{Ex_gnt[i]}};
      assign Ex_seq_num_masked[i] = Ex_seq_num[i] & {p_seq_num_bits{Ex_gnt[i]}};
      assign Ex_waddr_masked[i]   = Ex_waddr[i]   & {5{Ex_gnt[i]}};
      assign Ex_wdata_masked[i]   = Ex_wdata[i]   & {32{Ex_gnt[i]}};
      assign Ex_wen_masked[i]     = Ex_wen[i]     & Ex_gnt[i];
      assign Ex_preg_masked[i]    = Ex_preg[i]    & {p_phys_addr_bits{Ex_gnt[i]}};
      assign Ex_ppreg_masked[i]   = Ex_ppreg[i]   & {p_phys_addr_bits{Ex_gnt[i]}};
      assign Ex_val_masked[i]     = Ex_val[i]     & Ex_gnt[i];
    end
  endgenerate

  logic                 [31:0] Ex_pc_sel;
  logic   [p_seq_num_bits-1:0] Ex_seq_num_sel;
  logic                  [4:0] Ex_waddr_sel;
  logic                 [31:0] Ex_wdata_sel;
  logic                        Ex_wen_sel;
  logic [p_phys_addr_bits-1:0] Ex_preg_sel;
  logic [p_phys_addr_bits-1:0] Ex_ppreg_sel;
  logic                        Ex_val_sel;

  assign Ex_pc_sel      = Ex_pc_masked.or();
  assign Ex_seq_num_sel = Ex_seq_num_masked.or();
  assign Ex_waddr_sel   = Ex_waddr_masked.or();
  assign Ex_wdata_sel   = Ex_wdata_masked.or();
  assign Ex_wen_sel     = Ex_wen_masked.or();
  assign Ex_preg_sel    = Ex_preg_masked.or();
  assign Ex_ppreg_sel   = Ex_ppreg_masked.or();
  assign Ex_val_sel     = Ex_val_masked.or();

  // No backpressure - always ready
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: ASSIGN_RDY
      assign Ex_rdy[i] = Ex_gnt[i];
    end
  endgenerate
  
  //----------------------------------------------------------------------
  // Pipeline registers for X interface
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                        val;
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] ppreg;
  } X_input;

  X_input X_reg;
  X_input X_reg_next;

  always_ff @( posedge clk ) begin
    if ( rst )
      X_reg <= '{ 
        val: 1'b0, 
        pc: 'x,
        seq_num: 'x, 
        waddr: 'x, 
        wdata: 'x, 
        wen: 1'b0,
        ppreg: 'x
      };
    else
      X_reg <= X_reg_next;
  end

  always_comb begin
    if ( Ex_val_sel )
      X_reg_next = '{
        val:     1'b1,
        pc:      Ex_pc_sel,
        seq_num: Ex_seq_num_sel,
        waddr:   Ex_waddr_sel,
        wdata:   Ex_wdata_sel,
        wen:     Ex_wen_sel,
        ppreg:   Ex_ppreg_sel
      };
    else
      X_reg_next = '{ 
        val: 1'b0, 
        pc: 'x,
        seq_num: 'x, 
        waddr: 'x, 
        wdata: 'x, 
        wen: 1'b0,
        ppreg: 'x
      };
  end

  assign complete.val     = Ex_val_sel;
  assign complete.seq_num = Ex_seq_num_sel;
  assign complete.waddr   = Ex_waddr_sel;
  assign complete.wdata   = Ex_wdata_sel;
  assign complete.wen     = ( Ex_waddr_sel == '0 ) ? 0 : Ex_wen_sel;
  assign complete.preg    = Ex_preg_sel;

  //----------------------------------------------------------------------
  // ROB
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                 [31:0] pc;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] ppreg;
  } t_rob_msg;

  t_rob_msg rob_input, rob_output;

  assign rob_input.pc      = X_reg.pc;
  assign rob_input.waddr   = X_reg.waddr;
  assign rob_input.wdata   = X_reg.wdata;
  assign rob_input.wen     = ( X_reg.waddr == '0 ) ? 0 : X_reg.wen;
  assign rob_input.ppreg   = X_reg.ppreg;

  localparam p_rob_depth = 2 ** p_seq_num_bits;

  ROB #(
    .p_depth    (p_rob_depth),
    .p_msg_bits ($bits(t_rob_msg))
  ) rob (
    .ins_idx (X_reg.seq_num),
    .ins_msg (rob_input),
    .ins_en  (X_reg.val),

    .deq_idx (commit.seq_num),
    .deq_msg (rob_output),
    .deq_en  (commit.val),
    .deq_rdy (commit.val),
    .*
  );

  assign commit.pc    = rob_output.pc;
  assign commit.waddr = rob_output.waddr;
  assign commit.wdata = rob_output.wdata;
  assign commit.wen   = rob_output.wen;
  assign commit.ppreg = rob_output.ppreg;

  assign arb_commit.pc    = rob_output.pc;
  assign arb_commit.waddr = rob_output.waddr;
  assign arb_commit.wdata = rob_output.wdata;
  assign arb_commit.wen   = rob_output.wen;
  assign arb_commit.ppreg = rob_output.ppreg;

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  int str_len;
  assign str_len = ceil_div_4( p_seq_num_bits ) + 1 + // seq_num
                   1                            + 1 + // wen
                   ceil_div_4( 5 )              + 1 + // addr
                   8;                                 // data
  
  function string trace( int trace_level );
    if( X_reg.val ) begin
      if( trace_level > 0 )
        trace = $sformatf("%h:%h:%h:%h", X_reg.seq_num, X_reg.wen, X_reg.waddr, X_reg.wdata );
      else
        trace = $sformatf("%h", X_reg.seq_num);
    end else begin
      if( trace_level > 0 )
        trace = {str_len{" "}};
      else
        trace = {(ceil_div_4( p_seq_num_bits )){" "}};
    end
  endfunction
`endif

endmodule

`endif // HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL2_V
