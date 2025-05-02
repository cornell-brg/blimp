//========================================================================
// MemIntf.v
//========================================================================
// A paremetrized interface for communicating with memory

`ifndef INTF_MEM_IFC_V
`define INTF_MEM_IFC_V

`include "types/MemMsg.v"

interface MemIntf
#(
  parameter p_opaq_bits = 8
);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Message definitions
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  typedef struct packed {
    t_op                    op;
    logic [p_opaq_bits-1:0] opaque;
    logic [31:0]            addr;
    logic [3:0]             strb;
    logic [31:0]            data;
  } mem_msg_t;
  
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  logic      req_val;
  logic      req_rdy;
  mem_msg_t  req_msg;

  logic      resp_val;
  logic      resp_rdy;
  mem_msg_t  resp_msg;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Modports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  modport client (
    output req_val,
    input  req_rdy,
    output req_msg,

    input  resp_val,
    output resp_rdy,
    input  resp_msg
  );

  modport server (
    input  req_val,
    output req_rdy,
    input  req_msg,

    output resp_val,
    input  resp_rdy,
    output resp_msg
  );

endinterface

`endif // INTF_MEM_INTF_V
