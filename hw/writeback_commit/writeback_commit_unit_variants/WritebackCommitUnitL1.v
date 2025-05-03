//========================================================================
// WritebackCommitUnitL1.v
//========================================================================
// A basic writeback unit that writes back one result at a time, with
// no separate commit

`ifndef HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL1_V
`define HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL1_V

`include "hw/common/RRArb.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"
`include "intf/X__WIntf.v"

module WritebackCommitUnitL1 #(
  parameter p_num_pipes = 1
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

  localparam p_seq_num_bits = complete.p_seq_num_bits;

  //----------------------------------------------------------------------
  // Select which pipe to get from
  //----------------------------------------------------------------------

  logic               [31:0] Ex_pc      [p_num_pipes-1:0];
  logic [p_seq_num_bits-1:0] Ex_seq_num [p_num_pipes-1:0];
  logic                [4:0] Ex_waddr   [p_num_pipes-1:0];
  logic               [31:0] Ex_wdata   [p_num_pipes-1:0];
  logic                      Ex_wen     [p_num_pipes-1:0];
  logic                      Ex_val     [p_num_pipes-1:0];
  logic                      Ex_rdy     [p_num_pipes-1:0];

  genvar i;
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: UNPACK_FROM_INTF
      assign Ex_pc[i]      = Ex[i].pc;
      assign Ex_seq_num[i] = Ex[i].seq_num;
      assign Ex_waddr[i]   = Ex[i].waddr;
      assign Ex_wdata[i]   = Ex[i].wdata;
      assign Ex_wen[i]     = Ex[i].wen;
      assign Ex_val[i]     = Ex[i].val;
      assign Ex[i].rdy     = Ex_rdy[i];
    end
  endgenerate

  logic [p_num_pipes-1:0] Ex_val_packed;
  logic [p_num_pipes-1:0] Ex_gnt_packed;
  logic                   Ex_gnt [p_num_pipes-1:0];

  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: UNPACK
      assign Ex_val_packed[i] = Ex_val[i];
      assign Ex_gnt[i] = Ex_gnt_packed[i];
    end
  endgenerate

  RRArb #(p_num_pipes) ex_arb (
    .clk (clk),
    .rst (rst),
    .en  (1'b1),
    .req (Ex_val_packed),
    .gnt (Ex_gnt_packed)
  );

  logic               [31:0] Ex_pc_masked      [p_num_pipes-1:0];
  logic [p_seq_num_bits-1:0] Ex_seq_num_masked [p_num_pipes-1:0];
  logic                [4:0] Ex_waddr_masked   [p_num_pipes-1:0];
  logic               [31:0] Ex_wdata_masked   [p_num_pipes-1:0];
  logic                      Ex_wen_masked     [p_num_pipes-1:0];
  logic                      Ex_val_masked     [p_num_pipes-1:0];

  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: MASK
      assign Ex_pc_masked[i]      = Ex_pc[i]      & {32{Ex_gnt[i]}};
      assign Ex_seq_num_masked[i] = Ex_seq_num[i] & {p_seq_num_bits{Ex_gnt[i]}};
      assign Ex_waddr_masked[i]   = Ex_waddr[i]   & {5{Ex_gnt[i]}};
      assign Ex_wdata_masked[i]   = Ex_wdata[i]   & {32{Ex_gnt[i]}};
      assign Ex_wen_masked[i]     = Ex_wen[i]     & Ex_gnt[i];
      assign Ex_val_masked[i]     = Ex_val[i]     & Ex_gnt[i];
    end
  endgenerate

  logic               [31:0] Ex_pc_sel;
  logic [p_seq_num_bits-1:0] Ex_seq_num_sel;
  logic                [4:0] Ex_waddr_sel;
  logic               [31:0] Ex_wdata_sel;
  logic                      Ex_wen_sel;
  logic                      Ex_val_sel;

  assign Ex_pc_sel      = Ex_pc_masked.or();
  assign Ex_seq_num_sel = Ex_seq_num_masked.or();
  assign Ex_waddr_sel   = Ex_waddr_masked.or();
  assign Ex_wdata_sel   = Ex_wdata_masked.or();
  assign Ex_wen_sel     = Ex_wen_masked.or();
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
    logic                      val;
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
    logic                [4:0] waddr;
    logic               [31:0] wdata;
    logic                      wen;
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
        wen: 1'b0
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
        wen:     Ex_wen_sel
      };
    else
      X_reg_next = '{ 
        val: 1'b0, 
        pc: 'x,
        seq_num: 'x, 
        waddr: 'x, 
        wdata: 'x, 
        wen: 1'b0
      };
  end

  assign complete.val     = Ex_val_sel;
  assign complete.seq_num = Ex_seq_num_sel;
  assign complete.waddr   = Ex_waddr_sel;
  assign complete.wdata   = Ex_wdata_sel;
  assign complete.wen     = ( Ex_waddr_sel == '0 ) ? 0 : Ex_wen_sel;

  assign commit.val     = X_reg.val;
  assign commit.pc      = X_reg.pc;
  assign commit.seq_num = X_reg.seq_num;
  assign commit.waddr   = X_reg.waddr;
  assign commit.wdata   = X_reg.wdata;
  assign commit.wen     = ( X_reg.waddr == '0 ) ? 0 : X_reg.wen;

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

`endif // HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL1_V
