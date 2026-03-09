//========================================================================
// FetchUnitL5.v
//========================================================================
// A FIFO-less fetch unit for fetching instructions with squashing and
// support for superscalar backend. Uses a single wide memory interface;
// the response data is unpacked into p_num_fe_lanes items. Memory
// responses flow directly to the D interface with no buffering.

`ifndef HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL5_V
`define HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL5_V

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

  localparam       p_rst_addr          = 32'h200;

  localparam [1:0] INST_STATUS_INVALID = 2'b00,
                   INST_STATUS_READY   = 2'b01;

  localparam       p_seq_num_bits      = D[0].p_seq_num_bits;
       
  localparam       p_flight_bits       = $clog2(p_max_in_flight) + 1;
  localparam       p_lane_idx_bits     = p_num_fe_lanes > 1 ? 
                                          $clog2(p_num_fe_lanes) : 1;

  logic [31:0] target_base_bm;
  assign target_base_bm = {{(32-$clog2(p_num_fe_lanes)){1'b1}}, 
                           {$clog2(p_num_fe_lanes){1'b0}}} << 2;
  logic [31:0] target_offset_bm;
  assign target_offset_bm = {{(32-$clog2(p_num_fe_lanes)){1'b0}}, 
                             {$clog2(p_num_fe_lanes){1'b1}}};

  //----------------------------------------------------------------------
  // D Interface Signal Arrays
  //----------------------------------------------------------------------

  genvar i;

  // D interface signals (driven by this module)
  logic                      D_val        [p_num_fe_lanes];
  logic               [31:0] D_inst       [p_num_fe_lanes];
  logic               [31:0] D_pc         [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] D_seq_num    [p_num_fe_lanes];
  logic                [1:0] D_inst_status [p_num_fe_lanes];

  // D interface signals (driven by external)
  logic                      D_rdy     [p_num_fe_lanes];

  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: D_INTF_CONNECT
      // Outputs to D interface
      assign D[i].val         = D_val[i];
      assign D[i].inst        = D_inst[i];
      assign D[i].pc          = D_pc[i];
      assign D[i].seq_num     = D_seq_num[i];
      assign D[i].inst_status = D_inst_status[i];

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
    // imem that goes out
    if( memreq_xfer & !D_xfer_all )
      num_in_flight_next = num_in_flight_next + p_num_fe_lanes;

    // Response that comes back and is consumed by D
    if( D_xfer_all & !memreq_xfer )
      num_in_flight_next = num_in_flight_next - p_num_fe_lanes;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the in-flight requests to squash
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

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

    // Drain a stale fetch block when memory delivers a response and we have
    // some to squash (should_drop is guaranteed true, so mem.resp_rdy is high)
    if( mem.resp_val & ( num_to_squash_next > 0 ) )
      num_to_squash_next = num_to_squash_next - p_num_fe_lanes;
  end

  assign should_drop = squash.val | ( num_to_squash > 0 );

  // Track whether the next good transfer needs squash restart lane masking
  logic needs_squash_restart;
  always_ff @( posedge clk ) begin
    if( rst )
      needs_squash_restart <= 1'b0;
    else if( squash.val )
      needs_squash_restart <= 1'b1;
    else if( D_xfer_all )
      needs_squash_restart <= 1'b0;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the current request address
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic [31:0] curr_fetch_block_base;
  logic [31:0] mem_req_addr;

  always_ff @( posedge clk ) begin
    if ( rst )
      curr_fetch_block_base <= 32'(p_rst_addr);
    else if ( squash.val & memreq_xfer )
      curr_fetch_block_base <= (squash.target & target_base_bm) + (p_num_fe_lanes << 2);
    else if ( squash.val )
      curr_fetch_block_base <= (squash.target & target_base_bm);
    else if ( memreq_xfer )
      curr_fetch_block_base <= mem_req_addr + (p_num_fe_lanes << 2);
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

  assign mem.req_val        = squash.val | 
                              (num_in_flight + num_to_squash < p_max_in_flight);
  assign mem.req_msg.op     = MEM_MSG_READ;
  assign mem.req_msg.opaque = '0;
  assign mem.req_msg.addr   = mem_req_addr;
  assign mem.req_msg.strb   = '0;
  assign mem.req_msg.data   = '0;

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
  // Response signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic alloc_ok [p_num_fe_lanes];
  logic alloc_ok_all;
  always_comb begin
    alloc_ok_all = 1'b1;
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      if( (needs_squash_restart & !should_drop) ) begin
        if( p_lane_idx_bits'(j) >= squash_restart_offset )
          alloc_ok_all &= alloc_ok[j];
        else
          alloc_ok_all &= 1'b1;
      end else begin
        alloc_ok_all &= alloc_ok[j];
      end
    end
  end

  // Accept memory responses when dropping stale data or when D is ready
  assign mem.resp_rdy = should_drop | (D_rdy_all & alloc_ok_all);

  // Per-lane response signals
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: RESP_LANE

      assign alloc_ok[i] = alloc_rdy[i] & alloc_val[i];

      always_comb begin
        if( (needs_squash_restart & !should_drop) ) begin
          D_inst_status[i] = (mem.resp_val & (i >= squash_restart_offset))
                             ? INST_STATUS_READY : INST_STATUS_INVALID;
          alloc_rdy[i]     = mem.resp_val & D_rdy[i] & (i >= squash_restart_offset);
          /* verilator lint_off CMPCONST */
          if( p_lane_idx_bits'(i) >= squash_restart_offset )
            D_val[i]        = mem.resp_val & alloc_ok[i];
          else
            D_val[i]        = mem.resp_val;
          /* verilator lint_on CMPCONST */
        end else begin
          D_inst_status[i] = (mem.resp_val & !should_drop)
                             ? INST_STATUS_READY : INST_STATUS_INVALID;
          alloc_rdy[i]     = mem.resp_val & D_rdy[i] & !should_drop;
          D_val[i]         = mem.resp_val & alloc_ok[i] & !should_drop;
        end
      end

      always_comb begin
        D_inst[i]    = mem.resp_msg.data[i*32 +: 32];
        D_pc[i]      = mem.resp_msg.addr + 32'(i << 2);
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

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  // seq num section width: p_num_fe_lanes * ceil_div_4(p_seq_num_bits) + (p_num_fe_lanes - 1) commas
  // total low trace width:  seq_num_width + 2 (": ") + 8 (addr)
  function string trace( int trace_level );
    int seq_w;
    int total_w;
    seq_w   = p_num_fe_lanes * ceil_div_4(p_seq_num_bits) + (p_num_fe_lanes - 1);
    total_w = seq_w + 2 + 8;

    if( trace_level > 0 ) begin
      if( memreq_xfer )
        trace = $sformatf("%h", mem.req_msg.addr);
      else
        trace = {8{" "}};

      trace = {trace, " > "};

      if( D_xfer_all ) begin
        trace = {trace, $sformatf("%h %s ", mem.resp_msg.addr,
                                  (should_drop ? "X" : " "))};
        for( int i = 0; i < p_num_fe_lanes; i++ ) begin
          if( i != 0 )
            trace = {trace, ","};
          if( D_xfer[i] )
            trace = {trace, $sformatf("%h", alloc_seq_num[i])};
          else
            trace = {trace, {(ceil_div_4(p_seq_num_bits)){" "}}};
        end
      end else
        trace = {trace, {(11 + seq_w){" "}}};
    end else begin
      if( D_xfer_all ) begin
        if( should_drop )
          trace = {(total_w){"X"}};
        else begin
          trace = "";
          for( int i = 0; i < p_num_fe_lanes; i++ ) begin
            if( i != 0 )
              trace = {trace, ","};
            trace = {trace, $sformatf("%h", alloc_seq_num[i])};
          end
          trace = {trace, $sformatf(": %h", mem.resp_msg.addr)};
        end
      end else
        trace = {(total_w){" "}};
    end
  endfunction

  function string trace_json();
    string seqs;
    seqs = "";

    trace_json = "{";

    // Memory request side
    trace_json = {trace_json, $sformatf("\"req_addr\":\"%h\"", mem.req_msg.addr)};
    trace_json = {trace_json, $sformatf(",\"req_val\":\"%b\"", mem.req_val)};
    trace_json = {trace_json, $sformatf(",\"req_rdy\":\"%b\"", mem.req_rdy)};

    // Memory response / D-side
    trace_json = {trace_json, $sformatf(",\"resp_addr\":\"%h\"", mem.resp_msg.addr)};
    trace_json = {trace_json, $sformatf(",\"resp_val\":\"%b\"", mem.resp_val)};
    trace_json = {trace_json, $sformatf(",\"resp_rdy\":\"%b\"", D_rdy_all)};

    // Sequence numbers (allocated this cycle, if D transfer occurs)
    if( D_xfer_all ) begin
      for( int i = 0; i < p_num_fe_lanes; i++ ) begin
        if( i != 0 )
          seqs = {seqs, ","};
        if( D_xfer[i] )
          seqs = {seqs, $sformatf("%h", alloc_seq_num[i])};
      end
      trace_json = {trace_json, $sformatf(",\"seqs\":\"%0s\"", seqs)};
    end else begin
      trace_json = {trace_json, ",\"seqs\":null"};
    end

    trace_json = {trace_json, $sformatf(",\"xfer\":\"%b\"", D_xfer_all)};
    trace_json = {trace_json, $sformatf(",\"squash\":%0s", (should_drop ? "true" : "false"))};
    trace_json = {trace_json, $sformatf(",\"in_flight\":\"%0d\"", num_in_flight)};
    trace_json = {trace_json, "}"};
  endfunction
`endif

endmodule

`endif // HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL5_V
