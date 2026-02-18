//========================================================================
// FetchUnitL5.v
//========================================================================
// A basic modular fetch unit for fetching instructions with squashing
// and support for superscalar backend

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
  // Memory Interface
  //----------------------------------------------------------------------

  MemIntf.client mem [p_num_fe_lanes],

  //----------------------------------------------------------------------
  // F <-> D Interface
  //----------------------------------------------------------------------

  F__DIntf.F_intf D [p_num_be_lanes],

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

  //----------------------------------------------------------------------
  // Request
  //----------------------------------------------------------------------

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the number of in-flight requests
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // All ports are tied together to keep fetch blocks aligned
  logic memreq_xfer_all;
  logic memreq_xfer [p_num_fe_lanes];
  logic D_xfer_all;
  logic D_xfer [p_num_fe_lanes]

  always_comb begin
    memreq_xfer_all = 1'b1;
    D_xfer_all      = 1'b1;
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      memreq_xfer[i]  = mem[i].req_val & mem[i].req_rdy;
      memreq_xfer_all &= memreq_xfer[i];
      D_xfer[i]       = D[i].val & D[i].rdy;
      D_xfer_all      &= D_xfer[i];
    end
  end

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

    // Add in-flight fetch block (4 messages) for each request to imem that goes
    // out (and isn't immediately squashed)
    if( memreq_xfer_all & (!D_xfer_all | should_drop) )
      num_in_flight_next = num_in_flight_next + 4;

    // Remove an in-flight fetch block (4 messages) for each response that comes
    // back (and isn't immediately squashed)
    if( D_xfer_all & !memreq_xfer_all & !should_drop )
      num_in_flight_next = num_in_flight_next - 4;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the in-flight requests to squash
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic                     resp_all;
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
    // there are some instructions exiting the fetch blcok
    if( resp_all & ( num_to_squash_next > 0 ) )
      num_to_squash_next = num_to_squash_next - 4;
  end

  assign should_drop = squash.val | ( num_to_squash > 0 );

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the current request address
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic [31:0] curr_fetch_block_base;
  logic [31:0] curr_fetch_block_base_next;

  always_ff @( posedge clk ) begin
    for (int i = 0; i < p_num_fe_lanes; i++ ) begin
      if ( rst )
        curr_fetch_block_base <= 32'(p_rst_addr);
      else if ( squash.val & memreq_xfer[i] )
        curr_fetch_block_base <= squash.target + 4;
      else if ( squash.val )
        curr_fetch_block_base <= squash.target;
      else if ( memreq_xfer[i] )
        curr_fetch_block_base <= curr_fetch_block_base_next;
    end
  end

  always_comb begin
    curr_fetch_block_base_next = mem[0].req_msg.addr + 4;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Determine the correct address to send out
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  always_comb begin
    for (int i = 0; i < p_num_fe_lanes; i++ ) begin
      if ( squash.val )
        mem[i].req_msg.addr = squash.target + 32'(i << 2);
      else
        mem[i].req_msg.addr = curr_fetch_block_base + 32'(i << 2);
    end
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Other request signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  always_comb begin
    for ( int i = 0; i < p_num_fe_lanes; i++ ) begin
      mem[i].req_val        = (num_in_flight + num_to_squash < p_max_in_flight);
      mem[i].req_msg.op     = MEM_MSG_READ;
      mem[i].req_msg.opaque = 'x;
      mem[i].req_msg.strb   = '0;
      mem[i].req_msg.data   = 'x;
    end
  end

  //----------------------------------------------------------------------
  // Response
  //----------------------------------------------------------------------

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Allocation
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic                      alloc_val     [p_num_fe_lanes];
  logic                      alloc_rdy     [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] alloc_seq_num [p_num_fe_lanes];

  SeqNumGenL5 #(
    .p_seq_num_bits  (p_seq_num_bits),
    .p_reclaim_width (p_reclaim_width),
    .p_num_be_lanes  (p_num_be_lanes)
  ) seq_num_gen (
    .*
  );

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Other response signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  typedef struct packed {
    t_op                    op;
    logic [31:0]            addr;
    logic [3:0]             strb;
    logic [31:0]            data;
  } mem_msg_t;

  logic resp_empty [p_num_fe_lanes];
  always_comb begin
    resp_all = 1'b1;
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      resp_all &= !resp_empty[i];
    end
  end

  genvar i;
  generate
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      logic resp_push, resp_pop, resp_full;
      mem_msg_t fifo_rdata, fifo_wdata;

      Fifo #(
        .p_entry_bits ($bits(mem_msg_t)),
        .p_depth      (8)
      ) resp_fifo (
        .clk   (clk),
        .rst   (rst),
        .push  (resp_push),
        .pop   (resp_pop),
        .empty (resp_empty[i]),
        .full  (resp_full),
        .wdata (fifo_wdata),
        .rdata (fifo_rdata)
      );

      assign fifo_wdata.op   = mem[i].resp_msg.op;
      assign fifo_wdata.addr = mem[i].resp_msg.addr;
      assign fifo_wdata.strb = mem[i].resp_msg.strb;
      assign fifo_wdata.data = mem[i].resp_msg.data;

      assign resp_push       = mem[i].resp_val & !resp_full;
      assign mem[i].resp_rdy = !resp_full;
      assign resp_pop        = ((D[i].rdy & alloc_val[i]) | should_drop) & !resp_empty[i];
      assign D[i].val        = !resp_empty[i] & alloc_val[i] & !should_drop;
      assign alloc_rdy[i]    = !resp_empty[i] & D[i].rdy & !should_drop;

      always_comb begin
        D[i].inst    = fifo_rdata.data;
        D[i].pc      = fifo_rdata.addr;
        D[i].seq_num = alloc_seq_num[i];
      end

      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      // Unused signals
      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      logic                      unused_resp_op;
      logic                [3:0] unused_resp_strb;
      logic [p_seq_num_bits-1:0] unused_squash_seq_num;

      always_comb begin
        unused_resp_op   = fifo_rdata.op;
        unused_resp_strb = fifo_rdata.strb;

        unused_squash_seq_num = squash.seq_num;
      end
    end
  endgenerate

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
