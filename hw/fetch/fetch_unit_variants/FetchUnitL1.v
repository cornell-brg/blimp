//========================================================================
// FetchUnitL1.v
//========================================================================
// A basic modular fetch unit for fetching instructions

`ifndef HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL1_V
`define HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL1_V

`include "intf/F__DIntf.v"
`include "intf/MemIntf.v"

module FetchUnitL1 ( 
  input  logic    clk,
  input  logic    rst,

  //----------------------------------------------------------------------
  // Memory Interface
  //----------------------------------------------------------------------

  MemIntf.client  mem,

  //----------------------------------------------------------------------
  // F <-> D Interface
  //----------------------------------------------------------------------

  F__DIntf.F_intf D
);
  
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Local Parameters
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  localparam p_rst_addr = 32'h200;

  //----------------------------------------------------------------------
  // Request
  //----------------------------------------------------------------------

  logic               memreq_xfer;
  logic               memresp_xfer;

  always_comb begin
    memreq_xfer  = mem.req_val  & mem.req_rdy;
    memresp_xfer = mem.resp_val & mem.resp_rdy;
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

  always_comb begin
    mem.resp_rdy = D.rdy;
    D.val        = mem.resp_val;
    D.inst       = mem.resp_msg.data;
    D.pc         = mem.resp_msg.addr;
    D.seq_num    = 'x;
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Unused signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic       unused_resp_op;
  logic [3:0] unused_resp_strb;

  always_comb begin
    unused_resp_op   = mem.resp_msg.op;
    unused_resp_strb = mem.resp_msg.strb;
  end

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function string trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    if( memreq_xfer )
      trace = $sformatf("%h", mem.req_msg.addr);
    else
      trace = {8{" "}};

    trace = {trace, " > "};

    if( memresp_xfer )
      trace = {trace, $sformatf("%h", mem.resp_msg.addr)};
    else
      trace = {trace, {8{" "}}};
  endfunction
`endif

endmodule

`endif // HW_FETCH_FETCHUNITVARIANTS_FETCHUNITL1_V
