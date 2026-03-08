//========================================================================
// SeqNumGenL5.v
//========================================================================
// A module for generating and managing sequence numbers with squashing and
// support for superscalar backend. p_num_fe_lanes sequence numbers will be
// allocated at once

`ifndef HW_FETCH_SEQNUMGENL5_V
`define HW_FETCH_SEQNUMGENL5_V

`include "hw/util/SSSeqAge.v"
`include "intf/CommitNotif.v"
`include "intf/SquashNotif.v"

module SeqNumGenL5 #(
  parameter p_seq_num_bits  = 5,
  parameter p_reclaim_width = 2, // Number of entries that can be reclaimed at once
  parameter p_num_fe_lanes  = 2,
  parameter p_num_be_lanes  = 2
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Allocation Interface
  //----------------------------------------------------------------------

  // allocate seq num for each ready lane, alloc_val is set for lanes that are
  // ready and successfully allocated
  output logic [p_seq_num_bits-1:0] alloc_seq_num [p_num_fe_lanes],
  output logic                      alloc_val     [p_num_fe_lanes],
  input  logic                      alloc_rdy     [p_num_fe_lanes],

  //----------------------------------------------------------------------
  // Commit Interface to free sequence numbers
  //----------------------------------------------------------------------

  CommitNotif.sub commit [p_num_be_lanes],

  //----------------------------------------------------------------------
  // Squash Interface
  //----------------------------------------------------------------------

  SquashNotif.sub squash
);

  localparam p_num_entries = 2 ** p_seq_num_bits;
  localparam p_num_fe_lanes_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1;

  logic [p_seq_num_bits-1:0] commit_seq_num [p_num_be_lanes];
  genvar i;
  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin: COMMIT_SEQ_NUM_ASSIGN
      assign commit_seq_num[i] = commit[i].seq_num;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Age Logic
  //----------------------------------------------------------------------
  // Need to keep track to know which to free on a squash

  SSSeqAge #(
    .p_num_be_lanes (p_num_be_lanes)
  ) seq_age (
    .*
  );
  
  //----------------------------------------------------------------------
  // Sequence Number List
  //----------------------------------------------------------------------
  // Keep track of which ones are allocated

  localparam ALLOC = 1'b1;
  localparam FREE  = 1'b0;

  logic seq_num_list [p_num_entries];
  logic [p_seq_num_bits:0] curr_head_ptr, curr_tail_ptr;
  logic is_alloc [p_num_fe_lanes];
  logic [p_num_be_lanes-1:0] is_free;

  generate
    for( i = 0; i < p_num_entries; i++ ) begin: SEQ_NUM
      always_ff @( posedge clk ) begin
        if( rst ) seq_num_list[i] <= 1'b0;
        else begin

          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
          // Allocation
          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

          for( int j = 0; j < p_num_fe_lanes; j++ ) begin
            if( alloc_val[j] & ( alloc_seq_num[j] == i ) )
              seq_num_list[i] <= ALLOC;
          end

          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
          // Freeing
          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

          for( int j = 0; j < p_num_be_lanes; j++ ) begin
            if( is_free[j] & ( commit_seq_num[j] == i ) )
              seq_num_list[i] <= FREE;
          end

          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
          // Squashing - free all inst seq nums younger than squash inst's
          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

          if( squash.val & seq_age.is_older( squash.seq_num, p_seq_num_bits'(i) ) )
            // The corresponding instruction is squashed
            seq_num_list[i] <= FREE;
        end
      end
    end
  endgenerate

  // With (p_seq_num_bits+1)-bit pointers, entries_allocated is simply the difference
  logic [p_seq_num_bits:0] entries_allocated;
  assign entries_allocated = curr_head_ptr - curr_tail_ptr;

  //----------------------------------------------------------------------
  // Allocation
  //----------------------------------------------------------------------

  // Track how many entries we need to allocate in this cycle
  logic [p_num_fe_lanes_bits:0] alloc_rdy_cntr;

  // Count how many lanes are requesting allocation (separate block to break
  // combinational loop with can_alloc)
  always_comb begin
    alloc_rdy_cntr = '0;
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      if( alloc_rdy[j] )
        alloc_rdy_cntr = alloc_rdy_cntr + 1;
    end
  end

  // Check that alloc_rdy_cntr consecutive entries from head are free
  logic alloc_entries_free;
  always_comb begin
    alloc_entries_free = 1'b1;
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      if( k < alloc_rdy_cntr && seq_num_list[p_seq_num_bits'(curr_head_ptr[p_seq_num_bits-1:0] + k)] != FREE )
        alloc_entries_free = 1'b0;
    end
  end

  // Can only allocate if there's enough space for all entries we need to
  // allocate and all those entries are free
  // With (p_seq_num_bits+1)-bit pointers, we can use all p_num_entries
  logic can_alloc;
  logic [p_seq_num_bits:0] space_needed;
  logic [p_seq_num_bits:0] space_available;

  always_comb begin
    space_needed = entries_allocated + p_seq_num_bits'(alloc_rdy_cntr);
    space_available = p_num_entries;  // Can use all entries now
    can_alloc = (space_needed <= space_available) & alloc_entries_free;
  end

  // Allocate consecutive sequence numbers starting from head pointer for each
  // ready lane
  logic [p_num_fe_lanes_bits:0] alloc_lane_cntr;
  always_comb begin
    alloc_lane_cntr = '0;
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin: ALLOC_SEQ_NUM_ASSIGN
      alloc_seq_num[j] = '0;
      if( alloc_rdy[j] ) begin
        alloc_seq_num[j] = ( squash.val ) ? squash.seq_num + p_seq_num_bits'(1 + alloc_lane_cntr)
                                          : p_seq_num_bits'(curr_head_ptr[p_seq_num_bits-1:0] + alloc_lane_cntr);
        alloc_lane_cntr = alloc_lane_cntr + 1;
      end

      // Valid allocation for this lane if we can allocate and this lane is
      // requesting allocation
      alloc_val[j] = can_alloc & alloc_rdy[j];
    end
  end

  logic [p_seq_num_bits:0] curr_head_ptr_next;

  always_ff @( posedge clk ) begin
    if( rst ) begin
      curr_head_ptr <= '0;
    end else begin
      curr_head_ptr <= curr_head_ptr_next;
    end
  end

  always_comb begin
    curr_head_ptr_next = curr_head_ptr;

    // On a squash, head pointer goes to inst after squashed inst
    // Extend squash.seq_num to (p_seq_num_bits+1) bits to match pointer width
    if( squash.val ) curr_head_ptr_next = squash.seq_num + 1;

    // If allocating (possibly also during a squash), head pointer moves forward
    // by number of entries allocated (starting from new squash head pointer if
    // squash happens)
    if( can_alloc  ) curr_head_ptr_next = curr_head_ptr_next + p_seq_num_bits'(alloc_rdy_cntr);
  end

  //----------------------------------------------------------------------
  // Freeing
  //----------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin: FREE_LOGIC
      assign is_free[i] = commit[i].val;
    end
  endgenerate

  logic [31:0] unused_commit_pc    [p_num_be_lanes];
  logic  [4:0] unused_commit_waddr [p_num_be_lanes];
  logic [31:0] unused_commit_wdata [p_num_be_lanes];
  logic        unused_commit_wen   [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin: UNUSED_COMMIT_SIGNALS
      assign unused_commit_pc[i]    = commit[i].pc;
      assign unused_commit_waddr[i] = commit[i].waddr;
      assign unused_commit_wdata[i] = commit[i].wdata;
      assign unused_commit_wen[i]   = commit[i].wen;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Reclaiming
  //----------------------------------------------------------------------

  // verilator lint_off SPLITVAR
  logic [p_reclaim_width-1:0] reclaim_valid /* verilator split_var */;
  // verilator lint_on SPLITVAR
  logic [p_reclaim_width-1:0] reclaim_select;

  generate
    for( i = 0; i < p_reclaim_width; i++ ) begin: RECLAIM_VAL
      if( i == 0 )
        assign reclaim_valid[i] = ( seq_num_list[p_seq_num_bits'(curr_tail_ptr[p_seq_num_bits-1:0] + i)] == FREE ) &
                                  ((p_seq_num_bits+1)'(i) < entries_allocated                              );
      else
        assign reclaim_valid[i] = ( seq_num_list[p_seq_num_bits'(curr_tail_ptr[p_seq_num_bits-1:0] + i)] == FREE ) &
                                  ((p_seq_num_bits+1)'(i) < entries_allocated                              ) &
                                  reclaim_valid[i - 1];
    end
  endgenerate

  // Identify the maximum amount to reclaim
  generate
    if (p_reclaim_width > 1) begin
      assign reclaim_select = reclaim_valid & (
        ((~reclaim_valid) >> 1) | 
        {1'b1, (p_reclaim_width-1)'(1'b0)}
      );
    end else begin
      assign reclaim_select = reclaim_valid & (
        ((~reclaim_valid) >> 1) | 
        {1'b1}
      );
    end
  endgenerate

  // Find the maximum amount to reclaim
  logic [p_seq_num_bits:0] curr_tail_incr;
  logic [p_seq_num_bits:0] curr_tail_incr_arr [p_reclaim_width];

  generate
    for( i = 0; i < p_reclaim_width; i++ ) begin: RECLAIM_INCR
      always_comb begin
        if( reclaim_select[i] )
          curr_tail_incr_arr[i] = (p_seq_num_bits+1)'(i + 1);
        else
          curr_tail_incr_arr[i] = '0;
      end
    end
  endgenerate

  assign curr_tail_incr = curr_tail_incr_arr.or();

  always_ff @( posedge clk ) begin
    if( rst ) begin
      curr_tail_ptr <= '0;
    end else begin
      curr_tail_ptr <= curr_tail_ptr + curr_tail_incr;
    end
  end

  logic [31:0] unused_squash_target;
  assign unused_squash_target = squash.target;

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  function automatic string trace( int trace_level );
    string alloc_trace, free_trace;

    alloc_trace = "";
    for( int j = 0; j < p_num_fe_lanes; j = j + 1 ) begin
      if( j != 0 )
        alloc_trace = {alloc_trace, ","};
      if( alloc_val[j] )
        alloc_trace = {alloc_trace, $sformatf("%h", alloc_seq_num[j])};
      else
        alloc_trace = {alloc_trace, {(ceil_div_4(p_seq_num_bits)){" "}}};
    end

    free_trace = "";
    for( int j = 0; j < p_num_be_lanes; j = j + 1 ) begin
      if( j != 0 )
        free_trace = {free_trace, ","};
      if( is_free[j] )
        free_trace = {free_trace, $sformatf("%h", commit_seq_num[j])};
      else
        free_trace = {free_trace, {(ceil_div_4(p_seq_num_bits)){" "}}};
    end

    if( trace_level > 0 )
      trace = $sformatf("%h::%h (%s) (%s)",
        curr_head_ptr,
        curr_tail_ptr,
        alloc_trace,
        free_trace
      );
    else
      trace = $sformatf("%s - %s", alloc_trace, free_trace);
  endfunction
`endif

endmodule

`endif // HW_FETCH_SEQNUMGENL5_V
