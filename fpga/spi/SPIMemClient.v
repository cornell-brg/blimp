// ==========================================================================
// SPIMemClient.v
// ==========================================================================
// A memory client for writing SPI data to memory

`ifndef FPGA_SPI_SPIMEMCLIENT_V
`define FPGA_SPI_SPIMEMCLIENT_V

`include "intf/MemIntf.v"
`include "fpga/spi/SPIMinion.v"

module SPIMemClient #(
  parameter p_opaq_bits = 8
)(
  input  logic clk,
  input  logic rst,

  input  logic cs,
  output logic miso,
  input  logic mosi,
  input  logic sclk,

  MemIntf.client mem,

  // Enable bit for our processor
  output logic go
);

  // ---------------------------------------------------------------------
  // Ignore responses (only writing)
  // ---------------------------------------------------------------------

  logic unused_resp;
  assign unused_resp = &{ mem.resp_val, mem.resp_msg };
  assign mem.resp_rdy = 1'b1;

  // ---------------------------------------------------------------------
  // Use SPIMinion to handle SPI transactions
  // ---------------------------------------------------------------------
  // No reading -> pull_msg is always 0

  logic [31:0] spi_push_msg;
  logic        spi_push_en;

  SPIMinion #(
    .nbits (32)
  ) minion (
    .clk   (clk),
    .reset (rst),

    // SPI Interface
    .cs   (cs),
    .mosi (mosi),
    .miso (miso),
    .sclk (sclk),

    // Push Interface
    .push_msg (spi_push_msg),
    .push_en  (spi_push_en),
    
    // Unused Pull Interface
    .pull_msg ('0),
    .pull_en  (),
    .parity   ()
  );

  // ---------------------------------------------------------------------
  // State Machine to handle transactions
  // ---------------------------------------------------------------------
  // Expect to receive address first, then data
  //
  // Due to the memory subsystem's speed compared to SPI, we don't have to
  // worry about backpressure

  localparam WAIT_ADDR = 2'd0;
  localparam WAIT_DATA = 2'd1;
  localparam WAIT_MEM  = 2'd2;
  localparam SET_GO    = 2'd3;

  localparam GO_ADDR   = 32'h00000000;

  logic [1:0] curr_state, next_state;

  always_ff @( posedge clk ) begin
    if( rst )
      curr_state <= WAIT_ADDR;
    else
      curr_state <= next_state;
  end

  logic [31:0] addr, data;

  always_comb begin
    next_state = curr_state;
    case( curr_state )
      WAIT_ADDR: if( spi_push_en ) next_state = WAIT_DATA;
      WAIT_DATA: begin
        if( spi_push_en ) begin
          if( addr == GO_ADDR )
            next_state = SET_GO;
          else
            next_state = WAIT_MEM;
        end
      end
      WAIT_MEM: if( mem.req_rdy ) next_state = WAIT_ADDR;
      SET_GO:                 next_state = WAIT_ADDR;
      default:                next_state = WAIT_ADDR;
    endcase
  end

  // ---------------------------------------------------------------------
  // Store Address and Data
  // ---------------------------------------------------------------------

  always_ff @( posedge clk ) begin
    if( rst )
      addr <= '0;
    else if( ( curr_state == WAIT_ADDR ) & spi_push_en )
      addr <= spi_push_msg;
  end

  always_ff @( posedge clk ) begin
    if( rst )
      data <= '0;
    else if( ( curr_state == WAIT_DATA ) & spi_push_en )
      data <= spi_push_msg;
  end

  // ---------------------------------------------------------------------
  // Enable bit for processor
  // ---------------------------------------------------------------------

  always_ff @( posedge clk ) begin
    if( rst )
      go <= 1'b1;
    else if( curr_state == SET_GO )
      go <= data[0];
  end

  // ---------------------------------------------------------------------
  // Memory request signsl
  // ---------------------------------------------------------------------

  assign mem.req_val        = ( curr_state == WAIT_MEM );
  assign mem.req_msg.op     = MEM_MSG_WRITE;
  assign mem.req_msg.opaque = 'x;
  assign mem.req_msg.addr   = addr;
  assign mem.req_msg.strb   = 4'b1111;
  assign mem.req_msg.data   = data;

endmodule

`endif // FPGA_SPI_SPIMEMCLIENT_V