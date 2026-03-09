//========================================================================
// WritebackCommitUnitL4.v
//========================================================================
// A writeback unit that reorders messages based on sequence number
// (including physical register specifiers) and allows for multiple
// independent instructions to commit simultaneously

`ifndef HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL4_V
`define HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL4_V

`include "hw/writeback_commit/MROB.v"
`include "hw/writeback_commit/WritebackCommitUnitBypassFifo.v"
`include "hw/common/MRRArb.v"
`include "hw/writeback_commit/SSWBArb.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"
`include "intf/X__WIntf.v"

module WritebackCommitUnitL4 #(
  parameter p_num_pipes          = 1,
  parameter p_num_be_lanes       = 2,
  parameter p_x_intf_fifo_depth  = 4,
  parameter p_x_intf_fifo_bypass = 0,
  parameter p_use_age_arb        = 1
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

  CommitNotif.pub commit [p_num_be_lanes]
);

  localparam p_seq_num_bits   = complete.p_seq_num_bits;
  localparam p_phys_addr_bits = complete.p_phys_addr_bits;
  localparam p_rob_depth      = 2 ** p_seq_num_bits;

  //----------------------------------------------------------------------
  // Writeback message struct (used throughout the pipeline)
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                        val;
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
  } t_wb_msg;

  //----------------------------------------------------------------------
  // Unpack interface signals
  //----------------------------------------------------------------------

  t_wb_msg Ex_msg [p_num_pipes];
  logic    Ex_rdy [p_num_pipes];

  genvar i;
  generate
    for( i = 0; i < p_num_pipes; i = i + 1 ) begin: UNPACK_FROM_INTF
      assign Ex_msg[i].val     = Ex[i].val;
      assign Ex_msg[i].pc      = Ex[i].pc;
      assign Ex_msg[i].seq_num = Ex[i].seq_num;
      assign Ex_msg[i].waddr   = Ex[i].waddr;
      assign Ex_msg[i].wdata   = Ex[i].wdata;
      assign Ex_msg[i].wen     = Ex[i].wen;
      assign Ex_msg[i].preg    = Ex[i].preg;
      assign Ex_msg[i].ppreg   = Ex[i].ppreg;
      assign Ex[i].rdy         = Ex_rdy[i];
    end
  endgenerate

  //----------------------------------------------------------------------
  // Arbiter budget
  //----------------------------------------------------------------------

  logic fifo_full;

  logic [p_seq_num_bits:0]         avail_slots_mrob;
  logic [$clog2(p_num_be_lanes):0] avail_slots_arb;

  assign avail_slots_arb = fifo_full ? '0 :
                           ($clog2(p_num_be_lanes)+1)'(avail_slots_mrob > p_num_be_lanes ?
                                                  p_num_be_lanes :
                                                  avail_slots_mrob);

  //----------------------------------------------------------------------
  // Arbitration and selection
  //----------------------------------------------------------------------
  // SSWBArb (age-based) handles arbitration + selection muxing internally.
  // MRRArb (round-robin) only provides grant; muxing is done here.

  t_wb_msg Ex_msg_sel [p_num_be_lanes];

  generate
    if (p_use_age_arb) begin : gen_age_arb

      SSWBArb #(
        .t_msg          (t_wb_msg),
        .p_num_pipes    (p_num_pipes),
        .p_num_be_lanes (p_num_be_lanes),
        .p_seq_num_bits (p_seq_num_bits)
      ) ex_arb (
        .clk     (clk),
        .rst     (rst),
        .en      (1'b1),
        .m       (avail_slots_arb),
        .in_msg  (Ex_msg),
        .rdy     (Ex_rdy),
        .sel_msg (Ex_msg_sel),
        .commit  (commit)
      );

    end else begin : gen_rr_arb

      logic [p_num_pipes-1:0] Ex_val_packed;
      logic [p_num_pipes-1:0] Ex_gnt_packed;

      for( i = 0; i < p_num_pipes; i = i + 1 ) begin: GEN_PACK
        assign Ex_val_packed[i] = Ex_msg[i].val;
      end

      MRRArb #(
        .p_width (p_num_pipes),
        .p_max_m (p_num_be_lanes)
      ) ex_arb (
        .clk     (clk),
        .rst     (rst),
        .en      (1'b1),
        .m       (avail_slots_arb),
        .req     (Ex_val_packed),
        .gnt     (Ex_gnt_packed)
      );

      // Selection muxing: granted pipes -> sequential output lanes
      int j_rr, k_rr;

      always_comb begin
        for (j_rr = 0; j_rr < p_num_be_lanes; j_rr++)
          Ex_msg_sel[j_rr] = '0;

        k_rr = 0;
        for (j_rr = 0; j_rr < p_num_pipes; j_rr++) begin
          if (Ex_gnt_packed[j_rr] && (k_rr < p_num_be_lanes)) begin
            Ex_msg_sel[k_rr] = Ex_msg[j_rr];
            k_rr++;
          end
        end
      end

      // Ready = granted
      for( i = 0; i < p_num_pipes; i = i + 1 ) begin: GEN_RDY
        assign Ex_rdy[i] = Ex_gnt_packed[i];
      end

    end
  endgenerate;

  //----------------------------------------------------------------------
  // Complete notifications (driven from pre-FIFO arbiter output)
  //----------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin: COMPLETE_GEN
      assign complete[i].val     = Ex_msg_sel[i].val;
      assign complete[i].seq_num = Ex_msg_sel[i].seq_num;
      assign complete[i].waddr   = Ex_msg_sel[i].waddr;
      assign complete[i].wdata   = Ex_msg_sel[i].wdata;
      assign complete[i].wen     = ( Ex_msg_sel[i].waddr == '0 ) ? 0 : 
                                     Ex_msg_sel[i].wen;
      assign complete[i].preg    = Ex_msg_sel[i].preg;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Bypass FIFO for X interface
  //----------------------------------------------------------------------

  t_wb_msg                   fifo_in          [p_num_be_lanes];
  logic [p_num_be_lanes-1:0] Ex_val_sel_packed;

  generate
    for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin: FIFO_IN_GEN
      assign Ex_val_sel_packed[i] = Ex_msg_sel[i].val;
      assign fifo_in[i]          = Ex_msg_sel[i];
    end
  endgenerate

  logic fifo_push, fifo_pop, fifo_empty;
  assign fifo_push = |Ex_val_sel_packed & !fifo_full;
  assign fifo_pop  = !fifo_empty;

  t_wb_msg X_curr [p_num_be_lanes];

  WritebackCommitUnitBypassFifo #(
    .t_msg       (t_wb_msg),
    .p_depth     (p_x_intf_fifo_depth),
    .p_bypass    (p_x_intf_fifo_bypass),
    .p_num_lanes (p_num_be_lanes)
  ) x_fifo (
    .clk   (clk),
    .rst   (rst),
    .push  (fifo_push),
    .i_msg (fifo_in),
    .full  (fifo_full),
    .pop   (fifo_pop),
    .empty (fifo_empty),
    .o_msg (X_curr)
  );

  //----------------------------------------------------------------------
  // ROB
  //----------------------------------------------------------------------

  t_wb_msg rob_input [p_num_be_lanes], rob_output [p_num_be_lanes];

  logic [p_seq_num_bits-1:0]  X_curr_seq_num [p_num_be_lanes];
  logic                       X_curr_val     [p_num_be_lanes];
  logic [p_num_be_lanes-1:0]  X_curr_val_packed;

  always_comb begin
    for (int j = 0; j < p_num_be_lanes; j++) begin
      rob_input[j]          = X_curr[j];
      rob_input[j].wen      = ( X_curr[j].waddr == '0 ) ? 1'b0 : X_curr[j].wen;
      X_curr_seq_num[j]     = X_curr[j].seq_num;
      X_curr_val[j]         = X_curr[j].val & !fifo_empty;
      X_curr_val_packed[j]  = X_curr[j].val & !fifo_empty;
    end
  end

  logic                      deq_rdy;
  logic                      deq_msg_val        [p_num_be_lanes];
  logic [p_seq_num_bits-1:0] rob_output_seq_num [p_num_be_lanes];

  MROB #(
    .p_depth     (p_rob_depth),
    .p_num_lanes (p_num_be_lanes),
    .p_msg_bits  ($bits(t_wb_msg))
  ) rob (
    .ins_idx     (X_curr_seq_num),
    .ins_msg     (rob_input),
    .ins_msg_val (X_curr_val),
    .ins_en      (|X_curr_val_packed),
    .ins_rdy     (),
    .avail_slots (avail_slots_mrob),

    .deq_idx     (rob_output_seq_num),
    .deq_msg     (rob_output),
    .deq_msg_val (deq_msg_val),
    .deq_en      (deq_rdy),
    .deq_rdy     (deq_rdy),
    .*
  );

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin: GEN_COMMIT_OUTPUT
      assign commit[i].pc      = rob_output[i].pc;
      assign commit[i].waddr   = rob_output[i].waddr;
      assign commit[i].wdata   = rob_output[i].wdata;
      assign commit[i].wen     = rob_output[i].wen;
      assign commit[i].ppreg   = rob_output[i].ppreg;
      assign commit[i].val     = deq_msg_val[i] & deq_rdy;
      assign commit[i].seq_num = rob_output_seq_num[i];
    end
  endgenerate

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
    trace = "";
    for( int i = 0; i < p_num_be_lanes; i++ ) begin
      if( i != 0 )
        trace = {trace, "  "};

      if( X_curr[i].val ) begin
        if( trace_level > 0 )
          trace = {trace, $sformatf("%h:%h:%h:%h", X_curr[i].seq_num, X_curr[i].wen, X_curr[i].waddr, X_curr[i].wdata )};
        else
          trace = {trace, $sformatf("%h", X_curr[i].seq_num)};
      end else begin
        if( trace_level > 0 )
          trace = {trace, {str_len{" "}}};
        else
          trace = {trace, {(ceil_div_4( p_seq_num_bits )){" "}}};
      end
    end
  endfunction
`endif

endmodule

`endif // HW_WRITEBACK_WRITEBACKCOMMITUNITVARIANTS_WRITEBACKCOMMITUNITL4_V
