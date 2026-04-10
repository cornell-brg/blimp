//========================================================================
// SquashUnitL3.v
//========================================================================
// Age-based squash arbiter with a decoupled grant for the decode-issue
// unit.  Produces two grant outputs:
//
//   gnt       – full arbitration across all sources (for fetch, etc.)
//   gnt_excl  – arbitration excluding the DIU source (for the DIU's
//               own squash_sub, breaking the combinational loop when
//               DIUSquashPub is combinational)
//
// When p_num_arb == 2, gnt_excl is a zero-cost passthrough of the
// single non-DIU source.

`ifndef HW_SQUASH_SQUASHUNITL3_V
`define HW_SQUASH_SQUASHUNITL3_V

`include "hw/util/SSSeqAge.v"
`include "intf/SquashNotif.v"
`include "intf/CommitNotif.v"

//------------------------------------------------------------------------
// SquashUnitL3Helper
//------------------------------------------------------------------------
// Pairwise age-based squash arbiter.  Selects the older of two squash
// notifications, using a circular sequence-number comparison.

module SquashUnitL3Helper #(
  parameter p_seq_num_bits = 5
)(
  input  logic [p_seq_num_bits-1:0] arb0_seq_num,
  input  logic               [31:0] arb0_target,
  input  logic                      arb0_val,
  input  logic [p_seq_num_bits-1:0] arb1_seq_num,
  input  logic               [31:0] arb1_target,
  input  logic                      arb1_val,

  output logic [p_seq_num_bits-1:0] gnt_seq_num,
  output logic               [31:0] gnt_target,
  output logic                      gnt_val,

  input  logic [p_seq_num_bits-1:0] oldest_seq_num
);

  logic arb0_is_older;
  assign arb0_is_older = ( arb0_seq_num < arb1_seq_num   ) ^
                         ( arb0_seq_num < oldest_seq_num ) ^
                         ( arb1_seq_num < oldest_seq_num );

  always_comb begin
    if( !arb0_val ) begin
      gnt_seq_num = arb1_seq_num;
      gnt_target  = arb1_target;
      gnt_val     = arb1_val;
    end else if( !arb1_val ) begin
      gnt_seq_num = arb0_seq_num;
      gnt_target  = arb0_target;
      gnt_val     = arb0_val;
    end else if( arb0_is_older ) begin
      gnt_seq_num = arb0_seq_num;
      gnt_target  = arb0_target;
      gnt_val     = arb0_val;
    end else begin
      gnt_seq_num = arb1_seq_num;
      gnt_target  = arb1_target;
      gnt_val     = arb1_val;
    end
  end

endmodule

//------------------------------------------------------------------------
// SquashUnitL3
//------------------------------------------------------------------------

module SquashUnitL3 #(
  parameter p_num_arb       = 2,
  parameter p_diu_idx       = 0,
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
  // Full arbitrated notification (all sources)
  //----------------------------------------------------------------------

  SquashNotif.pub gnt,

  //----------------------------------------------------------------------
  // Arbitrated notification excluding DIU (for DIU's squash_sub)
  //----------------------------------------------------------------------

  SquashNotif.pub gnt_excl,

  //----------------------------------------------------------------------
  // Commit to track age comparison
  //----------------------------------------------------------------------

  CommitNotif.sub commit [p_num_be_lanes]
);

  //----------------------------------------------------------------------
  // Single SSSeqAge instance for age tracking (shared)
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

  //----------------------------------------------------------------------
  // Full grant: binary-tree arbitration across all sources
  //----------------------------------------------------------------------

  localparam p_full_levels = $clog2( p_num_arb );
  localparam p_full_intf   = ( 2 ** ( p_full_levels + 1 ) ) - 1;

  generate
    if( p_num_arb == 1 ) begin: FULL_BASE
      assign gnt.seq_num = arb[0].seq_num;
      assign gnt.target  = arb[0].target;
      assign gnt.val     = arb[0].val;

    end else begin: FULL_TREE
      logic [p_seq_num_bits-1:0] full_seq_num [p_full_intf] /* verilator split_var */;
      logic               [31:0] full_target  [p_full_intf] /* verilator split_var */;
      logic                      full_val     [p_full_intf] /* verilator split_var */;

      for( genvar i = 0; i < 2 ** p_full_levels; i++ ) begin: FULL_INIT
        if( i < p_num_arb ) begin
          assign full_seq_num[i] = arb[i].seq_num;
          assign full_target[i]  = arb[i].target;
          assign full_val[i]     = arb[i].val;
        end else begin
          assign full_seq_num[i] = '0;
          assign full_target[i]  = '0;
          assign full_val[i]     = 1'b0;
        end
      end

      for( genvar i = 0; i < p_full_levels; i++ ) begin: FULL_LEVEL
        for( genvar j = 0; j < (2 ** i); j++ ) begin: FULL_NODE
          SquashUnitL3Helper #(
            .p_seq_num_bits (p_seq_num_bits)
          ) helper (
            .arb0_seq_num   ( full_seq_num[p_full_intf - (2*j) - (2*(2**i))    ] ),
            .arb0_target    ( full_target [p_full_intf - (2*j) - (2*(2**i))    ] ),
            .arb0_val       ( full_val    [p_full_intf - (2*j) - (2*(2**i))    ] ),
            .arb1_seq_num   ( full_seq_num[p_full_intf - (2*j) - (2*(2**i)) - 1] ),
            .arb1_target    ( full_target [p_full_intf - (2*j) - (2*(2**i)) - 1] ),
            .arb1_val       ( full_val    [p_full_intf - (2*j) - (2*(2**i)) - 1] ),
            .gnt_seq_num    ( full_seq_num[p_full_intf -     j  -    (2**i)     ] ),
            .gnt_target     ( full_target [p_full_intf -     j  -    (2**i)     ] ),
            .gnt_val        ( full_val    [p_full_intf -     j  -    (2**i)     ] ),
            .oldest_seq_num ( oldest_seq_num )
          );
        end
      end

      assign gnt.seq_num = full_seq_num[p_full_intf - 1];
      assign gnt.target  = full_target [p_full_intf - 1];
      assign gnt.val     = full_val    [p_full_intf - 1];
    end
  endgenerate

  //----------------------------------------------------------------------
  // Excluded grant: arbitrate all sources except arb[p_diu_idx]
  //----------------------------------------------------------------------

  localparam p_excl_arb    = p_num_arb - 1;
  localparam p_excl_levels = $clog2( p_excl_arb > 0 ? p_excl_arb : 1 );
  localparam p_excl_intf   = ( 2 ** ( p_excl_levels + 1 ) ) - 1;

  generate
    if( p_num_arb == 2 ) begin: EXCL_PASSTHRU
      // Only one non-DIU source — direct passthrough, zero hardware.
      localparam p_other_idx = (p_diu_idx == 0) ? 1 : 0;

      assign gnt_excl.val     = arb[p_other_idx].val;
      assign gnt_excl.target  = arb[p_other_idx].target;
      assign gnt_excl.seq_num = arb[p_other_idx].seq_num;

    end else begin: EXCL_TREE
      // Pack non-DIU sources into flat arrays.
      logic [p_seq_num_bits-1:0] excl_seq_num [p_excl_intf] /* verilator split_var */;
      logic               [31:0] excl_target  [p_excl_intf] /* verilator split_var */;
      logic                      excl_val     [p_excl_intf] /* verilator split_var */;

      for( genvar i = 0; i < p_num_arb; i++ ) begin: EXCL_CONNECT
        if( i < p_diu_idx ) begin
          assign excl_seq_num[i] = arb[i].seq_num;
          assign excl_target[i]  = arb[i].target;
          assign excl_val[i]     = arb[i].val;
        end else if( i > p_diu_idx ) begin
          assign excl_seq_num[i-1] = arb[i].seq_num;
          assign excl_target[i-1]  = arb[i].target;
          assign excl_val[i-1]     = arb[i].val;
        end
      end

      // Zero-fill unused leaf slots.
      for( genvar i = p_excl_arb; i < 2 ** p_excl_levels; i++ ) begin: EXCL_ZERO
        assign excl_seq_num[i] = '0;
        assign excl_target[i]  = '0;
        assign excl_val[i]     = 1'b0;
      end

      // Binary-tree arbitration.
      for( genvar i = 0; i < p_excl_levels; i++ ) begin: EXCL_LEVEL
        for( genvar j = 0; j < (2 ** i); j++ ) begin: EXCL_NODE
          SquashUnitL3Helper #(
            .p_seq_num_bits (p_seq_num_bits)
          ) helper (
            .arb0_seq_num   ( excl_seq_num[p_excl_intf - (2*j) - (2*(2**i))    ] ),
            .arb0_target    ( excl_target [p_excl_intf - (2*j) - (2*(2**i))    ] ),
            .arb0_val       ( excl_val    [p_excl_intf - (2*j) - (2*(2**i))    ] ),
            .arb1_seq_num   ( excl_seq_num[p_excl_intf - (2*j) - (2*(2**i)) - 1] ),
            .arb1_target    ( excl_target [p_excl_intf - (2*j) - (2*(2**i)) - 1] ),
            .arb1_val       ( excl_val    [p_excl_intf - (2*j) - (2*(2**i)) - 1] ),
            .gnt_seq_num    ( excl_seq_num[p_excl_intf -     j  -    (2**i)     ] ),
            .gnt_target     ( excl_target [p_excl_intf -     j  -    (2**i)     ] ),
            .gnt_val        ( excl_val    [p_excl_intf -     j  -    (2**i)     ] ),
            .oldest_seq_num ( oldest_seq_num )
          );
        end
      end

      assign gnt_excl.seq_num = excl_seq_num[p_excl_intf - 1];
      assign gnt_excl.target  = excl_target [p_excl_intf - 1];
      assign gnt_excl.val     = excl_val    [p_excl_intf - 1];
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
  assign str_len = ceil_div_4(p_seq_num_bits) + 1 +
                   ceil_div_4(32);

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

`endif // HW_SQUASH_SQUASHUNITL3_V
