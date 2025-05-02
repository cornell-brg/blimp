//========================================================================
// ExQueue.v
//========================================================================
// A queue to buffer outputs of execute units

`ifndef HW_EXECUTE_EXQUEUE_V
`define HW_EXECUTE_EXQUEUE_V

`include "intf/X__WIntf.v"
`include "hw/common/Fifo.v"

module ExQueue #(
  parameter p_depth          = 8,
  parameter p_seq_num_bits   = 5,
  parameter p_phys_addr_bits = 6
)(
  input  logic clk,
  input  logic rst,

  X__WIntf.W_intf in,
  X__WIntf.X_intf out
);

  //----------------------------------------------------------------------
  // Define message type, connect to interfaces
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                 [31:0] pc;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
  } msg_t;

  msg_t in_msg;
  msg_t out_msg;

  assign in_msg.pc      = in.pc;
  assign in_msg.waddr   = in.waddr;
  assign in_msg.wdata   = in.wdata;
  assign in_msg.wen     = in.wen;
  assign in_msg.seq_num = in.seq_num;
  assign in_msg.preg    = in.preg;
  assign in_msg.ppreg   = in.ppreg;

  assign out.pc      = out_msg.pc;
  assign out.waddr   = out_msg.waddr;
  assign out.wdata   = out_msg.wdata;
  assign out.wen     = out_msg.wen;
  assign out.seq_num = out_msg.seq_num;
  assign out.preg    = out_msg.preg;
  assign out.ppreg   = out_msg.ppreg;

  //----------------------------------------------------------------------
  // Use a FIFO with bypassing to buffer the stream
  //----------------------------------------------------------------------

  logic buffer_push;
  logic buffer_pop;
  logic buffer_empty;
  logic buffer_full;
  msg_t buffer_out;

  Fifo #(
    .p_entry_bits ($bits(msg_t)),
    .p_depth      (p_depth)
  ) buffer (
    .clk   (clk),
    .rst   (rst),
    .push  (buffer_push),
    .pop   (buffer_pop),
    .empty (buffer_empty),
    .full  (buffer_full),
    .wdata (in_msg),
    .rdata (buffer_out)
  );

  logic can_bypass;
  assign can_bypass = buffer_empty;

  //----------------------------------------------------------------------
  // Pass messages
  //----------------------------------------------------------------------

  always_comb begin
    if( can_bypass )
      out_msg = in_msg;
    else
      out_msg = buffer_out;
  end

  //----------------------------------------------------------------------
  // Control signals
  //----------------------------------------------------------------------

  assign in.rdy  = !buffer_full  | out.rdy;
  assign out.val = !buffer_empty | ( buffer_empty & in.val );

  assign buffer_push = in.rdy & in.val & !( can_bypass & out.rdy );
  assign buffer_pop  = !buffer_empty & out.rdy;
endmodule

`endif // HW_EXECUTE_EXQUEUE_V
