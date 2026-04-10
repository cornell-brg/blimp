//========================================================================
// SquashUnitL2.v
//========================================================================
// A unit for arbitrating between different squash notifications basec
// on age with support for superscalar backend

`ifndef HW_SQUASH_SQUASHUNITL2_V
`define HW_SQUASH_SQUASHUNITL2_V

`include "hw/util/SSSeqAge.v"
`include "intf/CommitNotif.v"
`include "intf/SquashNotif.v"

//------------------------------------------------------------------------
// SquashUnitL2Helper
//------------------------------------------------------------------------
// A helper module to arbitrate between two squash interfaces

module SquashUnitL2Helper #(
  parameter p_seq_num_bits = 5
)(
  //----------------------------------------------------------------------
  // Notifications to arbitrate between
  //----------------------------------------------------------------------

  input  logic [p_seq_num_bits-1:0] arb0_seq_num,
  input  logic               [31:0] arb0_target,
  input  logic                      arb0_val,
  input  logic [p_seq_num_bits-1:0] arb1_seq_num,
  input  logic               [31:0] arb1_target,
  input  logic                      arb1_val,

  //----------------------------------------------------------------------
  // Arbitrated notification
  //----------------------------------------------------------------------

  output logic [p_seq_num_bits-1:0] gnt_seq_num,
  output logic               [31:0] gnt_target,
  output logic                      gnt_val,

  //----------------------------------------------------------------------
  // Oldest sequence number for age comparison
  //----------------------------------------------------------------------

  input  logic [p_seq_num_bits-1:0] oldest_seq_num
);

  logic arb0_is_older;
  assign arb0_is_older = ( arb0_seq_num < arb1_seq_num    ) ^
                         ( arb0_seq_num < oldest_seq_num ) ^
                         ( arb1_seq_num < oldest_seq_num );

  always_comb begin
    // Choose the valid notification, if only one
    if( !arb0_val ) begin
      gnt_seq_num = arb1_seq_num;
      gnt_target  = arb1_target;
      gnt_val     = arb1_val;
    end else if( !arb1_val ) begin
      gnt_seq_num = arb0_seq_num;
      gnt_target  = arb0_target;
      gnt_val     = arb0_val;
    end

    // Pass along the older squash
    else if( arb0_is_older ) begin
      // 0 is older
      gnt_seq_num = arb0_seq_num;
      gnt_target  = arb0_target;
      gnt_val     = arb0_val;
    end else begin
      // 1 is older
      gnt_seq_num = arb1_seq_num;
      gnt_target  = arb1_target;
      gnt_val     = arb1_val;
    end
  end

endmodule

//------------------------------------------------------------------------
// SquashUnitL2
//------------------------------------------------------------------------

module SquashUnitL2 #(
  parameter p_num_arb       = 2,
  parameter p_num_be_lanes  = 2,
  parameter p_seq_num_bits  = 5,
  parameter p_num_phys_regs = 36
) (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Notifications to arbitrate between
  //----------------------------------------------------------------------

  SquashNotif.sub arb [p_num_arb],

  //----------------------------------------------------------------------
  // Arbitrated notification
  //----------------------------------------------------------------------

  SquashNotif.pub gnt,

  //----------------------------------------------------------------------
  // Commit to track age comparison
  //----------------------------------------------------------------------

  CommitNotif.sub commit [p_num_be_lanes]
);

  //----------------------------------------------------------------------
  // Single SSSeqAge instance for age tracking
  //----------------------------------------------------------------------

  logic [p_seq_num_bits-1:0] oldest_seq_num;

  SSSeqAge #(
    .p_num_be_lanes  (p_num_be_lanes),
    .p_seq_num_bits  (p_seq_num_bits),
    .p_num_phys_regs (p_num_phys_regs)
  ) seq_age (
    .clk            (clk),
    .rst            (rst),
    .oldest_seq_num (oldest_seq_num),
    .commit         (commit)
  );

  // Binary tree
  localparam p_num_levels = $clog2( p_num_arb );
  localparam p_num_intf   = ( 2 ** ( p_num_levels + 1 ) ) - 1;

  generate
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Trivial case
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    if( p_num_arb == 1 ) begin: BASE_CASE
      assign gnt.seq_num = arb[0].seq_num;
      assign gnt.target  = arb[0].target;
      assign gnt.val     = arb[0].val;
    end

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Complicated case
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Use a helper module to arbitrate between two requests, and connect
    // in a binary tree structure

    else begin: TREE
      logic [p_seq_num_bits-1:0] intermediate_seq_num [p_num_intf] /* verilator split_var */;
      logic               [31:0] intermediate_target  [p_num_intf] /* verilator split_var */;
      logic                      intermediate_val     [p_num_intf] /* verilator split_var */;

      genvar i, j;
      for( i = 0; i < 2 ** p_num_levels; i = i + 1 ) begin: INITIAL_ASSIGN
        if( i < p_num_arb ) begin
          assign intermediate_seq_num[i] = arb[i].seq_num;
          assign intermediate_target[i]  = arb[i].target;
          assign intermediate_val[i]     = arb[i].val;
        end else begin
          assign intermediate_seq_num[i] = '0;
          assign intermediate_target[i]  = '0;
          assign intermediate_val[i]     = 1'b0;
        end
      end

      for( i = 0; i < p_num_levels; i = i + 1 ) begin: LEVEL_ARBITRATE
        for( j = 0; j < (2 ** i); j = j + 1 ) begin: NODE_ARBITRATE
          SquashUnitL2Helper #(
            .p_seq_num_bits (p_seq_num_bits)
          ) helper (
            .arb0_seq_num    ( intermediate_seq_num[p_num_intf - (2 * j) - (2 * (2 ** i))    ] ),
            .arb0_target     ( intermediate_target [p_num_intf - (2 * j) - (2 * (2 ** i))    ] ),
            .arb0_val        ( intermediate_val    [p_num_intf - (2 * j) - (2 * (2 ** i))    ] ),
            .arb1_seq_num    ( intermediate_seq_num[p_num_intf - (2 * j) - (2 * (2 ** i)) - 1] ),
            .arb1_target     ( intermediate_target [p_num_intf - (2 * j) - (2 * (2 ** i)) - 1] ),
            .arb1_val        ( intermediate_val    [p_num_intf - (2 * j) - (2 * (2 ** i)) - 1] ),
            .gnt_seq_num     ( intermediate_seq_num[p_num_intf -      j  -      (2 ** i)     ] ),
            .gnt_target      ( intermediate_target [p_num_intf -      j  -      (2 ** i)     ] ),
            .gnt_val         ( intermediate_val    [p_num_intf -      j  -      (2 ** i)     ] ),
            .oldest_seq_num  ( oldest_seq_num )
          );
        end
      end

      assign gnt.seq_num = intermediate_seq_num[p_num_intf - 1];
      assign gnt.target  = intermediate_target [p_num_intf - 1];
      assign gnt.val     = intermediate_val    [p_num_intf - 1];
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
  assign str_len = ceil_div_4(p_seq_num_bits) + 1 + // seq_num
                   ceil_div_4(32);                  // waddr

  function string trace( int trace_level );
    if( trace_level > 0 ) begin
      if( gnt.val )
        trace = $sformatf("%h:%h", gnt.seq_num, gnt.target);
      else
        trace = {str_len{" "}};
    end else begin
      if( gnt.val )
        trace = $sformatf("%h", gnt.seq_num);
      else
        trace = {(ceil_div_4(p_seq_num_bits)){" "}};
    end
  endfunction

  function string trace_json();
    if( gnt.val )
      trace_json = $sformatf("{\"seq\":\"%h\",\"target\":\"%h\",\"xfer\":\"1\"}",
        gnt.seq_num, gnt.target );
    else
      trace_json = "null";
  endfunction
`endif

endmodule

`endif // HW_SQUASH_SQUASHUNITL2_V
