//========================================================================
// SeqNumGenL5.v
//========================================================================
// A module for generating and managing sequence numbers with squashing and
// support for superscalar backend. p_num_fe_lanes sequence numbers will be
// allocated at once

`ifndef HW_FETCH_SEQNUMGENL5_V
`define HW_FETCH_SEQNUMGENL5_V

`include "hw/util/MSeqAge.v"
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

  output logic [p_seq_num_bits-1:0] alloc_seq_num [p_num_fe_lanes],
  output logic                      alloc_val,
  input  logic                      alloc_rdy,

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

  MSeqAge #(
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
  logic [p_seq_num_bits-1:0] curr_head_ptr, curr_tail_ptr;
  logic is_alloc;
  logic [p_num_be_lanes-1:0] is_free;

  generate
    for( i = 0; i < p_num_entries; i++ ) begin: SEQ_NUM
      always_ff @( posedge clk ) begin
        if( rst ) seq_num_list[i] <= 1'b0;
        else begin

          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
          // Allocation
          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

          if( is_alloc & ( curr_head_ptr == i ) )
            seq_num_list[i] <= ALLOC;

          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
          // Freeing
          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

          for( int j = 0; j < p_num_be_lanes; j++ ) begin
            if( is_free[j] & ( commit_seq_num[j] == i ) )
              seq_num_list[i] <= FREE;
          end

          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
          // Squashing
          // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

          if( squash.val & seq_age.is_older( squash.seq_num, p_seq_num_bits'(i) ) )
            // The corresponding instruction is squashed
            seq_num_list[i] <= FREE;
        end
      end
    end
  endgenerate

  //----------------------------------------------------------------------
  // Allocation
  //----------------------------------------------------------------------

  // Can only allocate if we're not about to wrap around and next sequence
  // number to allocate is free
  assign alloc_val = !( curr_head_ptr + 1 == curr_tail_ptr ) & 
                      ( seq_num_list[curr_head_ptr] == FREE );

  assign is_alloc = alloc_val & alloc_rdy;
  assign alloc_seq_num = ( squash.val ) ? squash.seq_num + 1
                                        : curr_head_ptr;
  logic [p_seq_num_bits-1:0] curr_head_ptr_next;

  always_ff @( posedge clk ) begin
    if( rst ) begin
      curr_head_ptr <= '0;
    end else begin
      curr_head_ptr <= curr_head_ptr_next;
    end
  end

  always_comb begin
    curr_head_ptr_next = curr_head_ptr;

    if( squash.val ) curr_head_ptr_next = squash.seq_num + 1;
    if( is_alloc   ) curr_head_ptr_next = curr_head_ptr_next + 1;
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

  logic [p_seq_num_bits-1:0] entries_allocated;
  assign entries_allocated = curr_head_ptr - curr_tail_ptr;

  logic [p_reclaim_width-1:0] reclaim_valid /* verilator split_var */;
  logic [p_reclaim_width-1:0] reclaim_select;

  generate
    for( i = 0; i < p_reclaim_width; i++ ) begin: RECLAIM_VAL
      if( i == 0 )
        assign reclaim_valid[i] = ( seq_num_list[p_seq_num_bits'(curr_tail_ptr + i)] == FREE ) &
                                  (p_seq_num_bits'(i) < entries_allocated                    );
      else
        assign reclaim_valid[i] = ( seq_num_list[p_seq_num_bits'(curr_tail_ptr + i)] == FREE ) &
                                  (p_seq_num_bits'(i) < entries_allocated                    ) &
                                  reclaim_valid[i - 1];
    end
  endgenerate

  // Identify the maximum amount to reclaim
  assign reclaim_select = reclaim_valid & (
    ((~reclaim_valid) >> 1) | 
    {1'b1, (p_reclaim_width-1)'(1'b0)}
  );

  // Find the maximum amount to reclaim
  logic [p_seq_num_bits-1:0] curr_tail_incr;
  logic [p_seq_num_bits-1:0] curr_tail_incr_arr [p_reclaim_width];

  generate
    for( i = 0; i < p_reclaim_width; i++ ) begin: RECLAIM_INCR
      always_comb begin
        if( reclaim_select[i] )
          curr_tail_incr_arr[i] = p_seq_num_bits'(i + 1);
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

    if( is_alloc )
      alloc_trace = $sformatf("%h", alloc_seq_num);
    else
      alloc_trace = {ceil_div_4(p_seq_num_bits){" "}};

    for( int j = 0; j < p_num_be_lanes; j = j + 1 ) begin
      if( is_free[j] )
        free_trace = $sformatf("%h", commit_seq_num[j]);
      else
        free_trace = {ceil_div_4(p_seq_num_bits){" "}};
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
