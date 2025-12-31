//========================================================================
// TestMPub.v
//========================================================================
// A FL publisher for sending notifications to DUTs

`ifndef TEST_FL_TESTMPUB_V
`define TEST_FL_TESTMPUB_V

module TestMPub #(
  parameter type t_msg    = logic[31:0],
  parameter int  p_num_msgs = 2
)(
  input  logic clk,
  
  output t_msg msg [p_num_msgs],
  output logic val [p_num_msgs] 
);

  initial begin
    for( int i = 0; i < p_num_msgs; i++ ) begin
      msg[i] = '{default: 'x};
      val[i] = '0;
    end
  end

  //----------------------------------------------------------------------
  // pub
  //----------------------------------------------------------------------
  // A function to send a notification

  task pub (
    input t_msg dut_msg [p_num_msgs],
    input logic dut_val [p_num_msgs]
  );

    for( int i = 0; i < p_num_msgs; i++ ) begin
      if( dut_val[i] ) begin
        val[i] = 1'b1;
        msg[i] = dut_msg[i];
      end
    end

    @( posedge clk );
    #1;

    for( int i = 0; i < p_num_msgs; i++ ) begin
      val[i] = 1'b0;
      msg[i] = 'x;
    end

  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string test_trace;
  int trace_len;
  initial begin
    test_trace = $sformatf("%p", msg);
    trace_len = test_trace.len();
  end

  function string trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    if( val.or() )
      trace = $sformatf("%p", msg);
    else
      trace = {(trace_len){" "}};
  endfunction

endmodule

`endif // TEST_FL_TESTPUB_V
