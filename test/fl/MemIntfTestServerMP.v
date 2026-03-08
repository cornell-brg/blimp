//========================================================================
// MemIntfTestServerMP.v
//========================================================================
// A multi-port FL model of a memory server, to use in testing.
// All ports share a single backing store so writes from one port are
// visible to reads from any other port.

`include "fl/fl_peripherals.v"
`include "intf/MemIntf.v"
`include "types/MemMsg.v"

`ifndef TEST_FL_MEM_INTF_TEST_SERVER_MP_V
`define TEST_FL_MEM_INTF_TEST_SERVER_MP_V

module MemIntfTestServerMP #(
  parameter type t_req_msg  = `MEM_REQ ( 8 ),
  parameter type t_resp_msg = `MEM_RESP( 8 ),
  parameter p_opaq_bits     = 8,
  parameter p_num_words     = 1,
  parameter p_num_ports     = 1,

  parameter p_send_intv_delay = 1,
  parameter p_recv_intv_delay = 1
)(
  input  logic clk,
  input  logic rst,

  MemIntf.server dut [p_num_ports]
);

  //----------------------------------------------------------------------
  // Store memory values in associative array (shared across all ports)
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
  // Per-port logic (inline queues to avoid Verilator generate scope issues)
  //----------------------------------------------------------------------

  // Extract interface signals into plain arrays for runtime indexing
  logic      port_req_val  [p_num_ports];
  logic      port_req_rdy  [p_num_ports];
  t_req_msg  port_req_msg  [p_num_ports];
  logic      port_resp_val [p_num_ports];
  logic      port_resp_rdy [p_num_ports];
  t_resp_msg port_resp_msg [p_num_ports];

  genvar i;
  generate
    for( i = 0; i < p_num_ports; i++ ) begin: PORT
      assign port_req_val[i]  = dut[i].req_val;
      assign port_req_rdy[i]  = dut[i].req_rdy;
      assign port_req_msg[i]  = dut[i].req_msg;
      assign port_resp_val[i] = dut[i].resp_val;
      assign port_resp_rdy[i] = dut[i].resp_rdy;
      assign port_resp_msg[i] = dut[i].resp_msg;

      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      // Request queue (inline)
      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      t_req_msg req_queue [$];
      int send_intv_delay;

      initial dut[i].req_rdy = 1'b0;

      always @( posedge clk ) begin
        if( send_intv_delay > 0 ) send_intv_delay <= send_intv_delay - 1;
      end

      always @( posedge clk ) begin
        if( rst ) begin
          req_queue.delete();
        end
      end

      always @( posedge clk ) begin
        #1;
        if( rst ) begin
          dut[i].req_rdy <= 1'b0;
        end
        else begin
          if( send_intv_delay == 0 ) begin
            dut[i].req_rdy <= 1'b1;
            #2;
            if( dut[i].req_val ) begin
              req_queue.push_back( dut[i].req_msg );
              send_intv_delay <= p_send_intv_delay;
            end
          end else begin
            dut[i].req_rdy <= 1'b0;
          end
        end
      end

      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      // Response queue (inline)
      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      t_resp_msg resp_queue [$];
      int recv_intv_delay;

      initial begin
        dut[i].resp_val = 1'b0;
        dut[i].resp_msg = 'x;
      end

      always @( posedge clk ) begin
        if( recv_intv_delay > 0 ) recv_intv_delay <= recv_intv_delay - 1;
      end

      always @( posedge clk ) begin
        if( rst ) begin
          resp_queue.delete();
        end
      end

      always @( posedge clk ) begin
        #1;
        if( rst ) begin
          dut[i].resp_val <= 1'b0;
          dut[i].resp_msg <= 'x;
        end
        else begin
          if( (recv_intv_delay == 0) & (resp_queue.size() > 0) ) begin
            dut[i].resp_val <= 1'b1;
            dut[i].resp_msg <= resp_queue[0];
            #2;
            if( dut[i].resp_rdy ) begin
              resp_queue.pop_front();
              recv_intv_delay <= p_recv_intv_delay;
            end
          end else begin
            dut[i].resp_val <= 1'b0;
            dut[i].resp_msg <= 'x;
          end
        end
      end

      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      // Handle transactions
      // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      t_req_msg    curr_req;
      t_resp_msg   curr_resp;
      logic [31:0] _temp_write_data;

      // verilator lint_off BLKSEQ
      always @( posedge clk ) begin
        if( req_queue.size() > 0 ) begin
          curr_req = req_queue.pop_front();

          // Execute the transaction
          case( curr_req.op )
            MEM_MSG_READ: begin
              for( int w = 0; w < p_num_words; w++ ) begin
                if( try_fl_read(curr_req.addr + (w << 2), _temp_write_data) )
                  curr_resp.data[w*32 +: 32] = _temp_write_data;
                else if( (curr_req.addr + (w << 2)) == CYCLE_COUNT_ADDR )
                  curr_resp.data[w*32 +: 32] = cycle_count;
                else if( mem.exists( curr_req.addr + (w << 2) ) == 1 )
                  curr_resp.data[w*32 +: 32] = mem[curr_req.addr + (w << 2)];
                else
                  curr_resp.data[w*32 +: 32] = 'x;
              end
              curr_resp.strb  = curr_req.strb;
            end
            MEM_MSG_WRITE: begin
              for( int w = 0; w < p_num_words; w++ ) begin
                if( mem.exists( curr_req.addr + (w << 2) ) == 1 )
                  _temp_write_data = mem[curr_req.addr + (w << 2)];
                else
                  _temp_write_data = '0;
                if( ( curr_req.strb[w*4 +: 4] & 4'b0001 ) > 0 )
                  _temp_write_data[7:0] = curr_req.data[w*32 +: 8];
                if( ( curr_req.strb[w*4 +: 4] & 4'b0010 ) > 0 )
                  _temp_write_data[15:8] = curr_req.data[w*32+8 +: 8];
                if( ( curr_req.strb[w*4 +: 4] & 4'b0100 ) > 0 )
                  _temp_write_data[23:16] = curr_req.data[w*32+16 +: 8];
                if( ( curr_req.strb[w*4 +: 4] & 4'b1000 ) > 0 )
                  _temp_write_data[31:24] = curr_req.data[w*32+24 +: 8];
                if( curr_req.strb[w*4 +: 4] == 4'b1111 ) begin
                  if( try_fl_write(curr_req.addr + (w << 2), _temp_write_data) );
                  else
                    mem[curr_req.addr + (w << 2)] = _temp_write_data;
                end else begin
                  mem[curr_req.addr + (w << 2)] = _temp_write_data;
                end
              end

              curr_resp.data = 'x;
              curr_resp.strb  = curr_req.strb;
            end
          endcase

          curr_resp.op     = curr_req.op;
          curr_resp.addr   = curr_req.addr;
          curr_resp.opaque = curr_req.opaque;

          // Store the result to be sent back
          resp_queue.push_back( curr_resp );
        end
      end
      // verilator lint_on BLKSEQ

    end
  endgenerate

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  function string trace(int trace_level);
    string req_linetrace, resp_linetrace;
    int str_len;

    str_len = 2 + 1 +
              ceil_div_4(p_opaq_bits) + 1 +
              8                       + 1 +
              ceil_div_4(p_num_words * 32);

    trace = "";

    for( int p = 0; p < p_num_ports; p++ ) begin
      if( p != 0 )
        trace = {trace, " "};

      if( port_req_val[p] & port_req_rdy[p] ) begin
        case( port_req_msg[p].op )
          MEM_MSG_READ:  req_linetrace = "rd";
          MEM_MSG_WRITE: req_linetrace = "wr";
          default:       req_linetrace = "??";
        endcase

        if( trace_level > 0 ) begin
          req_linetrace = {req_linetrace, ":", $sformatf("%h:%h:%h",
                           port_req_msg[p].opaque, port_req_msg[p].addr,
                           port_req_msg[p].data)};
        end
      end else begin
        if( trace_level > 0 )
          req_linetrace = {str_len{" "}};
        else
          req_linetrace = {2{" "}};
      end

      if( port_resp_val[p] & port_resp_rdy[p] ) begin
        case( port_resp_msg[p].op )
          MEM_MSG_READ:  resp_linetrace = "rd";
          MEM_MSG_WRITE: resp_linetrace = "wr";
          default:       resp_linetrace = "??";
        endcase

        if( trace_level > 0 ) begin
          resp_linetrace = {resp_linetrace, ":", $sformatf("%h:%h:%h",
                           port_resp_msg[p].opaque, port_resp_msg[p].addr,
                           port_resp_msg[p].data)};
        end
      end else begin
        if( trace_level > 0 )
          resp_linetrace = {str_len{" "}};
        else
          resp_linetrace = {2{" "}};
      end

      trace = {trace, $sformatf("%s > %s", req_linetrace, resp_linetrace)};
    end
  endfunction

endmodule

`endif // TEST_FL_MEM_INTF_TEST_SERVER_MP_V
