//========================================================================
// MROB.v
//========================================================================
// A basic reorder buffer to ensure in-order commit, can enqueue and dequeue
// multiple instructions at once

`ifndef HW_WRITEBACK_MROB_V
`define HW_WRITEBACK_MROB_V

module MROB #(
  parameter p_depth    = 32,
  parameter p_msg_bits = 32,
  parameter p_num_lanes = 2,
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
        entries[i] <= '{msg: 'x, val: 1'b0};
      end
    end else begin
      for( int i = 0; i < p_num_lanes; i++ ) begin
        if( ins_en & ins_msg_val[i] ) begin
          entries[ins_idx[i]] <= '{
            msg: ins_msg[i],
            val: 1'b1
          };
        end
        if( deq_en & deq_rdy & deq_msg_val[i] ) begin
          entries[deq_idx[i]] <= '{msg: 'x, val: 1'b0};
        end
      end
    end
  end

  //----------------------------------------------------------------------
  // Dequeue
  //----------------------------------------------------------------------

  logic [p_entry_bits-1:0] deq_ptr_next;
  logic [p_depth-1:0]      val_rot_pack;

  assign deq_rdy = entries[deq_ptr].val;

  logic [p_entry_bits-1:0] deq_idx_full [p_depth];
  logic [p_msg_bits-1:0]   deq_msg_full [p_depth];
  
  // get which entries are valid with entry at deq_ptr at index 0
  always_comb begin
    for( int i = 0; i < p_depth; i++ ) begin
      if( i + int'(deq_ptr) < p_depth ) begin
        val_rot_pack[i] = entries[i + int'(deq_ptr)].val;
        deq_msg_full[i] = entries[i + int'(deq_ptr)].msg;
        deq_idx_full[i] = deq_ptr + p_entry_bits'(i);
      end else begin
        val_rot_pack[i] = entries[i + int'(deq_ptr) - p_depth].val;
        deq_msg_full[i] = entries[i + int'(deq_ptr) - p_depth].msg;
        deq_idx_full[i] = deq_ptr + p_entry_bits'(i - p_depth);
      end
    end
  end

  // set output rdy bits up to first invalid entry
  logic [p_depth-1:0] val_rot_pack_edges;
  logic [p_depth-1:0] val_rot_pack_first_edge;
  logic [p_entry_bits-1:0] first_invalid_idx;

  assign val_rot_pack_edges = val_rot_pack & ~(val_rot_pack >> 1);
  assign val_rot_pack_first_edge = val_rot_pack_edges & (~val_rot_pack_edges + 1);

  logic [p_depth-1:0] val_rot_pack_thermo;

  always_comb begin
    first_invalid_idx = '0;
    for( int i = p_depth-1; i >= 0; i-- ) begin
      if (i == p_depth-1)
        val_rot_pack_thermo[i] = val_rot_pack_first_edge[i];
      else
        val_rot_pack_thermo[i] = val_rot_pack_first_edge[i] | val_rot_pack_thermo[i+1];

      if (val_rot_pack_first_edge[i])
        first_invalid_idx = (p_entry_bits)'(i+1);
    end
  end

  always_comb begin
    for( int i = 0; i < p_num_lanes; i++ ) begin
      deq_msg_val[i] = val_rot_pack_thermo[i];
      deq_msg[i]     = deq_msg_full[i];
      deq_idx[i]     = deq_idx_full[i];
    end
  end

  always_ff @( posedge clk ) begin
    if( rst )
      deq_ptr <= '0;
    else if( deq_en & deq_rdy )
      deq_ptr <= deq_ptr_next;
  end

  logic [p_entry_bits:0] deq_ptr_add_val;

  always_comb begin

    // get value to add to deq_ptr based on first invalid index
    if( entries[first_invalid_idx].val ) begin
      deq_ptr_add_val = (p_entry_bits+1)'(p_depth) - (p_entry_bits+1)'(deq_ptr);
    end else if( (p_entry_bits+1)'(first_invalid_idx + deq_ptr) > (p_entry_bits+1)'(p_depth - 1) ) begin
      deq_ptr_add_val = (p_entry_bits+1)'(first_invalid_idx) - (p_entry_bits+1)'(p_depth);
    end else begin
      deq_ptr_add_val = (p_entry_bits+1)'(first_invalid_idx);
    end

    // truncate actual value added if > number of available lanes
    if( deq_ptr_add_val > (p_entry_bits+1)'(p_num_lanes) ) 
      deq_ptr_next = deq_ptr + p_entry_bits'(p_num_lanes);
    else
      deq_ptr_next = deq_ptr + p_entry_bits'(deq_ptr_add_val);
  end

  always_comb begin
    avail_slots = '0;
    for( int i = 0; i < p_depth; i++ ) begin
      if( !entries[i].val )
        avail_slots = avail_slots + 1;
    end
  end

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

// `ifndef SYNTHESIS
//   function int ceil_div_4( int val );
//     return (val / 4) + ((val % 4) > 0 ? 1 : 0);
//   endfunction

//   string test_trace;
//   int    msg_len;

//   initial begin
//     test_trace = $sformatf("%x:%x", ins_idx, ins_msg);
//     msg_len = test_trace.len();
//   end

//   function string trace( int trace_level );
//     if( ins_en ) begin
//       if( trace_level > 0 )
//         trace = $sformatf("%x:%x", ins_idx, ins_msg);
//       else
//         trace = $sformatf("%x", ins_idx);
//     end else begin
//       if( trace_level > 0 )
//         trace = {(msg_len){" "}};
//       else 
//         trace = {(ceil_div_4(p_entry_bits)){" "}};
//     end

//     trace = {trace, " > "};

//     if( deq_en & deq_rdy ) begin
//       if( trace_level > 0 )
//         trace = {trace, $sformatf("%x:%x", deq_idx, deq_msg)};
//       else
//         trace = {trace, $sformatf("%x", deq_idx)};
//     end else begin
//       if( trace_level > 0 )
//         trace = {trace, {(msg_len){" "}}};
//       else 
//         trace = {trace, {(ceil_div_4(p_entry_bits)){" "}}};
//     end
//   endfunction
// `endif

endmodule

`endif // HW_WRITEBACK_ROB_V
