//========================================================================
// TestMSub.v
//========================================================================
// A FL subscriber for receiving notifications from DUTs

`ifndef TEST_FL_TESTMSUB_V
`define TEST_FL_TESTMSUB_V

`include "test/FLTestUtils.v"

module TestMSub #(
  parameter type t_msg = logic[31:0],
  parameter int  p_num_msgs = 2
)(
  input logic clk,
  
  input t_msg msg [p_num_msgs],
  input logic val [p_num_msgs]
);
  
  FLTestUtils t( .rst( 1'b0 ), .* );

  //----------------------------------------------------------------------
  // sub
  //----------------------------------------------------------------------
  // A function to receive a notification

  t_msg dut_msg  [p_num_msgs];
  logic msg_recv [p_num_msgs];
  logic all_recv;

  task sub (
    input t_msg exp_msg [p_num_msgs],
    input logic exp_val [p_num_msgs]
  );

    for( int i = 0; i < p_num_msgs; i++ ) begin
      msg_recv[i] = !exp_val[i];
    end

    // Loop & advance simulation time until the messages are received
    do begin
      all_recv = 1'b1;
      #2;
      for( int i = 0; i < p_num_msgs; i++ ) begin
        if( exp_val[i] && !msg_recv[i] ) begin
          msg_recv[i] = val[i];
          dut_msg[i]  = msg[i];
        end
        all_recv = all_recv && msg_recv[i];
      end
      @( posedge clk );
      #1;
    end while( !all_recv );
    
    // Check that all received messages exist somewhere in the expected messages
    for( int j = 0; j < p_num_msgs; j++ ) begin
      if( exp_val[j] ) begin
        `CHECK_EQ_SET( dut_msg[j], exp_msg, exp_val );
      end
    end

  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string test_trace;
  int trace_len;
  initial begin
    test_trace = $sformatf("%h", msg[0]);
    trace_len = test_trace.len();
  end

  function string trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    trace = "";

    for( int i = 0; i < p_num_msgs; i++ ) begin
      if( i != 0 )
        trace = {trace, "  "};

      if( val[i] & !all_recv )
        trace = $sformatf("%h", msg[i]);
      else if( val[i] )
        trace = {{(trace_len-1){" "}}, "X"};
      else if( !all_recv )
        trace = {(trace_len){" "}};
      else
        trace = {{(trace_len-1){" "}}, "."};
    end
  endfunction

endmodule

`endif // TEST_FL_TESTMSUB_V
