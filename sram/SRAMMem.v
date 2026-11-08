`ifndef SRAM_SRAMMEM_V
`define SRAM_SRAMMEM_V

`include "fpga/net/MemNetReq.v"
`include "fpga/net/MemNetResp.v"
`include "hw/common/Fifo.v"
`include "types/MemMsg.v"
`include "ip/sram/rtl/SRAM_generic.sv"

module SRAMMem #(
  parameter p_opaq_bits = 8,
  parameter p_num_entries = 256
)(
  input  logic clk,
  input  logic rst,

  MemNetReq.server  req,
  MemNetResp.server resp
);

  localparam c_addr_nbits = $clog2(p_num_entries);

  //----------------------------------------------------------------------
  // Use a FIFO to decouple incoming messages
  //----------------------------------------------------------------------

  typedef struct packed {
    t_op                    op;
    logic [p_opaq_bits-1:0] opaque;
    logic [1:0]             origin;
    logic [31:0]            addr;
    logic [3:0]             strb;
    logic [31:0]            data;
  } fifo_msg_t;

  logic fifo_push, fifo_pop, fifo_empty, fifo_full;
  fifo_msg_t fifo_wdata, fifo_rdata;

  Fifo #(
    .p_entry_bits (71 + p_opaq_bits),
    .p_depth      (4)
  ) req_fifo (
    .clk   (clk),
    .rst   (rst),
    .push  (fifo_push),
    .pop   (fifo_pop),
    .empty (fifo_empty),
    .full  (fifo_full),
    .wdata (fifo_wdata),
    .rdata (fifo_rdata)
  );

  assign fifo_push  = req.val;
  assign req.rdy    = !fifo_full;
  assign fifo_wdata = req.msg;

  //----------------------------------------------------------------------
  // Pipeline: REQ -> READ/WRITE -> SRAM_WAIT -> RESP
  // Need extra stage for SRAM read latency (synchronous SRAM)
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                   val;
    t_op                    op;
    logic [p_opaq_bits-1:0] opaque;
    logic [1:0]             origin;
    logic [31:0]            addr;
    logic [3:0]             strb;
    logic [31:0]            data;
  } pipe_msg_t;

  pipe_msg_t rw_msg, sram_msg, resp_msg;
  logic      rw_val, rw_rdy, sram_val, sram_rdy;

  logic  req_xfer, rw_xfer, sram_xfer, resp_xfer;
  assign req_xfer  = !fifo_empty & fifo_pop;
  assign rw_xfer   = rw_val & rw_rdy;
  assign sram_xfer = sram_val & sram_rdy;
  assign resp_xfer = resp.val & resp.rdy;
  
  assign rw_rdy = (sram_msg.val & sram_xfer) | !sram_msg.val;

  // verilator lint_off ENUMVALUE
  pipe_msg_t rw_msg_next, sram_msg_next, resp_msg_next;
  always_ff @( posedge clk ) begin
    if ( rst )
      rw_msg <= '{ 
        val:     1'b0, 
        op:     'x,
        opaque: 'x,
        origin: 'x,
        addr:   'x,
        strb:   'x,
        data:   'x
      };
    else
      rw_msg <= rw_msg_next;
    if ( rst )
      sram_msg <= '{ 
        val:     1'b0, 
        op:     'x,
        opaque: 'x,
        origin: 'x,
        addr:   'x,
        strb:   'x,
        data:   'x
      };
    else
      sram_msg <= sram_msg_next;
    if ( rst )
      resp_msg <= '{ 
        val:     1'b0, 
        op:     'x,
        opaque: 'x,
        origin: 'x,
        addr:   'x,
        strb:   'x,
        data:   'x
      };
    else
      resp_msg <= resp_msg_next;
  end

  logic [31:0] rdata;

  always_comb begin
    rw_msg_next = rw_msg;
    if( req_xfer )
      rw_msg_next = '{
        val: 1'b1,
        op:     fifo_rdata.op,
        opaque: fifo_rdata.opaque,
        origin: fifo_rdata.origin,
        addr:   fifo_rdata.addr,
        strb:   fifo_rdata.strb,
        data:   fifo_rdata.data
      };
    else if( rw_xfer )
      rw_msg_next = '{ 
        val:     1'b0, 
        op:     'x,
        opaque: 'x,
        origin: 'x,
        addr:   'x,
        strb:   'x,
        data:   'x
      };
  end

  always_comb begin
    sram_msg_next = sram_msg;
    if( rw_xfer )
      sram_msg_next = '{
        val:    1'b1,
        op:     rw_msg.op,
        opaque: rw_msg.opaque,
        origin: rw_msg.origin,
        addr:   rw_msg.addr,
        strb:   rw_msg.strb,
        data:   rw_msg.data  // Pass through write data
      };
    else if( sram_xfer )
      sram_msg_next = '{ 
        val:     1'b0, 
        op:     'x,
        opaque: 'x,
        origin: 'x,
        addr:   'x,
        strb:   'x,
        data:   'x
      };
  end

  always_comb begin
    resp_msg_next = resp_msg;
    if( sram_xfer )
      resp_msg_next = '{
        val:    1'b1,
        op:     sram_msg.op,
        opaque: sram_msg.opaque,
        origin: sram_msg.origin,
        addr:   sram_msg.addr,
        strb:   sram_msg.strb,
        data:   rdata  // Now SRAM output is valid
      };
    else if( resp_xfer )
      resp_msg_next = '{ 
        val:     1'b0, 
        op:     'x,
        opaque: 'x,
        origin: 'x,
        addr:   'x,
        strb:   'x,
        data:   'x
      };
  end
  // verilator lint_on ENUMVALUE

  assign resp.msg.op     = resp_msg.op;
  assign resp.msg.opaque = resp_msg.opaque;
  assign resp.msg.origin = resp_msg.origin;
  assign resp.msg.addr   = resp_msg.addr;
  assign resp.msg.strb   = resp_msg.strb;
  assign resp.msg.data   = resp_msg.data;

  //----------------------------------------------------------------------
  // SRAM instantiation
  //----------------------------------------------------------------------

  logic                    sram_port0_val;
  logic                    sram_port0_type;
  logic [c_addr_nbits-1:0] sram_port0_idx;
  logic [3:0]              sram_port0_wben;
  logic [31:0]             sram_port0_wdata;
  logic [31:0]             sram_port0_rdata;

  sram_SRAM_generic #(
    .p_data_nbits  (32),
    .p_num_entries (p_num_entries)
  ) sram (
    .CLK (clk),
    .WEN (sram_port0_type ? ~sram_port0_wben : 4'hF),
    .CEN (~sram_port0_val),
    .A   (sram_port0_idx),
    .D   (sram_port0_wdata),
    .Q   (sram_port0_rdata),
    .OEN (1'b0)
  );

  //----------------------------------------------------------------------
  // Memory Signals
  //----------------------------------------------------------------------

  logic we;
  assign we = rw_msg.val & ( rw_msg.op == MEM_MSG_WRITE );

  assign rdata = sram_port0_rdata;
  assign sram_port0_wdata = rw_msg.data;
  assign sram_port0_wben  = rw_msg.strb;
  assign sram_port0_type  = we;
  assign sram_port0_val   = rw_msg.val;

  logic [c_addr_nbits-1:0] mem_addr;
  assign mem_addr = rw_msg.addr[c_addr_nbits+1:2]; // Word address

  assign sram_port0_idx = mem_addr;

  //----------------------------------------------------------------------
  // Control Signals
  //----------------------------------------------------------------------

  assign resp.val = resp_msg.val;
  assign rw_val = rw_msg.val;
  assign sram_val = sram_msg.val;

  // Break combinational loop - currently inserts a bubble
  assign sram_rdy = ( resp_msg.val & resp_xfer ) | !resp_msg.val;

  assign fifo_pop = (( rw_msg.val & rw_xfer ) | !rw_msg.val) & !fifo_empty;

  //----------------------------------------------------------------------
  // Backdoor initialization for DPI compatibility
  //----------------------------------------------------------------------

  function void init_mem(
    input logic [31:0] addr,
    input logic [31:0] data
  );
    // Direct memory access (no timing controls, DPI-compatible)
    sram.mem[addr[c_addr_nbits+1:2]] = data;
  endfunction

endmodule

`endif