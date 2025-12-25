//========================================================================
// WritebackCommitUnitL4.v
//========================================================================
// A writeback unit that reorders messages based on sequence number
// (including physical register specifiers) and allows for multiple
// independent instructions to commit simultaneously

`ifndef HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL4_V
`define HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL4_V

`include "hw/writeback_commit/MROB.v"
`include "hw/common/MRRArb.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"
`include "intf/X__WIntf.v"

module WritebackCommitUnitL4 #(
  parameter p_num_pipes = 1,
  parameter p_num_be_lanes = 2
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // X <-> W Interface
  //----------------------------------------------------------------------

  X__WIntf.W_intf Ex [p_num_pipes],

  //----------------------------------------------------------------------
  // Completion Interfaces
  //----------------------------------------------------------------------

  CompleteNotif.pub complete [p_num_be_lanes],

  //----------------------------------------------------------------------
  // Commit Interface
  //----------------------------------------------------------------------

  CommitNotif.pub   commit [p_num_be_lanes]
);

  localparam p_seq_num_bits   = complete.p_seq_num_bits;
  localparam p_phys_addr_bits = complete.p_phys_addr_bits;

  //----------------------------------------------------------------------
  // Select which pipe to get from
  //----------------------------------------------------------------------

  logic                 [31:0] Ex_pc      [p_num_pipes];
  logic   [p_seq_num_bits-1:0] Ex_seq_num [p_num_pipes];
  logic                  [4:0] Ex_waddr   [p_num_pipes];
  logic                 [31:0] Ex_wdata   [p_num_pipes];
  logic                        Ex_wen     [p_num_pipes];
  logic [p_phys_addr_bits-1:0] Ex_preg    [p_num_pipes];
  logic [p_phys_addr_bits-1:0] Ex_ppreg   [p_num_pipes];
  logic                        Ex_val     [p_num_pipes];
  logic                        Ex_rdy     [p_num_pipes];

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

  logic [p_num_pipes-1:0] Ex_val_packed;
  logic [p_num_pipes-1:0] Ex_gnt_packed;
  logic                   Ex_gnt         [p_num_pipes];

  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: UNPACK
      assign Ex_val_packed[i] = Ex_val[i];
      assign Ex_gnt[i] = Ex_gnt_packed[i];
    end
  endgenerate

  MRRArb #(
    .p_width (p_num_pipes),
    .p_max_m (p_num_be_lanes),
  ) ex_arb (
    .clk     (clk),
    .rst     (rst),
    .en      (1'b1),
    .m       (), // TODO
    .req     (Ex_val_packed),
    .gnt     (Ex_gnt_packed)
  );

  logic                 [31:0] Ex_pc_sel      [p_num_be_lanes];
  logic   [p_seq_num_bits-1:0] Ex_seq_num_sel [p_num_be_lanes];
  logic                  [4:0] Ex_waddr_sel   [p_num_be_lanes];
  logic                 [31:0] Ex_wdata_sel   [p_num_be_lanes];
  logic                        Ex_wen_sel     [p_num_be_lanes];
  logic [p_phys_addr_bits-1:0] Ex_preg_sel    [p_num_be_lanes];
  logic [p_phys_addr_bits-1:0] Ex_ppreg_sel   [p_num_be_lanes];
  logic                        Ex_val_sel     [p_num_be_lanes];
  int j, k;

  always_comb begin
    for ( j = 0; j < p_max_m; j++) begin
      Ex_pc_sel[j]      = '0;
      Ex_seq_num_sel[j] = '0;
      Ex_waddr_sel[j]   = '0;
      Ex_wdata_sel[j]   = '0;
      Ex_wen_sel[j]     = '0;
      Ex_preg_sel[j]    = '0;
      Ex_ppreg_sel[j]   = '0;
      Ex_val_sel[j]     = '0;
    end

    k = 0;
    for( j = 0; j < p_num_pipes; j++ ) begin
      if( Ex_gnt[j] && (k < p_num_be_lanes) ) begin
        Ex_pc_sel[k]      = Ex_pc[j];
        Ex_seq_num_sel[k] = Ex_seq_num[j];
        Ex_waddr_sel[k]   = Ex_waddr[j];
        Ex_wdata_sel[k]   = Ex_wdata[j];
        Ex_wen_sel[k]     = Ex_wen[j];
        Ex_preg_sel[k]    = Ex_preg[j];
        Ex_ppreg_sel[k]   = Ex_ppreg[j];
        Ex_val_sel[k]     = Ex_val[j];
        k++;
      end
    end
  end

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

  X_input X_reg      [p_num_be_lanes];
  X_input X_reg_next [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin: X_REG_GEN
      always_ff @( posedge clk ) begin
        if ( rst )
          X_reg[i] <= '{ 
            val: 1'b0, 
            pc: 'x,
            seq_num: 'x, 
            waddr: 'x, 
            wdata: 'x, 
            wen: 1'b0,
            ppreg: 'x
          };
        else
          X_reg[i] <= X_reg_next[i];
      end

      always_comb begin
        if ( Ex_val_sel[i] )
          X_reg_next[i] = '{
            val:     1'b1,
            pc:      Ex_pc_sel[i],
            seq_num: Ex_seq_num_sel[i],
            waddr:   Ex_waddr_sel[i],
            wdata:   Ex_wdata_sel[i],
            wen:     Ex_wen_sel[i],
            ppreg:   Ex_ppreg_sel[i]
          };
        else
          X_reg_next[i] = '{ 
            val: 1'b0, 
            pc: 'x,
            seq_num: 'x, 
            waddr: 'x, 
            wdata: 'x, 
            wen: 1'b0,
            ppreg: 'x
          };
      end
    end

    assign complete[i].val     = Ex_val_sel[i];
    assign complete[i].seq_num = Ex_seq_num_sel[i];
    assign complete[i].waddr   = Ex_waddr_sel[i];
    assign complete[i].wdata   = Ex_wdata_sel[i];
    assign complete[i].wen     = ( Ex_waddr_sel[i] == '0 ) ? 0 : Ex_wen_sel[i];
    assign complete[i].preg    = Ex_preg_sel[i];
  endgenerate

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

  // TODO
  MROB #(
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

  // TODO
  assign commit.pc    = rob_output.pc;
  assign commit.waddr = rob_output.waddr;
  assign commit.wdata = rob_output.wdata;
  assign commit.wen   = rob_output.wen;
  assign commit.ppreg = rob_output.ppreg;

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
  
  function string trace( int trace_level ); // TODO
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

`endif // HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL4_V
