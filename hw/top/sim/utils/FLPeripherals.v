//========================================================================
// FLPeripherals.v
//========================================================================
// A FL model of our memory-mapped peripherals

`include "fl/fl_peripherals.v"
`include "hw/util/DelayStream.v"
`include "intf/MemIntf.v"
`include "types/MemMsg.v"

`ifndef HW_TOP_SIM_UTILS_FLPERIPHERALS_V
`define HW_TOP_SIM_UTILS_FLPERIPHERALS_V

module FLPeripherals #(
  parameter p_opaq_bits     = 8,

  parameter p_send_intv_delay = 1,
  parameter p_recv_intv_delay = 1
)(
  input  logic clk,
  input  logic rst,
  
  MemNetReq.server  req,
  MemNetResp.server resp
);

  typedef struct packed {
    t_op                    op;
    logic [p_opaq_bits-1:0] opaque;
    logic [1:0]             origin;
    logic [31:0]            addr;
    logic [3:0]             strb;
    logic [31:0]            data;
  } mem_msg_t;

  //----------------------------------------------------------------------
  // Keep track of cycles since reset
  //----------------------------------------------------------------------

  localparam CYCLE_COUNT_ADDR = 32'hFFFFFF00;

  logic [31:0] cycle_count;

  always_ff @( posedge clk ) begin
    if( rst )
      cycle_count <= '0;
    else
      cycle_count <= cycle_count + 1;
  end

  //----------------------------------------------------------------------
  // Have queues for sending and receiving memory messages
  //----------------------------------------------------------------------

  // verilator lint_off PINCONNECTEMPTY
  
  DelayStream #(
    .t_msg             (mem_msg_t),
    .p_send_intv_delay (p_send_intv_delay)
  ) req_queue (
    .clk      (clk),
    .rst      (rst),

    .send_val (req.val),
    .send_rdy (req.rdy),
    .send_msg (req.msg),

    .recv_val (),
    .recv_rdy (1'b0),
    .recv_msg ()
  );

  DelayStream #(
    .t_msg             (mem_msg_t),
    .p_recv_intv_delay (p_recv_intv_delay)
  ) resp_queue (
    .clk      (clk),
    .rst      (rst),

    .send_val (1'b0),
    .send_rdy (),
    .send_msg ('x),

    .recv_val (resp.val),
    .recv_rdy (resp.rdy),
    .recv_msg (resp.msg)
  );

  // verilator lint_on PINCONNECTEMPTY

  //----------------------------------------------------------------------
  // Handle transactions
  //----------------------------------------------------------------------

  mem_msg_t    curr_req;
  mem_msg_t    curr_resp;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    if( req_queue.num_msgs() > 0 ) begin
      curr_req = req_queue.dequeue();

      // Execute the transaction
      case( curr_req.op )
        MEM_MSG_READ: begin
          if( try_fl_read(curr_req.addr, curr_resp.data) );
          else if( curr_req.addr  == CYCLE_COUNT_ADDR )
            curr_resp.data = cycle_count;
          else
            curr_resp.data = 'x;
          curr_resp.strb  = curr_req.strb;
        end
        MEM_MSG_WRITE: begin
          if( curr_req.strb == 4'b1111 ) begin
            // verilator lint_off IGNOREDRETURN
            try_fl_write(curr_req.addr, curr_req.data);
            // verilator lint_on IGNOREDRETURN
          end

          curr_resp.data = 'x;
          curr_resp.strb  = curr_req.strb;
        end
      endcase

      curr_resp.op     = curr_req.op;
      curr_resp.addr   = curr_req.addr;
      curr_resp.opaque = curr_req.opaque;
      curr_resp.origin = curr_req.origin;

      // Store the result to be sent back
      resp_queue.enqueue( curr_resp );
    end
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  function string trace(int trace_level);
    string req_linetrace, resp_linetrace;
    int str_len;

    str_len = 2 + 1 +                       // op
              ceil_div_4(p_opaq_bits) + 1 + // opaque
              8                       + 1 + // addr
              8;                            // data

    if( req.val & req.rdy ) begin
      case( req.msg.op )
        MEM_MSG_READ:  req_linetrace = "rd";
        MEM_MSG_WRITE: req_linetrace = "wr";
        default:       req_linetrace = "??";
      endcase

      if( trace_level > 0 ) begin
        req_linetrace = {req_linetrace, ":", $sformatf("%h:%h:%h", 
                         req.msg.opaque, req.msg.addr,
                         req.msg.data)};
      end
    end else begin
      if( trace_level > 0 )
        req_linetrace = {str_len{" "}};
      else
        req_linetrace = {2{" "}};
    end

    if( resp.val & resp.rdy ) begin
      case( resp.msg.op )
        MEM_MSG_READ:  resp_linetrace = "rd";
        MEM_MSG_WRITE: resp_linetrace = "wr";
        default:       resp_linetrace = "??";
      endcase

      if( trace_level > 0 ) begin
        resp_linetrace = {resp_linetrace, ":", $sformatf("%h:%h:%h", 
                         resp.msg.opaque, resp.msg.addr,
                         resp.msg.data)};
      end
    end else begin
      if( trace_level > 0 )
        resp_linetrace = {str_len{" "}};
      else
        resp_linetrace = {2{" "}};
    end

    trace = $sformatf("%s > %s", req_linetrace, resp_linetrace);
  endfunction

endmodule

`endif // TEST_FL_MEM_INTF_TEST_SERVER_V
