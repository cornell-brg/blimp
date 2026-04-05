//========================================================================
// MROB.v
//========================================================================
// A basic reorder buffer to ensure in-order commit, can enqueue and dequeue
// multiple instructions at once

`ifndef HW_WRITEBACK_MROB_V
`define HW_WRITEBACK_MROB_V

module MROB #(
  parameter p_depth      = 32,
  parameter p_msg_bits   = 32,
  parameter p_num_lanes  = 2,
  parameter p_entry_bits = $clog2( p_depth )
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Insert
  //----------------------------------------------------------------------

  input  logic [p_entry_bits-1:0] ins_idx     [p_num_lanes],
  input  logic [p_msg_bits-1:0]   ins_msg     [p_num_lanes],
  input  logic                    ins_msg_val [p_num_lanes],
  output logic                    ins_rdy,
  input  logic                    ins_en,
  output logic [p_entry_bits:0]   avail_slots,

  //----------------------------------------------------------------------
  // Dequeue
  //----------------------------------------------------------------------

  output logic [p_entry_bits-1:0] deq_idx     [p_num_lanes],
  output logic [p_msg_bits-1:0]   deq_msg     [p_num_lanes],
  output logic                    deq_msg_val [p_num_lanes],
  output logic                    deq_rdy,
  input  logic                    deq_en
);

  logic [p_entry_bits-1:0] deq_ptr;

  //----------------------------------------------------------------------
  // Entries
  //----------------------------------------------------------------------

  typedef struct packed {
    logic [p_msg_bits-1:0] msg;
    logic                  val;
  } t_entry;

  t_entry entries [p_depth];

  assign ins_rdy = (avail_slots > 0);

  //----------------------------------------------------------------------
  // Update Logic
  //----------------------------------------------------------------------

  always_ff @( posedge clk ) begin
    if( rst ) begin
      for( int i = 0; i < p_depth; i++ ) begin
        entries[i] <= '{msg: '0, val: 1'b0};
      end
    end else begin

      // Insert message into entries for each insert index that is valid
      for( int i = 0; i < p_num_lanes; i++ ) begin
        if( ins_en & ins_msg_val[i] ) begin
          entries[ins_idx[i]] <= '{
            msg: ins_msg[i],
            val: 1'b1
          };
        end
      end

      // If, however, we are also dequeuing this index, clear the entry
      for( int i = 0; i < p_num_lanes; i++ ) begin
        if( deq_en & deq_rdy & deq_msg_val[i] ) begin
          entries[deq_idx[i]] <= '{msg: '0, val: 1'b0};
        end
      end
    end
  end

  //----------------------------------------------------------------------
  // Bypass
  //----------------------------------------------------------------------
  // Bypassing is enabled if any of the insert indices match the deq_ptr

  logic can_bypass;

  always_comb begin
    can_bypass = 1'b0;
    for( int i = 0; i < p_num_lanes; i++ ) begin
      if( ins_idx[i] == deq_ptr && ins_msg_val[i]) begin
        can_bypass = 1'b1;
      end
    end
  end

  //----------------------------------------------------------------------
  // Dequeue
  //----------------------------------------------------------------------

  // Ready to dequeue if we have a valid entry at deq_ptr or can bypass
  assign deq_rdy = entries[deq_ptr].val | ( can_bypass & ins_en );

  // Rotate and bypass only p_num_lanes entries starting from deq_ptr,
  // rather than the full p_depth array. Insert bypass is applied inline.
  logic [p_entry_bits-1:0] deq_ptr_next;
  logic [p_num_lanes-1:0]  val_rot;

  always_comb begin
    for( int i = 0; i < p_num_lanes; i++ ) begin
      // Index into entries with natural wrap-around (power-of-2 depth)
      deq_idx[i] = deq_ptr + (p_entry_bits)'(unsigned'(i));

      // Start with stored entry value
      val_rot[i] = entries[deq_idx[i]].val;
      deq_msg[i] = entries[deq_idx[i]].msg;

      // Apply insert bypass: if any insert lane targets this index, use it
      for( int j = 0; j < p_num_lanes; j++ ) begin
        if( ins_en & ins_msg_val[j] & (ins_idx[j] == deq_idx[i]) ) begin
          val_rot[i] = 1'b1;
          deq_msg[i] = ins_msg[j];
        end
      end
    end
  end

  // Consecutive valid check: each val_thermo bit is the AND-reduction of
  // val_rot[0..i], computed independently to avoid cross-bit dependencies.
  logic [p_num_lanes-1:0] val_thermo;

  always_comb begin
    for( int i = 0; i < p_num_lanes; i++ ) begin
      val_thermo[i] = 1'b1;
      for( int k = 0; k <= i; k++ )
        val_thermo[i] = val_thermo[i] & val_rot[k];
      deq_msg_val[i] = val_thermo[i];
    end
  end

  // Advance deq_ptr by popcount of thermometer (already capped at p_num_lanes)
  logic [p_entry_bits-1:0] deq_ptr_adv;

  always_comb begin
    deq_ptr_adv = '0;
    for( int i = 0; i < p_num_lanes; i++ )
      deq_ptr_adv = deq_ptr_adv + p_entry_bits'(val_thermo[i]);
    deq_ptr_next = deq_ptr + deq_ptr_adv;
  end

  always_ff @( posedge clk ) begin
    if( rst )
      deq_ptr <= '0;
    else if( deq_en & deq_rdy )
      deq_ptr <= deq_ptr_next;
  end

  // Track available slots with an incremental counter instead of
  // recomputing a p_depth-wide popcount every cycle
  logic [p_entry_bits:0] num_inserted;
  logic [p_entry_bits:0] num_dequeued;

  always_comb begin
    num_inserted = '0;
    for( int i = 0; i < p_num_lanes; i++ )
      if( ins_en & ins_msg_val[i] )
        num_inserted = num_inserted + 1;
  end

  always_comb begin
    num_dequeued = '0;
    for( int i = 0; i < p_num_lanes; i++ )
      if( deq_en & deq_rdy & deq_msg_val[i] )
        num_dequeued = num_dequeued + 1;
  end

  always_ff @( posedge clk ) begin
    if( rst )
      avail_slots <= (p_entry_bits+1)'(p_depth);
    else
      avail_slots <= avail_slots - num_inserted + num_dequeued;
  end

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  string test_trace;
  int    msg_len;

  initial begin
    test_trace = $sformatf("%x:%x", ins_idx[0], ins_msg[0]);
    msg_len = test_trace.len();
  end

  function string trace( int trace_level );
    trace = "";

    for( int i = 0; i < p_num_lanes; i++ ) begin
      if( i != 0 )
        trace = {trace, "  "};

      if( ins_en ) begin
        if( trace_level > 0 )
          trace = {trace, $sformatf("%x:%x", ins_idx[i], ins_msg[i])};
        else
          trace = {trace, $sformatf("%x", ins_idx[i])};
      end else begin
        if( trace_level > 0 )
          trace = {trace, {(msg_len){" "}}};
        else 
          trace = {trace, {(ceil_div_4(p_entry_bits)){" "}}};
      end

      trace = {trace, " > "};

      if( deq_en & deq_rdy ) begin
        if( trace_level > 0 )
          trace = {trace, $sformatf("%x:%x", deq_idx[i], deq_msg[i])};
        else
          trace = {trace, $sformatf("%x", deq_idx[i])};
      end else begin
        if( trace_level > 0 )
          trace = {trace, {(msg_len){" "}}};
        else 
          trace = {trace, {(ceil_div_4(p_entry_bits)){" "}}};
      end
    end
  endfunction
`endif

endmodule

`endif // HW_WRITEBACK_ROB_V
