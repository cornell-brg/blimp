//========================================================================
// SeqNumGenL2.v
//========================================================================
// A module for generating and managing sequence numbers

`ifndef HW_FETCH_SEQNUMGENL2_V
`define HW_FETCH_SEQNUMGENL2_V

`include "intf/CommitNotif.v"

module SeqNumGenL2 #(
  parameter p_seq_num_bits  = 5,
  parameter p_reclaim_width = 2 // Number of entries that can be reclaimed at once
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Allocation Interface
  //----------------------------------------------------------------------

  output logic [p_seq_num_bits-1:0] alloc_seq_num,
  output logic                      alloc_val,
  input  logic                      alloc_rdy,

  //----------------------------------------------------------------------
  // Commit Interface to free sequence numbers
  //----------------------------------------------------------------------

  CommitNotif.sub commit
);

  //----------------------------------------------------------------------
  // Sequence Number List
  //----------------------------------------------------------------------
  // Keep track of which ones are allocated

  localparam ALLOC = 1'b1;
  localparam FREE  = 1'b0;

  logic seq_num_list [2 ** p_seq_num_bits];
  logic [p_seq_num_bits-1:0] curr_head_ptr, curr_tail_ptr;
  logic is_alloc, is_free;

  always_ff @( posedge clk ) begin
    if( rst ) seq_num_list <= '{default: 1'b0};
    else begin

      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      // Allocation
      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      if( is_alloc )
        seq_num_list[curr_head_ptr] <= ALLOC;

      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      // Freeing
      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      if( is_free )
        seq_num_list[commit.seq_num] <= FREE;
    end
  end

  //----------------------------------------------------------------------
  // Allocation
  //----------------------------------------------------------------------

  // Can only allocate if we're not about to wrap around
  assign alloc_val = ( (curr_tail_ptr == 0) ? !(curr_head_ptr == '1) : !(curr_head_ptr + 1 == curr_tail_ptr) );

  assign is_alloc = alloc_val & alloc_rdy;
  assign alloc_seq_num = curr_head_ptr;

  always_ff @( posedge clk ) begin
    if( rst ) begin
      curr_head_ptr <= '0;
    end else begin
      if( is_alloc ) curr_head_ptr <= curr_head_ptr + 1;
    end
  end

  //----------------------------------------------------------------------
  // Freeing
  //----------------------------------------------------------------------

  assign is_free = commit.val;

  logic [31:0] unused_commit_pc;
  logic  [4:0] unused_commit_waddr;
  logic [31:0] unused_commit_wdata;
  logic        unused_commit_wen;

  assign unused_commit_pc    = commit.pc;
  assign unused_commit_waddr = commit.waddr;
  assign unused_commit_wdata = commit.wdata;
  assign unused_commit_wen   = commit.wen;

  //----------------------------------------------------------------------
  // Reclaiming
  //----------------------------------------------------------------------

  logic [p_seq_num_bits-1:0] entries_allocated;
  assign entries_allocated = curr_head_ptr - curr_tail_ptr;

  logic [p_reclaim_width-1:0] reclaim_valid /* verilator split_var */;
  logic [p_reclaim_width-1:0] reclaim_select;

  genvar i;
  generate
    for( i = 0; i < p_reclaim_width; i = i + 1 ) begin
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
    for( i = 0; i < p_reclaim_width; i = i + 1 ) begin
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

    if( is_free )
      free_trace = $sformatf("%h", commit.seq_num);
    else
      free_trace = {ceil_div_4(p_seq_num_bits){" "}};

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

`endif // HW_FETCH_SEQNUMGENL2_V
