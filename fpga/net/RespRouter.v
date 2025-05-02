//========================================================================
// RespRouter.v
//========================================================================
// A module for routing a memory response by its origin

`ifndef FPGA_NET_RESPROUTER_V
`define FPGA_NET_RESPROUTER_V

`include "fpga/net/MemNetResp.v"

module RespRouter #(
  parameter p_num_route = 3
)(
  MemNetResp.client resp,
  MemNetResp.server route [p_num_route]
);

  // ---------------------------------------------------------------------
  // Route based on origin
  // ---------------------------------------------------------------------

  logic [p_num_route-1:0] route_rdy;

  genvar i;
  generate
    for( i = 0; i < p_num_route; i = i + 1 ) begin: ROUTE
      always_comb begin
        if( resp.msg.origin == 2'(i) ) begin
          route[i].val = resp.val;
          route_rdy[i] = route[i].rdy;
        end else begin
          route[i].val = 1'b0;
          route_rdy[i] = 1'b0;
        end

        route[i].msg = resp.msg;
      end
    end
  endgenerate

  assign resp.rdy = |route_rdy;
endmodule

`endif // FPGA_NET_RESPROUTER_V