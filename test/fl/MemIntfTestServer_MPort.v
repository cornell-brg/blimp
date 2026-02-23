//========================================================================
// MemIntfTestServer_MPort.v
//========================================================================
// A FL model of a memory server with M ports, to use in testing and
// simulation
//
// Here, we also include support for our FL memory-mapped peripherals

`include "fl/fl_peripherals.v"
`include "hw/util/DelayStream.v"
`include "intf/MemIntf.v"
`include "types/MemMsg.v"

`ifndef TEST_FL_MEM_INTF_TEST_SERVER_M_PORT_V
`define TEST_FL_MEM_INTF_TEST_SERVER_M_PORT_V

module MemIntfTestServer_MPort #(
  parameter type t_req_msg  = `MEM_REQ ( 8 ),
  parameter type t_resp_msg = `MEM_RESP( 8 ),
  parameter p_num_ports     = 2,
  parameter p_opaq_bits     = 8,

  parameter p_send_intv_delay = 1,
  parameter p_recv_intv_delay = 1
)(
  input  logic clk,
  input  logic rst,
  
  
  MemIntf.server dut [p_num_ports]
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
  genvar i;
  generate
    for( i = 0; i < p_num_ports; i++ ) begin : INTF_QUEUES
      DelayStream #(
        .t_msg             (t_req_msg),
        .p_send_intv_delay (p_send_intv_delay)
      ) req_queue (
        .clk      (clk),
        .rst      (rst),

        .send_val (dut[i].req_val),
        .send_rdy (dut[i].req_rdy),
        .send_msg (dut[i].req_msg),

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

        .recv_val (dut[i].resp_val),
        .recv_rdy (dut[i].resp_rdy),
        .recv_msg (dut[i].resp_msg)
      );
    end
  endgenerate
  // verilator lint_on PINCONNECTEMPTY

  //----------------------------------------------------------------------
  // Handle transactions
  //----------------------------------------------------------------------

  t_req_msg    curr_req  [p_num_ports];
  t_resp_msg   curr_resp [p_num_ports];
  logic [31:0] _temp_write_data [p_num_ports];

  // verilator lint_off BLKSEQ
  generate
    for( i = 0; i < p_num_ports; i++ ) begin
      always @( posedge clk ) begin
        if( INTF_QUEUES[i].req_queue.num_msgs() > 0 ) begin
          curr_req[i] = INTF_QUEUES[i].req_queue.dequeue();

          // Execute the transaction
          case( curr_req[i].op )
            MEM_MSG_READ: begin
              if( try_fl_read(curr_req[i].addr, curr_resp[i].data) );
              else if( curr_req[i].addr  == CYCLE_COUNT_ADDR )
                curr_resp[i].data = cycle_count;
              else if( mem.exists( curr_req[i].addr ) == 1 )
                curr_resp[i].data = mem[curr_req[i].addr];
              else
                curr_resp[i].data = 'x;
              curr_resp[i].strb  = curr_req[i].strb;
            end
            MEM_MSG_WRITE: begin
              _temp_write_data[i] = mem[curr_req[i].addr];
              if( ( curr_req[i].strb & 4'b0001 ) > 0 )
                _temp_write_data[i][7:0] = curr_req[i].data[7:0];
              if( ( curr_req[i].strb & 4'b0010 ) > 0 )
                _temp_write_data[i][15:8] = curr_req[i].data[15:8];
              if( ( curr_req[i].strb & 4'b0100 ) > 0 )
                _temp_write_data[i][23:16] = curr_req[i].data[23:16];
              if( ( curr_req[i].strb & 4'b1000 ) > 0 )
                _temp_write_data[i][31:24] = curr_req[i].data[31:24];

              if( curr_req[i].strb == 4'b1111 ) begin
                if( try_fl_write(curr_req[i].addr, _temp_write_data[i]) );
                else
                  mem[curr_req[i].addr] = _temp_write_data[i];
              end else begin
                mem[curr_req[i].addr] = _temp_write_data[i];
              end
              curr_resp[i].data = 'x;
              curr_resp[i].strb  = curr_req[i].strb;
            end
          endcase

          curr_resp[i].op     = curr_req[i].op;
          curr_resp[i].addr   = curr_req[i].addr;
          curr_resp[i].opaque = curr_req[i].opaque;

          // Store the result to be sent back
          INTF_QUEUES[i].resp_queue.enqueue( curr_resp[i] );
        end
      end
    end
  endgenerate
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  // function int ceil_div_4( int val );
  //   return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  // endfunction

  // function string trace(int trace_level);
  //   string req_linetrace, resp_linetrace;
  //   int str_len;

  //   str_len = 2 + 1 +                       // op
  //             ceil_div_4(p_opaq_bits) + 1 + // opaque
  //             8                       + 1 + // addr
  //             8;                            // data

  //   trace = "";

  //   for( int p = 0; p < p_num_ports; p++ ) begin

  //     if( dut[p].req_val & dut[p].req_rdy ) begin
  //       case( dut[p].req_msg.op )
  //         MEM_MSG_READ:  req_linetrace = "rd";
  //         MEM_MSG_WRITE: req_linetrace = "wr";
  //         default:       req_linetrace = "??";
  //       endcase

  //       if( trace_level > 0 ) begin
  //         req_linetrace = {req_linetrace, ":", $sformatf("%h:%h:%h",
  //                          dut[p].req_msg.opaque, dut[p].req_msg.addr,
  //                          dut[p].req_msg.data)};
  //       end
  //     end else begin
  //       if( trace_level > 0 )
  //         req_linetrace = {str_len{" "}};
  //       else
  //         req_linetrace = {2{" "}};
  //     end

  //     if( dut[p].resp_val & dut[p].resp_rdy ) begin
  //       case( dut[p].resp_msg.op )
  //         MEM_MSG_READ:  resp_linetrace = "rd";
  //         MEM_MSG_WRITE: resp_linetrace = "wr";
  //         default:       resp_linetrace = "??";
  //       endcase

  //       if( trace_level > 0 ) begin
  //         resp_linetrace = {resp_linetrace, ":", $sformatf("%h:%h:%h",
  //                          dut[p].resp_msg.opaque, dut[p].resp_msg.addr,
  //                          dut[p].resp_msg.data)};
  //       end
  //     end else begin
  //       if( trace_level > 0 )
  //         resp_linetrace = {str_len{" "}};
  //       else
  //         resp_linetrace = {2{" "}};
  //     end

  //     if( p == 0 )
  //       trace = $sformatf("%s > %s", req_linetrace, resp_linetrace);
  //     else
  //       trace = {trace, $sformatf(" - %s > %s", req_linetrace, resp_linetrace)};

  //   end
  // endfunction

endmodule

`endif // TEST_FL_MEM_INTF_TEST_SERVER_M_PORT_V
