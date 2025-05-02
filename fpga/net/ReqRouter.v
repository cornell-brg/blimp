//========================================================================
// ReqRouter.v
//========================================================================
// A module for routing a memory request
//
// Currently, we only support two ports for routing to a peripheral or
// not. Future implementations might parametrize the number of ports to
// route to

`ifndef FPGA_NET_REQROUTER_V
`define FPGA_NET_REQROUTER_V

`include "fpga/net/MemNetReq.v"

module ReqRouter (
  MemNetReq.server req,

  MemNetReq.client memory,
  MemNetReq.client peripheral
);

  // ---------------------------------------------------------------------
  // Send to the peripheral if the address is 0xFXXXXXXX
  // ---------------------------------------------------------------------

  always_comb begin
    memory.msg     = req.msg;
    peripheral.msg = req.msg;
    memory.val     = 1'b0;
    peripheral.val = 1'b0;

    if( req.msg.addr[31:28] == 4'hF ) begin
      // Send to the peripheral
      peripheral.val = req.val;
      req.rdy        = peripheral.rdy;
    end else begin
      // Send to memory
      memory.val = req.val;
      req.rdy    = memory.rdy;
    end
  end
endmodule

`endif // FPGA_NET_REQROUTER_V