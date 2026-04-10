//========================================================================
// SquashUnitL1Chain.v
//========================================================================
// A unit for arbitrating between different squash notifications basec
// on age

`ifndef HW_SQUASH_SQUASHUNITL1CHAIN_V
`define HW_SQUASH_SQUASHUNITL1CHAIN_V

`include "hw/util/SeqAge.v"
`include "intf/CommitNotif.v"
`include "intf/SquashNotif.v"

module SquashUnitL1Chain #(
  parameter p_num_arb = 2
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

  CommitNotif.sub commit
);

  localparam p_seq_num_bits = gnt.p_seq_num_bits;

  //----------------------------------------------------------------------
  // Age logic
  //----------------------------------------------------------------------

  SeqAge #(
    .p_seq_num_bits (p_seq_num_bits)
  ) seq_age (
    .*
  );

  //----------------------------------------------------------------------
  // Chain arbitration
  //----------------------------------------------------------------------

  logic [p_seq_num_bits-1:0] arb_seq_num [p_num_arb] /* verilator split_var */;
  logic               [31:0] arb_target  [p_num_arb] /* verilator split_var */;
  logic                      arb_val     [p_num_arb] /* verilator split_var */;

  assign arb_seq_num[0] = arb[0].seq_num;
  assign arb_target[0]  = arb[0].target;
  assign arb_val[0]     = arb[0].val;

  genvar i;

  // Ignore linter error for using arb_seq_num/arb_val in
  // conditional logic before assignment, even though it's from a
  // previous iteration

  // verilator lint_off ALWCOMBORDER
  generate
    for( i = 1; i < p_num_arb; i = i + 1 ) begin: ARBITRATE
      always_comb begin
        if( arb[i].val & 
            (
              !arb_val[i - 1] | 
              seq_age.is_older( arb[i].seq_num, arb_seq_num[i - 1] )
            ) 
          ) begin
          arb_seq_num[i] = arb[i].seq_num;
          arb_target[i]  = arb[i].target;
          arb_val[i]     = arb[i].val;
        end else begin
          // Carry on from previous arbitration
          arb_seq_num[i] = arb_seq_num[i - 1];
          arb_target[i]  = arb_target[i - 1];
          arb_val[i]     = arb_val[i - 1];
        end
      end
    end
  endgenerate
  // verilator lint_on ALWCOMBORDER

  assign gnt.seq_num = arb_seq_num[p_num_arb - 1];
  assign gnt.target  = arb_target [p_num_arb - 1];
  assign gnt.val     = arb_val    [p_num_arb - 1];

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
`endif

endmodule

`endif // HW_SQUASH_SQUASHUNITL1CHAIN_V
