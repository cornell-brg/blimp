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
  logic waiting;

  initial waiting = 1'b0;

  task sub (
    input t_msg exp_msg [p_num_msgs],
    input logic exp_val [p_num_msgs]
  );

    waiting = 1'b1;
    for( int i = 0; i < p_num_msgs; i++ ) begin
      fork
        automatic int ii = i;
        if( exp_val[ii] ) begin
          do begin
            #2;
            msg_recv[ii] = val[ii];
            dut_msg[ii]  = msg[ii];
            @( posedge clk );
            #1;
          end while( !msg_recv[ii] );
          `CHECK_EQ_SET( dut_msg[ii], exp_msg, exp_val );
        end
      join_none
    end
    wait fork;

    waiting = 1'b0;

  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  // string test_trace;
  // int trace_len;
  // initial begin
  //   test_trace = $sformatf("%p", msg);
  //   trace_len = test_trace.len();
  // end

  // function string trace(
  //   // verilator lint_off UNUSEDSIGNAL
  //   int trace_level
  //   // verilator lint_on UNUSEDSIGNAL
  // );
  //   if( val & waiting )
  //     trace = $sformatf("%p", msg);
  //   else if( val )
  //     trace = {{(trace_len-1){" "}}, "X"};
  //   else if( waiting )
  //     trace = {(trace_len){" "}};
  //   else
  //     trace = {{(trace_len-1){" "}}, "."};
  // endfunction

endmodule

`endif // TEST_FL_TESTMSUB_V
