//========================================================================
// MemIntfTestServer.v
//========================================================================
// A FL model of a memory server, to use in testing

`include "hw/util/DelayStream.v"
`include "intf/MemIntf.v"
`include "test/FLTestUtils.v"
`include "types/MemMsg.v"

`ifndef TEST_FL_MEM_INTF_TEST_SERVER_V
`define TEST_FL_MEM_INTF_TEST_SERVER_V

module MemIntfTestServer #(
  parameter type t_req_msg  = `MEM_REQ ( 8 ),
  parameter type t_resp_msg = `MEM_RESP( 8 ),
  parameter p_opaq_bits     = 8,

  parameter p_send_intv_delay = 1,
  parameter p_recv_intv_delay = 1
)(
  input  logic clk,
  input  logic rst,
  
  
  MemIntf.server dut
);

  FLTestUtils t( .* );
  
  //----------------------------------------------------------------------
  // Store memory values in association array
  //----------------------------------------------------------------------

  logic [31:0] mem [logic [31:0]];

  always @( posedge clk ) begin
    if( rst )
      mem.delete();
  end

  task init_mem(
    input logic [31:0] addr,
    input logic [31:0] data
  );
    mem[addr] = data;
  endtask

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
    .t_msg             (t_req_msg),
    .p_send_intv_delay (p_send_intv_delay)
  ) req_queue (
    .clk      (clk),
    .rst      (rst),

    .send_val (dut.req_val),
    .send_rdy (dut.req_rdy),
    .send_msg (dut.req_msg),

    .recv_val (),
    .recv_rdy (1'b0),
    .recv_msg ()
  );

  DelayStream #(
    .t_msg             (t_resp_msg),
    .p_recv_intv_delay (p_recv_intv_delay)
  ) resp_queue (
    .clk      (clk),
    .rst      (rst),

    .send_val (1'b0),
    .send_rdy (),
    .send_msg ('x),

    .recv_val (dut.resp_val),
    .recv_rdy (dut.resp_rdy),
    .recv_msg (dut.resp_msg)
  );

  // verilator lint_on PINCONNECTEMPTY

  //----------------------------------------------------------------------
  // Handle transactions
  //----------------------------------------------------------------------

  t_req_msg    curr_req;
  t_resp_msg   curr_resp;
  logic [31:0] _temp_write_data;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    if( req_queue.num_msgs() > 0 ) begin
      curr_req = req_queue.dequeue();

      // Execute the transaction
      case( curr_req.op )
        MEM_MSG_READ: begin
          if( curr_req.addr  == CYCLE_COUNT_ADDR )
            curr_resp.data = cycle_count;
          else if( mem.exists( curr_req.addr ) == 1 )
            curr_resp.data = mem[curr_req.addr];
          else
            curr_resp.data = 'x;
          curr_resp.strb  = curr_req.strb;
        end
        MEM_MSG_WRITE: begin
          _temp_write_data = mem[curr_req.addr];
          if( ( curr_req.strb & 4'b0001 ) > 0 )
            _temp_write_data[7:0] = curr_req.data[7:0];
          if( ( curr_req.strb & 4'b0010 ) > 0 )
            _temp_write_data[15:8] = curr_req.data[15:8];
          if( ( curr_req.strb & 4'b0100 ) > 0 )
            _temp_write_data[23:16] = curr_req.data[23:16];
          if( ( curr_req.strb & 4'b1000 ) > 0 )
            _temp_write_data[31:24] = curr_req.data[31:24];

          mem[curr_req.addr] = _temp_write_data;
          curr_resp.data = 'x;
          curr_resp.strb  = curr_req.strb;
        end
      endcase

      curr_resp.op     = curr_req.op;
      curr_resp.addr   = curr_req.addr;
      curr_resp.opaque = curr_req.opaque;

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

    if( dut.req_val & dut.req_rdy ) begin
      case( dut.req_msg.op )
        MEM_MSG_READ:  req_linetrace = "rd";
        MEM_MSG_WRITE: req_linetrace = "wr";
        default:       req_linetrace = "??";
      endcase

      if( trace_level > 0 ) begin
        req_linetrace = {req_linetrace, ":", $sformatf("%h:%h:%h", 
                         dut.req_msg.opaque, dut.req_msg.addr,
                         dut.req_msg.data)};
      end
    end else begin
      if( trace_level > 0 )
        req_linetrace = {str_len{" "}};
      else
        req_linetrace = {2{" "}};
    end

    if( dut.resp_val & dut.resp_rdy ) begin
      case( dut.resp_msg.op )
        MEM_MSG_READ:  resp_linetrace = "rd";
        MEM_MSG_WRITE: resp_linetrace = "wr";
        default:       resp_linetrace = "??";
      endcase

      if( trace_level > 0 ) begin
        resp_linetrace = {resp_linetrace, ":", $sformatf("%h:%h:%h", 
                         dut.resp_msg.opaque, dut.resp_msg.addr,
                         dut.resp_msg.data)};
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
