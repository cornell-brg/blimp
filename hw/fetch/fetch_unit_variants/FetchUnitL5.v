//========================================================================
// FetchUnitL5.v
//========================================================================
// A basic modular fetch unit for fetching instructions with squashing
// and support for superscalar backend. Uses a single wide memory
// interface; the response data is unpacked into p_num_fe_lanes items.

`ifndef HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL5_V
`define HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL5_V

`include "hw/common/Fifo.v"
`include "hw/fetch/SeqNumGenL5.v"
`include "intf/F__DIntf.v"
`include "intf/MemIntf.v"
`include "intf/CommitNotif.v"
`include "intf/SquashNotif.v"

module FetchUnitL5
#(
  parameter p_reclaim_width = 2,
  parameter p_max_in_flight = 16,
  parameter p_num_fe_lanes  = 2,
  parameter p_num_be_lanes  = 2
)
(
  input  logic    clk,
  input  logic    rst,

  //----------------------------------------------------------------------
  // Memory Interface (single wide port)
  //----------------------------------------------------------------------

  MemIntf.client mem,

  //----------------------------------------------------------------------
  // F <-> D Interface
  //----------------------------------------------------------------------

  F__DIntf.F_intf D [p_num_fe_lanes],

  //----------------------------------------------------------------------
  // Commit Interface
  //----------------------------------------------------------------------

  CommitNotif.sub commit [p_num_be_lanes],

  //----------------------------------------------------------------------
  // Squash Interface
  //----------------------------------------------------------------------

  SquashNotif.sub squash
);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Local Parameters
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  localparam p_rst_addr     = 32'h200;
  localparam p_seq_num_bits = D[0].p_seq_num_bits;

  localparam p_flight_bits  = $clog2(p_max_in_flight) + 1;
  localparam p_lane_idx_bits = p_num_fe_lanes > 1 ? $clog2(p_num_fe_lanes) : 1;

  logic [31:0] target_base_bm;
  assign target_base_bm = {{(32-$clog2(p_num_fe_lanes)){1'b1}}, {$clog2(p_num_fe_lanes){1'b0}}} << 2;
  logic [31:0] target_offset_bm;
  assign target_offset_bm = {{(32-$clog2(p_num_fe_lanes)){1'b0}}, {$clog2(p_num_fe_lanes){1'b1}}};

  //----------------------------------------------------------------------
  // D Interface Signal Arrays
  //----------------------------------------------------------------------

  genvar i;

  // D interface signals (driven by this module)
  logic                      D_val        [p_num_fe_lanes];
  logic               [31:0] D_inst       [p_num_fe_lanes];
  logic               [31:0] D_pc         [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] D_seq_num    [p_num_fe_lanes];
  logic                      D_insn_valid [p_num_fe_lanes];

  // D interface signals (driven by external)
  logic                      D_rdy     [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: D_INTF_CONNECT
      // Outputs to D interface
      assign D[i].val        = D_val[i];
      assign D[i].inst       = D_inst[i];
      assign D[i].pc         = D_pc[i];
      assign D[i].seq_num    = D_seq_num[i];
      assign D[i].insn_valid = D_insn_valid[i];

      // Inputs from D interface
      assign D_rdy[i] = D[i].rdy;
    end
  endgenerate

  //----------------------------------------------------------------------
  // Request
  //----------------------------------------------------------------------

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the number of in-flight requests
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic memreq_xfer;
  logic D_xfer_all;
  logic D_xfer [p_num_fe_lanes];
  logic D_rdy_all;

  always_comb begin
    D_xfer_all = 1'b1;
    D_rdy_all  = 1'b1;
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      D_xfer[j]   = D_val[j] & D_rdy[j];
      D_xfer_all &= D_xfer[j];
      D_rdy_all  &= D_rdy[j];
    end
  end

  assign memreq_xfer = mem.req_val & mem.req_rdy;

  logic [p_flight_bits-1:0] num_in_flight;
  logic [p_flight_bits-1:0] num_in_flight_next;

  always_ff @( posedge clk ) begin
    if( rst )
      num_in_flight <= '0;
    else
      num_in_flight <= num_in_flight_next;
  end

  logic should_drop; // Drop messages from squashing

  always_comb begin
    num_in_flight_next = num_in_flight;

    // All in-flight messages should be squashed
    if( squash.val )
      num_in_flight_next = 0;

    // Add in-flight fetch block (p_num_fe_lanes messages) for each request to
    // imem that goes out (and isn't immediately squashed)
    if( memreq_xfer & (!D_xfer_all | should_drop) )
      num_in_flight_next = num_in_flight_next + p_num_fe_lanes;

    // response that comes back (and isn't immediately squashed)
    if( D_xfer_all & !memreq_xfer & !should_drop )
      num_in_flight_next = num_in_flight_next - p_num_fe_lanes;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the in-flight requests to squash
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic resp_empty;

  logic [p_flight_bits-1:0] num_to_squash;
  logic [p_flight_bits-1:0] num_to_squash_next;

  always_ff @( posedge clk ) begin
    if ( rst )
      num_to_squash <= '0;
    else
      num_to_squash <= num_to_squash_next;
  end

  always_comb begin
    num_to_squash_next = num_to_squash;

    // If squashing, the next number of instructions to squash is incremented by
    // the number of instructions in flight
    if( squash.val )
      num_to_squash_next = num_to_squash_next + num_in_flight;

    // Remove a fetch block from number of instructions to squash as long as
    // there are insns at the front of the resp fifo and we actually have
    // some to squash
    if( !resp_empty & ( num_to_squash_next > 0 ) )
      num_to_squash_next = num_to_squash_next - p_num_fe_lanes;
  end

  assign should_drop = squash.val | ( num_to_squash > 0 );
  logic should_drop_prev;
  always_ff @( posedge clk ) begin
    if( rst )
      should_drop_prev <= 1'b0;
    else
      should_drop_prev <= should_drop;
  end

  logic do_squash_restart;
  assign do_squash_restart = should_drop_prev & !should_drop;

  logic do_squash_restart_reg;
  always_ff @( posedge clk ) begin
    if( rst )
      do_squash_restart_reg <= 1'b0;

    // If we are waiting to do a squash restart and we are transferring on this
    // cycle, then we know we are doing the restart on this cycle and can reset
    else if( (do_squash_restart_reg | do_squash_restart) & D_xfer_all )
      do_squash_restart_reg <= 1'b0;

    // Only update if we are not waiting for a squash restart to occur
    else if( !do_squash_restart_reg )
      do_squash_restart_reg <= do_squash_restart;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the current request address
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic [31:0] curr_fetch_block_base;
  logic [31:0] curr_fetch_block_base_next;
  logic [31:0] mem_req_addr;

  always_ff @( posedge clk ) begin
    if ( rst )
      curr_fetch_block_base <= 32'(p_rst_addr);
    else if ( squash.val & memreq_xfer )
      curr_fetch_block_base <= (squash.target & target_base_bm) + (p_num_fe_lanes << 2);
    else if ( squash.val )
      curr_fetch_block_base <= (squash.target & target_base_bm);
    else if ( memreq_xfer )
      curr_fetch_block_base <= curr_fetch_block_base_next;
  end

  always_comb begin
    curr_fetch_block_base_next = mem_req_addr + (p_num_fe_lanes << 2);
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Request signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  always_comb begin
    if ( squash.val )
      mem_req_addr = (squash.target & target_base_bm);
    else
      mem_req_addr = curr_fetch_block_base;
  end

  assign mem.req_val        = (num_in_flight + num_to_squash < p_max_in_flight);
  assign mem.req_msg.op     = MEM_MSG_READ;
  assign mem.req_msg.opaque = 'x;
  assign mem.req_msg.addr   = mem_req_addr;
  assign mem.req_msg.strb   = '0;
  assign mem.req_msg.data   = 'x;

  // Get lane index we need to restart valid instructions from after latest
  // squash
  logic [p_lane_idx_bits-1:0] squash_restart_offset;
  always_ff @(posedge clk) begin
    if( rst ) begin
      squash_restart_offset <= '0;
    end else if( squash.val ) begin
      squash_restart_offset <= p_lane_idx_bits'((squash.target >> 2) & target_offset_bm);
    end
  end

  //----------------------------------------------------------------------
  // Response
  //----------------------------------------------------------------------

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Allocation
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic [p_seq_num_bits-1:0] alloc_seq_num [p_num_fe_lanes];
  logic                      alloc_rdy     [p_num_fe_lanes];
  logic                      alloc_val     [p_num_fe_lanes];

  SeqNumGenL5 #(
    .p_seq_num_bits  (p_seq_num_bits),
    .p_reclaim_width (p_reclaim_width),
    .p_num_fe_lanes  (p_num_fe_lanes),
    .p_num_be_lanes  (p_num_be_lanes)
  ) seq_num_gen (
    .*
  );

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Response FIFO
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // FIFO stores base address + wide instruction data per fetch block
  localparam p_fifo_data_bits  = p_num_fe_lanes * 32;
  localparam p_fifo_entry_bits = 32 + p_fifo_data_bits;

  logic resp_push, resp_pop, resp_full;
  logic [p_fifo_entry_bits-1:0] fifo_wdata;
  logic [p_fifo_entry_bits-1:0] fifo_rdata;

  assign fifo_wdata = {mem.resp_msg.addr, mem.resp_msg.data};

  // Unpack FIFO read data
  logic [31:0]                 fifo_rdata_addr;
  logic [p_fifo_data_bits-1:0] fifo_rdata_data;

  assign fifo_rdata_addr = fifo_rdata[p_fifo_entry_bits-1 -: 32];
  assign fifo_rdata_data = fifo_rdata[p_fifo_data_bits-1:0];

  Fifo #(
    .p_entry_bits (p_fifo_entry_bits),
    .p_depth      (8)
  ) resp_fifo (
    .clk   (clk),
    .rst   (rst),
    .push  (resp_push),
    .pop   (resp_pop),
    .empty (resp_empty),
    .full  (resp_full),
    .wdata (fifo_wdata),
    .rdata (fifo_rdata)
  );

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Other response signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic alloc_ok [p_num_fe_lanes];
  logic alloc_ok_all;
  always_comb begin
    alloc_ok_all = 1'b1;
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      if( (do_squash_restart | do_squash_restart_reg) ) begin
        if( p_lane_idx_bits'(j) >= squash_restart_offset )
          alloc_ok_all &= alloc_ok[j];
        else
          alloc_ok_all &= 1'b1;
      end else begin
        alloc_ok_all &= alloc_ok[j];
      end
    end
  end

  assign resp_push    = mem.resp_val & !resp_full;
  assign resp_pop     = ((D_rdy_all & alloc_ok_all) | should_drop) & !resp_empty;
  assign mem.resp_rdy = !resp_full;

  // Per-lane response signals
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: RESP_LANE

      assign alloc_ok[i] = alloc_rdy[i] & alloc_val[i];

      always_comb begin
        if( (do_squash_restart | do_squash_restart_reg) ) begin
          D_insn_valid[i] = !resp_empty & (i >= squash_restart_offset);
          alloc_rdy[i]    = !resp_empty & D_rdy[i] & (i >= squash_restart_offset);
          /* verilator lint_off CMPCONST */
          if( p_lane_idx_bits'(i) >= squash_restart_offset )
            D_val[i]        = !resp_empty & alloc_ok[i];
          else
            D_val[i]        = !resp_empty;
          /* verilator lint_on CMPCONST */
        end else begin
          D_insn_valid[i] = !resp_empty & !should_drop;
          alloc_rdy[i]    = !resp_empty & D_rdy[i] & !should_drop;
          D_val[i]        = !resp_empty & alloc_ok[i] & !should_drop;
        end
      end

      always_comb begin
        D_inst[i]    = fifo_rdata_data[i*32 +: 32];
        D_pc[i]      = fifo_rdata_addr + 32'(i << 2);
        D_seq_num[i] = alloc_seq_num[i];
      end
    end
  endgenerate

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Unused signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic [p_seq_num_bits-1:0] unused_squash_seq_num;

  always_comb begin
    unused_squash_seq_num = squash.seq_num;
  end

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

// `ifndef SYNTHESIS
//   function int ceil_div_4( int val );
//     return (val / 4) + ((val % 4) > 0 ? 1 : 0);
//   endfunction

//   function string trace( int trace_level );
//     if( trace_level > 0 ) begin
//       if( memreq_xfer )
//         trace = $sformatf("%h", mem.req_msg.addr);
//       else
//         trace = {8{" "}};

//       trace = {trace, " > "};

//       if( D_xfer )
//         trace = {trace, $sformatf("%h (%h) %s ",
//                                   mem.resp_msg.addr, alloc_seq_num,
//                                   (should_drop ? "X" : " "))};
//       else
//         trace = {trace, {(14 + ceil_div_4(p_seq_num_bits)){" "}}};
//     end else begin
//       if( D_xfer )
//         if( should_drop )
//           trace = {(ceil_div_4(p_seq_num_bits) + 2 + 8){"X"}};
//         else
//           trace = $sformatf("%h: %h", alloc_seq_num, mem.resp_msg.addr);
//       else
//         trace = {(ceil_div_4(p_seq_num_bits) + 2 + 8){" "}};
//     end
//   endfunction
// `endif

endmodule

`endif // HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL5_V
