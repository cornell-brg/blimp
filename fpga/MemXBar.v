//========================================================================
// MemXBar.v
//========================================================================
// A crossbar network for managing memory communication
//
// Currently, we expect 3 clients and 2 servers:
//  - Client:
//     - 0: Instruction Memory
//     - 1: Data Memory
//     - 2: SPI Flashing
//  - Server:
//     - M10K Memory
//     - Memory-Mapped Peripherals

`ifndef FPGA_MEMXBAR_V
`define FPGA_MEMXBAR_V

`include "fpga/net/MemNetReq.v"
`include "fpga/net/MemNetResp.v"
`include "fpga/net/ReqRouter.v"
`include "fpga/net/ReqArbiter.v"
`include "fpga/net/RespRouter.v"
`include "fpga/net/RespArbiter.v"
`include "intf/MemIntf.v"

module MemXBar #(
  parameter p_opaq_bits = 8
)(
  input  logic clk,
  input  logic rst,

  // ---------------------------------------------------------------------
  // Clients
  // ---------------------------------------------------------------------

  MemIntf.server imem,
  MemIntf.server dmem,
  MemIntf.server spi,

  // ---------------------------------------------------------------------
  // Servers
  // ---------------------------------------------------------------------

  MemNetReq.client  bram_req,
  MemNetResp.client bram_resp,

  MemNetReq.client  peripheral_req,
  MemNetResp.client peripheral_resp,

  // ---------------------------------------------------------------------
  // Go bit (pull low to disable imem transactions)
  // ---------------------------------------------------------------------

  input  logic go
);

  // ---------------------------------------------------------------------
  // Convert MemIntf to our network req/resp interfaces
  // ---------------------------------------------------------------------

  MemNetReq  #( p_opaq_bits ) imem_req();
  MemNetReq  #( p_opaq_bits ) dmem_req();
  MemNetReq  #( p_opaq_bits ) spi_req();
  MemNetResp #( p_opaq_bits ) imem_resp();
  MemNetResp #( p_opaq_bits ) dmem_resp();
  MemNetResp #( p_opaq_bits ) spi_resp();

  logic [1:0] unused_imem_resp_origin;
  logic [1:0] unused_dmem_resp_origin;
  logic [1:0] unused_spi_resp_origin;

  assign imem_req.val        = imem.req_val & go;
  assign imem.req_rdy        = imem_req.rdy & go;
  assign imem_req.msg.op     = imem.req_msg.op;
  assign imem_req.msg.opaque = imem.req_msg.opaque;
  assign imem_req.msg.addr   = imem.req_msg.addr;
  assign imem_req.msg.strb   = imem.req_msg.strb;
  assign imem_req.msg.data   = imem.req_msg.data;
  assign imem_req.msg.origin = 2'd0;

  assign dmem_req.val        = dmem.req_val;
  assign dmem.req_rdy        = dmem_req.rdy;
  assign dmem_req.msg.op     = dmem.req_msg.op;
  assign dmem_req.msg.opaque = dmem.req_msg.opaque;
  assign dmem_req.msg.addr   = dmem.req_msg.addr;
  assign dmem_req.msg.strb   = dmem.req_msg.strb;
  assign dmem_req.msg.data   = dmem.req_msg.data;
  assign dmem_req.msg.origin = 2'd1;

  assign spi_req.val        = spi.req_val;
  assign spi.req_rdy        = spi_req.rdy;
  assign spi_req.msg.op     = spi.req_msg.op;
  assign spi_req.msg.opaque = spi.req_msg.opaque;
  assign spi_req.msg.addr   = spi.req_msg.addr;
  assign spi_req.msg.strb   = spi.req_msg.strb;
  assign spi_req.msg.data   = spi.req_msg.data;
  assign spi_req.msg.origin = 2'd2;

  assign imem.resp_val           = imem_resp.val;
  assign imem_resp.rdy           = imem.resp_rdy;
  assign imem.resp_msg.op        = imem_resp.msg.op;
  assign imem.resp_msg.opaque    = imem_resp.msg.opaque;
  assign imem.resp_msg.addr      = imem_resp.msg.addr;
  assign imem.resp_msg.strb      = imem_resp.msg.strb;
  assign imem.resp_msg.data      = imem_resp.msg.data;
  assign unused_imem_resp_origin = imem_resp.msg.origin;

  assign dmem.resp_val           = dmem_resp.val;
  assign dmem_resp.rdy           = dmem.resp_rdy;
  assign dmem.resp_msg.op        = dmem_resp.msg.op;
  assign dmem.resp_msg.opaque    = dmem_resp.msg.opaque;
  assign dmem.resp_msg.addr      = dmem_resp.msg.addr;
  assign dmem.resp_msg.strb      = dmem_resp.msg.strb;
  assign dmem.resp_msg.data      = dmem_resp.msg.data;
  assign unused_dmem_resp_origin = dmem_resp.msg.origin;

  assign spi.resp_val           = spi_resp.val;
  assign spi_resp.rdy           = spi.resp_rdy;
  assign spi.resp_msg.op        = spi_resp.msg.op;
  assign spi.resp_msg.opaque    = spi_resp.msg.opaque;
  assign spi.resp_msg.addr      = spi_resp.msg.addr;
  assign spi.resp_msg.strb      = spi_resp.msg.strb;
  assign spi.resp_msg.data      = spi_resp.msg.data;
  assign unused_spi_resp_origin = spi_resp.msg.origin;

  // ---------------------------------------------------------------------
  // Request Routing
  // ---------------------------------------------------------------------

  MemNetReq #( p_opaq_bits ) bram_route_req[3]();
  MemNetReq #( p_opaq_bits ) peripheral_route_req[3]();

  ReqRouter imem_req_route (
    .req        (imem_req),
    .memory     (bram_route_req[0]),
    .peripheral (peripheral_route_req[0])
  );

  ReqRouter dmem_req_route (
    .req        (dmem_req),
    .memory     (bram_route_req[1]),
    .peripheral (peripheral_route_req[1])
  );

  ReqRouter spi_req_route (
    .req        (spi_req),
    .memory     (bram_route_req[2]),
    .peripheral (peripheral_route_req[2])
  );

  // ---------------------------------------------------------------------
  // Request Arbitration
  // ---------------------------------------------------------------------

  ReqArbiter #(
    .p_num_arb   (3),
    .p_opaq_bits (p_opaq_bits)
  ) bram_req_arb (
    .clk (clk),
    .rst (rst),
    .arb (bram_route_req),
    .gnt (bram_req)
  );

  ReqArbiter #(
    .p_num_arb   (3),
    .p_opaq_bits (p_opaq_bits)
  ) peripheral_req_arb (
    .clk (clk),
    .rst (rst),
    .arb (peripheral_route_req),
    .gnt (peripheral_req)
  );

  // ---------------------------------------------------------------------
  // Response Routing
  // ---------------------------------------------------------------------

  MemNetResp #( p_opaq_bits ) bram_route_resp[3]();
  MemNetResp #( p_opaq_bits ) peripheral_route_resp[3]();

  RespRouter #( 3 ) bram_resp_route (
    .resp  (bram_resp),
    .route (bram_route_resp)
  );

  RespRouter #( 3 ) peripheral_resp_route (
    .resp  (peripheral_resp),
    .route (peripheral_route_resp)
  );

  // ---------------------------------------------------------------------
  // Response Arbitration
  // ---------------------------------------------------------------------

  MemNetResp #( p_opaq_bits ) imem_route_resp[2]();
  MemNetResp #( p_opaq_bits ) dmem_route_resp[2]();
  MemNetResp #( p_opaq_bits ) spi_route_resp[2]();

  assign imem_route_resp[0].val = bram_route_resp[0].val;
  assign bram_route_resp[0].rdy = imem_route_resp[0].rdy;
  assign imem_route_resp[0].msg = bram_route_resp[0].msg;

  assign dmem_route_resp[0].val = bram_route_resp[1].val;
  assign bram_route_resp[1].rdy = dmem_route_resp[0].rdy;
  assign dmem_route_resp[0].msg = bram_route_resp[1].msg;

  assign spi_route_resp[0].val  = bram_route_resp[2].val;
  assign bram_route_resp[2].rdy = spi_route_resp[0].rdy;
  assign spi_route_resp[0].msg  = bram_route_resp[2].msg;

  assign imem_route_resp[1].val       = peripheral_route_resp[0].val;
  assign peripheral_route_resp[0].rdy = imem_route_resp[1].rdy;
  assign imem_route_resp[1].msg       = peripheral_route_resp[0].msg;

  assign dmem_route_resp[1].val       = peripheral_route_resp[1].val;
  assign peripheral_route_resp[1].rdy = dmem_route_resp[1].rdy;
  assign dmem_route_resp[1].msg       = peripheral_route_resp[1].msg;

  assign spi_route_resp[1].val        = peripheral_route_resp[2].val;
  assign peripheral_route_resp[2].rdy = spi_route_resp[1].rdy;
  assign spi_route_resp[1].msg        = peripheral_route_resp[2].msg;

  RespArbiter #(
    .p_num_arb   (2),
    .p_opaq_bits (p_opaq_bits)
  ) imem_resp_arb (
    .clk (clk),
    .rst (rst),
    .arb (imem_route_resp),
    .gnt (imem_resp)
  );

  RespArbiter #(
    .p_num_arb   (2),
    .p_opaq_bits (p_opaq_bits)
  ) dmem_resp_arb (
    .clk (clk),
    .rst (rst),
    .arb (dmem_route_resp),
    .gnt (dmem_resp)
  );

  RespArbiter #(
    .p_num_arb   (2),
    .p_opaq_bits (p_opaq_bits)
  ) spi_resp_arb (
    .clk (clk),
    .rst (rst),
    .arb (spi_route_resp),
    .gnt (spi_resp)
  );
endmodule

`endif // FPGA_MEMXBAR_V