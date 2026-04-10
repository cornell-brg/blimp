//========================================================================
// DelayStream.v
//========================================================================
// A streaming interface that implements delays between sender and
// receiver
//
// This module becomes transparent for synthesis

`ifndef HW_COMMON_DELAY_STREAM_V
`define HW_COMMON_DELAY_STREAM_V

module DelayStream #(
  parameter type t_msg        = logic,
  parameter p_send_intv_delay = 0,
  parameter p_recv_intv_delay = 0
)(
  input  logic clk,
  input  logic rst,

  input  logic send_val,
  output logic send_rdy,
  input  t_msg send_msg,

  output logic recv_val,
  input  logic recv_rdy,
  output t_msg recv_msg
);

  //----------------------------------------------------------------------
  // Transparent during synthesis
  //----------------------------------------------------------------------

`ifdef SYNTHESIS
  assign recv_val = send_val;
  assign send_rdy = recv_rdy;
  assign recv_msg = send_msg;

  //----------------------------------------------------------------------
  // Functional-level modeling
  //----------------------------------------------------------------------

`else
`ifndef CYCLE_TIME
  `define CYCLE_TIME 10
`endif

  t_msg msg_queue [$];

  always @( posedge clk ) begin
    if( rst )
      msg_queue.delete();
  end

  task enqueue( input t_msg msg );
    msg_queue.push_back( msg );
  endtask

  function int num_msgs();
    num_msgs = msg_queue.size();
  endfunction

  function t_msg dequeue();
    dequeue = msg_queue.pop_front();
  endfunction

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Handle requests
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  int send_intv_delay;

  always @( posedge clk ) begin
    if( send_intv_delay > 0 ) send_intv_delay <= send_intv_delay - 1;
  end

  initial send_rdy = 1'b0;

  always @( posedge clk ) begin
    `ifndef VCS_ASIC
    #1;
    `else
    #(`OUTPUT_DELAY);
    `endif
    if( rst ) begin
      send_rdy <= 1'b0;
    end
    else begin
      if( send_intv_delay == 0 ) begin
        send_rdy <= 1'b1;
        `ifndef VCS_ASIC
        #2;
        `else
        #(`CYCLE_TIME-`INPUT_DELAY-`OUTPUT_DELAY);
        `endif
        if( send_val ) begin
          enqueue( send_msg );
          send_intv_delay <= p_send_intv_delay;
        end
      end else begin
        send_rdy <= 1'b0;
      end
    end
  end

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Handle responses
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  int recv_intv_delay;

  always @( posedge clk ) begin
    if( recv_intv_delay > 0 ) recv_intv_delay <= recv_intv_delay - 1;
  end

  initial begin
    recv_val = 1'b0;
    recv_msg = 'x;
  end

  always @( posedge clk ) begin
    `ifndef VCS_ASIC
    #1;
    `else
    #(`OUTPUT_DELAY);
    `endif
    if( rst ) begin
      recv_val <= 1'b0;
      recv_msg <= 'x;
    end
    else begin
      if( (recv_intv_delay == 0) & (num_msgs() > 0) ) begin
        recv_val <= 1'b1;
        recv_msg <= msg_queue[0];
        `ifndef VCS_ASIC
        #2;
        `else
        #(`CYCLE_TIME-`INPUT_DELAY-`OUTPUT_DELAY);
        `endif
        if( recv_rdy ) begin
          msg_queue.pop_front();
          recv_intv_delay <= p_recv_intv_delay;
        end
      end else begin
        recv_val <= 1'b0;
        recv_msg <= 'x;
      end
    end
  end
  
`endif
endmodule

`endif // HW_COMMON_DELAY_STREAM_V
