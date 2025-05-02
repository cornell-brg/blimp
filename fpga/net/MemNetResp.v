//========================================================================
// MemNetReq.v
//========================================================================
// An interface for communicating a memory response in our network

`ifndef FPGA_NET_MEMNETRESP_V
`define FPGA_NET_MEMNETRESP_V

`include "intf/MemIntf.v"

interface MemNetResp #(
  parameter p_opaq_bits = 8
);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Message definitions
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  typedef struct packed {
    t_op                    op;
    logic [p_opaq_bits-1:0] opaque;
    logic [1:0]             origin;
    logic [31:0]            addr;
    logic [3:0]             strb;
    logic [31:0]            data;
  } mem_msg_t;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic      val;
  logic      rdy;
  mem_msg_t  msg;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Modports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  modport client (
    input  val,
    output rdy,
    input  msg
  );

  modport server (
    output val,
    input  rdy,
    output msg
  );

endinterface

`endif // FPGA_NET_MEMNETRESP_V