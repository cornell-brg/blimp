//========================================================================
// FetchUnitL2.v
//========================================================================
// A modular fetch unit for fetching instructions with sequence numbers

`ifndef HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL2_V
`define HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL2_V

`include "hw/common/Fifo.v"
`include "hw/fetch/SeqNumGenL2.v"
`include "intf/CommitNotif.v"
`include "intf/F__DIntf.v"
`include "intf/MemIntf.v"

module FetchUnitL2
#(
  parameter p_reclaim_width = 2
)
( 
  input  logic    clk,
  input  logic    rst,

  //----------------------------------------------------------------------
  // Memory Interface
  //----------------------------------------------------------------------

  MemIntf.client  mem,

  //----------------------------------------------------------------------
  // F <-> D Interface
  //----------------------------------------------------------------------

  F__DIntf.F_intf D,

  //----------------------------------------------------------------------
  // Commit Interface
  //----------------------------------------------------------------------

  CommitNotif.sub commit
);
  
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Local Parameters
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  localparam p_rst_addr     = 32'h200;
  localparam p_seq_num_bits = D.p_seq_num_bits;

  //----------------------------------------------------------------------
  // Request
  //----------------------------------------------------------------------

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the number of in-flight requests
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic               memreq_xfer;
  logic               D_xfer;

  always_comb begin
    memreq_xfer  = mem.req_val  & mem.req_rdy;
    D_xfer       = D.val        & D.rdy;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Keep track of the current request address
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic [31:0] curr_addr;
  logic [31:0] curr_addr_next;

  always_ff @( posedge clk ) begin
    if ( rst )
      curr_addr <= 32'(p_rst_addr);
    else if ( memreq_xfer )
      curr_addr <= curr_addr_next;
  end

  always_comb begin
    curr_addr_next = mem.req_msg.addr + 4;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Determine the correct address to send out
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  always_comb begin
    mem.req_msg.addr = curr_addr;
  end

  always_comb begin
    mem.req_val        = 1'b1;
    mem.req_msg.op     = MEM_MSG_READ;
    mem.req_msg.opaque = '0;
    mem.req_msg.strb   = '0;
    mem.req_msg.data   = 'x;
  end

  //----------------------------------------------------------------------
  // Response
  //----------------------------------------------------------------------

  typedef struct packed {
    t_op                    op;
    logic [31:0]            addr;
    logic [3:0]             strb;
    logic [31:0]            data;
  } mem_msg_t;

  logic resp_push, resp_pop, resp_empty, resp_full;
  mem_msg_t fifo_rdata, fifo_wdata;

  logic                      alloc_val;
  logic [p_seq_num_bits-1:0] alloc_seq_num;

  Fifo #(
    .p_entry_bits ($bits(mem_msg_t)),
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

  assign fifo_wdata.op   = mem.resp_msg.op;
  assign fifo_wdata.addr = mem.resp_msg.addr;
  assign fifo_wdata.strb = mem.resp_msg.strb;
  assign fifo_wdata.data = mem.resp_msg.data;

  assign resp_push    = mem.resp_val & !resp_full;
  assign mem.resp_rdy = !resp_full;
  assign resp_pop     = D.rdy & alloc_val & !resp_empty;

  always_comb begin
    D.val        = !resp_empty & alloc_val;
    D.inst       = fifo_rdata.data;
    D.pc         = fifo_rdata.addr;
    D.seq_num    = alloc_seq_num;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Allocate sequence numbers
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic alloc_rdy;
  assign alloc_rdy = D.rdy & !resp_empty;

  SeqNumGenL2 #(
    .p_seq_num_bits  (p_seq_num_bits),
    .p_reclaim_width (p_reclaim_width)
  ) seq_num_gen (
    .*
  );

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Unused signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic       unused_resp_op;
  logic [3:0] unused_resp_strb;

  always_comb begin
    unused_resp_op   = fifo_rdata.op;
    unused_resp_strb = fifo_rdata.strb;
  end

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  function string trace( int trace_level );
    if( trace_level > 0 ) begin
      if( memreq_xfer )
        trace = $sformatf("%h", mem.req_msg.addr);
      else
        trace = {8{" "}};

      trace = {trace, " > "};

      if( D_xfer )
        trace = {trace, $sformatf("%h (%h)", mem.resp_msg.addr, alloc_seq_num)};
      else
        trace = {trace, {(11 + ceil_div_4(p_seq_num_bits)){" "}}};
    end else begin
      if( D_xfer )
        trace = $sformatf("%h: %h", alloc_seq_num, mem.resp_msg.addr);
      else
        trace = {(ceil_div_4(p_seq_num_bits) + 2 + 8){" "}};
    end
  endfunction
`endif

endmodule

`endif // HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL2_V
