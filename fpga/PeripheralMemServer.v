// ==========================================================================
// PeripheralMemServer.v
// ==========================================================================
// A memory-mapped memory server for communicating with the PS2 Keyboard and
// VGA Display

`ifndef FPGA_PERIPHERALMEMSERVER_V
`define FPGA_PERIPHERALMEMSERVER_V

`include "fpga/net/MemNetReq.v"
`include "fpga/net/MemNetResp.v"
`include "fpga/ps2/Keyboard.v"
`include "fpga/ps2/ScanCodeFilter.v"
`include "fpga/vga/CharDisplay.v"
`include "hw/common/Fifo.v"

module PeripheralMemServer #(
  parameter p_opaq_bits     = 8,
  parameter p_key_buf_depth = 8
)(
  input  logic clk,
  input  logic rst,

  // ---------------------------------------------------------------------
  // Memory Interface
  // ---------------------------------------------------------------------

  MemNetReq.server  req,
  MemNetResp.server resp,

  // ---------------------------------------------------------------------
  // PS2 Interface
  // ---------------------------------------------------------------------

  input  logic PS2_CLK,
  input  logic PS2_DATA,

  // ---------------------------------------------------------------------
  // VGA Interface
  // ---------------------------------------------------------------------

  output  logic [3:0] VGA_R,
  output  logic [3:0] VGA_G,
  output  logic [3:0] VGA_B,
  output  logic       VGA_HS,
  output  logic       VGA_VS,
  output  logic       VGA_BLANK_N,
  output  logic       VGA_SYNC_N
);

  // ---------------------------------------------------------------------
  // VGA Display
  // ---------------------------------------------------------------------

  logic [7:0] vga_ascii;
  logic       vga_ascii_val;

  CharDisplay #(
    .p_num_rows (30),
    .p_num_cols (80)
  ) vga_display (
    .clk_25M   (clk),
    .rst       (rst),
    .ascii     (vga_ascii),
    .ascii_val (vga_ascii_val),
    .*
  );

  // ---------------------------------------------------------------------
  // PS2 Keyboard
  // ---------------------------------------------------------------------

  logic [7:0] scan_code;
  logic       scan_code_val;

  Keyboard keyboard (
    .*
  );

  logic [7:0] ps2_ascii;
  logic       ps2_ascii_val;

  ScanCodeFilter ps2_filter (
    .ascii     (ps2_ascii),
    .ascii_val (ps2_ascii_val),
    .*
  );

  // Store key presses in a FIFO buffer
  logic       key_buf_push;
  logic       key_buf_pop;
  logic       key_buf_empty;
  logic       key_buf_full;
  logic [7:0] key_buf_wdata;
  logic [7:0] key_buf_rdata;

  Fifo #(
    .p_entry_bits (8),
    .p_depth      (p_key_buf_depth)
  ) key_buf (
    .clk   (clk),
    .rst   (rst),
    .push  (key_buf_push),
    .pop   (key_buf_pop),
    .empty (key_buf_empty),
    .full  (key_buf_full),
    .wdata (key_buf_wdata),
    .rdata (key_buf_rdata)
  );

  assign key_buf_wdata = ps2_ascii;
  assign key_buf_push  = ps2_ascii_val & ~key_buf_full;

  // ---------------------------------------------------------------------
  // State Machine for accesses
  // ---------------------------------------------------------------------
  // Not pipelined, only because peripheral accesses are likely infrequent

  localparam IDLE    = 2'd0;
  localparam OPERATE = 2'd1;
  localparam RESP    = 2'd2;

  logic [1:0] curr_state, next_state;

  always_ff @( posedge clk ) begin
    if( rst )
      curr_state <= IDLE;
    else
      curr_state <= next_state;
  end

  logic op_done;
  always_comb begin
    next_state = curr_state;
    case( curr_state )
      IDLE:    if( req.val ) next_state = OPERATE;
      OPERATE: if( op_done ) next_state = RESP;
      RESP: begin
        if( resp.rdy ) begin
          if( req.val ) next_state = OPERATE;
          else          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // ---------------------------------------------------------------------
  // Handle memory messages
  // ---------------------------------------------------------------------

  typedef struct packed {
    t_op                    op;
    logic [p_opaq_bits-1:0] opaque;
    logic [1:0]             origin;
    logic [31:0]            addr;
    logic [3:0]             strb;
    logic [31:0]            data;
  } peripheral_msg_t;

  peripheral_msg_t curr_msg;
  always_ff @( posedge clk ) begin
    if( rst )
      curr_msg <= '0;
    else if(
      ( curr_state != OPERATE ) &
      ( next_state == OPERATE )
    ) // New transaction
      curr_msg <= '{
        op:     req.msg.op,
        opaque: req.msg.opaque,
        origin: req.msg.origin,
        addr:   req.msg.addr,
        strb:   req.msg.strb,
        data:   req.msg.data
      };
  end

  logic [31:0] rdata;
  assign resp.msg.op     = curr_msg.op;
  assign resp.msg.opaque = curr_msg.opaque;
  assign resp.msg.origin = curr_msg.origin;
  assign resp.msg.addr   = curr_msg.addr;
  assign resp.msg.strb   = curr_msg.strb;
  assign resp.msg.data   = rdata;

  // ---------------------------------------------------------------------
  // Assign read data and op_done based on peripheral being accessed
  // ---------------------------------------------------------------------

  localparam STDOUT = 32'hF0000000;
  localparam STDIN  = 32'hF0000004;

  logic [31:0] rdata_next;
  always_ff @( posedge clk ) begin
    if( rst )
      rdata <= '0;
    else if( curr_state == OPERATE )
      rdata <= rdata_next;
  end

  always_comb begin
    case( curr_msg.addr )
      STDOUT:  rdata_next = 'x;
      STDIN:   rdata_next = { 24'b0, key_buf_rdata };
      default: rdata_next = 'x;
    endcase
  end

  always_comb begin
    case( curr_msg.addr )
      STDOUT:  op_done = !ps2_ascii_val;
      STDIN:   op_done = !key_buf_empty;
      default: op_done = 1'b1;
    endcase
  end

  // ---------------------------------------------------------------------
  // Operate on peripherals as appropriate
  // ---------------------------------------------------------------------

  always_comb begin
    if( ps2_ascii_val )
      vga_ascii = ps2_ascii;
    else
      vga_ascii = curr_msg.data[7:0];
  end
  assign vga_ascii_val = ( ( next_state == RESP )
                         & ( curr_msg.addr == STDOUT ) )
                         | ps2_ascii_val;

  assign key_buf_pop = ( next_state == RESP )
                     & ( curr_msg.addr == STDIN );

  // ---------------------------------------------------------------------
  // Remaining control signals
  // ---------------------------------------------------------------------

  assign req.rdy = ( curr_state == IDLE ) |
                   (( curr_state == RESP & resp.rdy ));
  assign resp.val = ( curr_state == RESP );
endmodule

`endif // FPGA_PERIPHERALMEMSERVER_V