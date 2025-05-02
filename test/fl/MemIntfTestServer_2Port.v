//========================================================================
// MemIntfTestServer_2Port.v
//========================================================================
// A FL model of a memory server with two ports, to use in testing and
// simulation
//
// Here, we also include support for our FL memory-mapped peripherals

`include "fl/fl_peripherals.v"
`include "hw/util/DelayStream.v"
`include "intf/MemIntf.v"
`include "types/MemMsg.v"

`ifndef TEST_FL_MEM_INTF_TEST_SERVER_TWO_PORT_V
`define TEST_FL_MEM_INTF_TEST_SERVER_TWO_PORT_V

module MemIntfTestServer_2Port #(
  parameter type t_req_msg  = `MEM_REQ ( 8 ),
  parameter type t_resp_msg = `MEM_RESP( 8 ),
  parameter p_opaq_bits     = 8,

  parameter p_send_intv_delay = 1,
  parameter p_recv_intv_delay = 1
)(
  input  logic clk,
  input  logic rst,
  
  
  MemIntf.server dut [2]
);
  
  //----------------------------------------------------------------------
  // Store memory values in association array
  //----------------------------------------------------------------------

  logic [31:0] mem [logic [31:0]];

  always_ff @( posedge clk ) begin
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
  ) req_queue_0 (
    .clk      (clk),
    .rst      (rst),

    .send_val (dut[0].req_val),
    .send_rdy (dut[0].req_rdy),
    .send_msg (dut[0].req_msg),

    .recv_val (),
    .recv_rdy (1'b0),
    .recv_msg ()
  );

  DelayStream #(
    .t_msg             (t_resp_msg),
    .p_recv_intv_delay (p_recv_intv_delay)
  ) resp_queue_0 (
    .clk      (clk),
    .rst      (rst),

    .send_val (1'b0),
    .send_rdy (),
    .send_msg ('x),

    .recv_val (dut[0].resp_val),
    .recv_rdy (dut[0].resp_rdy),
    .recv_msg (dut[0].resp_msg)
  );

  DelayStream #(
    .t_msg             (t_req_msg),
    .p_send_intv_delay (p_send_intv_delay)
  ) req_queue_1 (
    .clk      (clk),
    .rst      (rst),

    .send_val (dut[1].req_val),
    .send_rdy (dut[1].req_rdy),
    .send_msg (dut[1].req_msg),

    .recv_val (),
    .recv_rdy (1'b0),
    .recv_msg ()
  );

  DelayStream #(
    .t_msg             (t_resp_msg),
    .p_recv_intv_delay (p_recv_intv_delay)
  ) resp_queue_1 (
    .clk      (clk),
    .rst      (rst),

    .send_val (1'b0),
    .send_rdy (),
    .send_msg ('x),

    .recv_val (dut[1].resp_val),
    .recv_rdy (dut[1].resp_rdy),
    .recv_msg (dut[1].resp_msg)
  );

  // verilator lint_on PINCONNECTEMPTY

  //----------------------------------------------------------------------
  // Handle transactions
  //----------------------------------------------------------------------

  t_req_msg    curr_req  [2];
  t_resp_msg   curr_resp [2];
  logic [31:0] _temp_write_data [2];

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    if( req_queue_0.num_msgs() > 0 ) begin
      curr_req[0] = req_queue_0.dequeue();

      // Execute the transaction
      case( curr_req[0].op )
        MEM_MSG_READ: begin
          if( try_fl_read(curr_req[0].addr, curr_resp[0].data) );
          else if( curr_req[0].addr  == CYCLE_COUNT_ADDR )
            curr_resp[0].data = cycle_count;
          else if( mem.exists( curr_req[0].addr ) == 1 )
            curr_resp[0].data = mem[curr_req[0].addr];
          else
            curr_resp[0].data = 'x;
          curr_resp[0].strb  = curr_req[0].strb;
        end
        MEM_MSG_WRITE: begin
          _temp_write_data[0] = mem[curr_req[0].addr];
          if( ( curr_req[0].strb & 4'b0001 ) > 0 )
            _temp_write_data[0][7:0] = curr_req[0].data[7:0];
          if( ( curr_req[0].strb & 4'b0010 ) > 0 )
            _temp_write_data[0][15:8] = curr_req[0].data[15:8];
          if( ( curr_req[0].strb & 4'b0100 ) > 0 )
            _temp_write_data[0][23:16] = curr_req[0].data[23:16];
          if( ( curr_req[0].strb & 4'b1000 ) > 0 )
            _temp_write_data[0][31:24] = curr_req[0].data[31:24];

          if( curr_req[0].strb == 4'b1111 ) begin
            if( try_fl_write(curr_req[0].addr, _temp_write_data[0]) );
            else
              mem[curr_req[0].addr] = _temp_write_data[0];
          end else begin
            mem[curr_req[0].addr] = _temp_write_data[0];
          end
          curr_resp[0].data = 'x;
          curr_resp[0].strb  = curr_req[0].strb;
        end
      endcase

      curr_resp[0].op     = curr_req[0].op;
      curr_resp[0].addr   = curr_req[0].addr;
      curr_resp[0].opaque = curr_req[0].opaque;

      // Store the result to be sent back
      resp_queue_0.enqueue( curr_resp[0] );
    end
  end

  always @( posedge clk ) begin
    if( req_queue_1.num_msgs() > 0 ) begin
      curr_req[1] = req_queue_1.dequeue();

      // Execute the transaction
      case( curr_req[1].op )
        MEM_MSG_READ: begin
          if( try_fl_read(curr_req[1].addr, curr_resp[1].data) );
          else if( curr_req[1].addr  == CYCLE_COUNT_ADDR )
            curr_resp[1].data = cycle_count;
          else if( mem.exists( curr_req[1].addr ) == 1 )
            curr_resp[1].data = mem[curr_req[1].addr];
          else
            curr_resp[1].data = 'x;
          curr_resp[1].strb  = curr_req[1].strb;
        end
        MEM_MSG_WRITE: begin
          _temp_write_data[1] = mem[curr_req[1].addr];
          if( ( curr_req[1].strb & 4'b0001 ) > 0 )
            _temp_write_data[1][7:0] = curr_req[1].data[7:0];
          if( ( curr_req[1].strb & 4'b0010 ) > 0 )
            _temp_write_data[1][15:8] = curr_req[1].data[15:8];
          if( ( curr_req[1].strb & 4'b0100 ) > 0 )
            _temp_write_data[1][23:16] = curr_req[1].data[23:16];
          if( ( curr_req[1].strb & 4'b1000 ) > 0 )
            _temp_write_data[1][31:24] = curr_req[1].data[31:24];

          if( curr_req[1].strb == 4'b1111 ) begin
            if( try_fl_write(curr_req[1].addr, _temp_write_data[1]) );
            else
              mem[curr_req[1].addr] = _temp_write_data[1];
          end else begin
            mem[curr_req[1].addr] = _temp_write_data[1];
          end
          curr_resp[0].data = 'x;
          curr_resp[0].strb  = curr_req[0].strb;
        end
      endcase

      curr_resp[1].op     = curr_req[1].op;
      curr_resp[1].addr   = curr_req[1].addr;
      curr_resp[1].opaque = curr_req[1].opaque;

      // Store the result to be sent back
      resp_queue_1.enqueue( curr_resp[1] );
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

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Port 0
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    if( dut[0].req_val & dut[0].req_rdy ) begin
      case( dut[0].req_msg.op )
        MEM_MSG_READ:  req_linetrace = "rd";
        MEM_MSG_WRITE: req_linetrace = "wr";
        default:       req_linetrace = "??";
      endcase

      if( trace_level > 0 ) begin
        req_linetrace = {req_linetrace, ":", $sformatf("%h:%h:%h", 
                         dut[0].req_msg.opaque, dut[0].req_msg.addr,
                         dut[0].req_msg.data)};
      end
    end else begin
      if( trace_level > 0 )
        req_linetrace = {str_len{" "}};
      else
        req_linetrace = {2{" "}};
    end

    if( dut[0].resp_val & dut[0].resp_rdy ) begin
      case( dut[0].resp_msg.op )
        MEM_MSG_READ:  resp_linetrace = "rd";
        MEM_MSG_WRITE: resp_linetrace = "wr";
        default:       resp_linetrace = "??";
      endcase

      if( trace_level > 0 ) begin
        resp_linetrace = {resp_linetrace, ":", $sformatf("%h:%h:%h", 
                         dut[0].resp_msg.opaque, dut[0].resp_msg.addr,
                         dut[0].resp_msg.data)};
      end
    end else begin
      if( trace_level > 0 )
        resp_linetrace = {str_len{" "}};
      else
        resp_linetrace = {2{" "}};
    end

    trace = $sformatf("%s > %s", req_linetrace, resp_linetrace);

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Port 1
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    if( dut[1].req_val & dut[1].req_rdy ) begin
      case( dut[1].req_msg.op )
        MEM_MSG_READ:  req_linetrace = "rd";
        MEM_MSG_WRITE: req_linetrace = "wr";
        default:       req_linetrace = "??";
      endcase

      if( trace_level > 0 ) begin
        req_linetrace = {req_linetrace, ":", $sformatf("%h:%h:%h", 
                         dut[1].req_msg.opaque, dut[1].req_msg.addr,
                         dut[1].req_msg.data)};
      end
    end else begin
      if( trace_level > 0 )
        req_linetrace = {str_len{" "}};
      else
        req_linetrace = {2{" "}};
    end

    if( dut[1].resp_val & dut[1].resp_rdy ) begin
      case( dut[1].resp_msg.op )
        MEM_MSG_READ:  resp_linetrace = "rd";
        MEM_MSG_WRITE: resp_linetrace = "wr";
        default:       resp_linetrace = "??";
      endcase

      if( trace_level > 0 ) begin
        resp_linetrace = {resp_linetrace, ":", $sformatf("%h:%h:%h", 
                         dut[1].resp_msg.opaque, dut[1].resp_msg.addr,
                         dut[1].resp_msg.data)};
      end
    end else begin
      if( trace_level > 0 )
        resp_linetrace = {str_len{" "}};
      else
        resp_linetrace = {2{" "}};
    end

    trace = {trace, $sformatf(" - %s > %s", req_linetrace, resp_linetrace)};
  endfunction

endmodule

`endif // TEST_FL_MEM_INTF_TEST_SERVER_TWO_PORT_V
