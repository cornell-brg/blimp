//========================================================================
// SeqArb.v
//========================================================================
// A module for monitoring sequence numbers and selecting the oldest one
//
// gnt is a one-hot vector to select the oldest one

`ifndef HW_UTIL_SEQARB_V
`define HW_UTIL_SEQARB_V

`include "intf/CommitNotif.v"
`include "hw/util/SeqAge.v"

//------------------------------------------------------------------------
// SeqArbHelper
//------------------------------------------------------------------------
// A helper module to arbitrate between two sequence numbers

module SeqArbHelper #(
  parameter p_seq_num_bits = 5
)(
  input  logic    clk,
  input  logic    rst,

  //----------------------------------------------------------------------
  // Numbers to arbitrate between
  //----------------------------------------------------------------------

  input  logic [p_seq_num_bits-1:0] arb0_seq_num,
  input  logic                      arb0_val,
  input  logic [p_seq_num_bits-1:0] arb1_seq_num,
  input  logic                      arb1_val,

  //----------------------------------------------------------------------
  // Arbitrated notification
  //----------------------------------------------------------------------

  output logic [p_seq_num_bits-1:0] gnt_seq_num,
  output logic                      gnt_val,

  //----------------------------------------------------------------------
  // Commit to track age comparison
  //----------------------------------------------------------------------

  CommitNotif.sub commit
);

  SeqAge #(
    .p_seq_num_bits (p_seq_num_bits)
  ) seq_age (
    .*
  );

  logic arb0_is_older;
  assign arb0_is_older = seq_age.is_older(
    arb0_seq_num,
    arb1_seq_num
  );

  always_comb begin
    // Choose the valid notification, if only one
    if( !arb0_val ) begin
      gnt_seq_num = arb1_seq_num;
      gnt_val     = arb1_val;
    end else if( !arb1_val ) begin
      gnt_seq_num = arb0_seq_num;
      gnt_val     = arb0_val;
    end

    // Pass along the older squash
    else if( arb0_is_older ) begin
      // 0 is older
      gnt_seq_num = arb0_seq_num;
      gnt_val     = arb0_val;
    end else begin
      // 1 is older
      gnt_seq_num = arb1_seq_num;
      gnt_val     = arb1_val;
    end
  end
endmodule

//------------------------------------------------------------------------
// SeqArb
//------------------------------------------------------------------------

module SeqArb #(
  parameter p_seq_num_bits = 5,
  parameter p_num_arb      = 2
)(
  input  logic clk,
  input  logic rst,

  input  logic [p_seq_num_bits-1:0] seq_num [p_num_arb],
  input  logic                      val     [p_num_arb],
  output logic                      gnt     [p_num_arb],

  //----------------------------------------------------------------------
  // Commit Interface
  //----------------------------------------------------------------------

  CommitNotif.sub commit
);

  // Binary tree
  localparam p_num_levels = $clog2( p_num_arb );
  localparam p_num_intf   = ( 2 ** ( p_num_levels + 1 ) ) - 1;
  logic [p_seq_num_bits-1:0] gnt_seq_num;

  generate
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Trivial case
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    if( p_num_arb == 1 ) begin: BASE_CASE
      assign gnt[0] = val[0];
      assign gnt_seq_num = seq_num[0]; // For tracing
    end

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Complicated case
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Use a helper module to arbitrate between two requests, and connect
    // in a binary tree structure

    else begin: TREE
      logic [p_seq_num_bits-1:0] intermediate_seq_num [p_num_intf] /* verilator split_var */;
      logic                      intermediate_val     [p_num_intf] /* verilator split_var */;

      genvar i, j;
      for( i = 0; i < 2 ** p_num_levels; i = i + 1 ) begin: INITIAL_ASSIGN
        if( i < p_num_arb ) begin
          assign intermediate_seq_num[i] = seq_num[i];
          assign intermediate_val[i]     = val[i];
        end else begin
          assign intermediate_seq_num[i] = 'x;
          assign intermediate_val[i]     = 1'b0;
        end
      end

      for( i = 0; i < p_num_levels; i = i + 1 ) begin: LEVEL_ARBITRATE
        for( j = 0; j < (2 ** i); j = j + 1 ) begin: NODE_ARBITRATE
          SeqArbHelper #(
            .p_seq_num_bits (p_seq_num_bits)
          ) helper (
            .arb0_seq_num ( intermediate_seq_num[p_num_intf - (2 * j) - (2 * (2 ** i))    ] ),
            .arb0_val     ( intermediate_val    [p_num_intf - (2 * j) - (2 * (2 ** i))    ] ),
            .arb1_seq_num ( intermediate_seq_num[p_num_intf - (2 * j) - (2 * (2 ** i)) - 1] ),
            .arb1_val     ( intermediate_val    [p_num_intf - (2 * j) - (2 * (2 ** i)) - 1] ),
            .gnt_seq_num  ( intermediate_seq_num[p_num_intf -      j  -      (2 ** i)     ] ),
            .gnt_val      ( intermediate_val    [p_num_intf -      j  -      (2 ** i)     ] ),
            .*
          );
        end
      end

      assign gnt_seq_num = intermediate_seq_num[p_num_intf - 1];

      for( i = 0; i < p_num_arb; i = i + 1 ) begin: ASSIGN_GNT
        assign gnt[i] = ( seq_num[i] == gnt_seq_num ) & val[i];
      end
    end
  endgenerate

  //----------------------------------------------------------------------
  // Unused signals
  //----------------------------------------------------------------------
  // Include those that are used by SeqAge, as they're not used in all
  // cases

  logic        unused_clk;
  logic        unused_rst;
  logic [31:0] unused_commit_pc;
  logic  [4:0] unused_commit_waddr;
  logic [31:0] unused_commit_wdata;
  logic        unused_commit_wen;
  logic        unused_commit_val;

  assign unused_clk          = clk;
  assign unused_rst          = rst;
  assign unused_commit_pc    = commit.pc;
  assign unused_commit_waddr = commit.waddr;
  assign unused_commit_wdata = commit.wdata;
  assign unused_commit_wen   = commit.wen;
  assign unused_commit_val   = commit.val;

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
    if( val.or() )
      trace = $sformatf("%h", gnt_seq_num);
    else
      trace = {(ceil_div_4(p_seq_num_bits)){" "}};
  endfunction
`endif

endmodule

`endif // HW_UTIL_SEQARB_V
