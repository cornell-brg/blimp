//========================================================================
// TestCaller.v
//========================================================================
// A FL operation-centric caller

`ifndef TEST_FL_TESTCALLER_V
`define TEST_FL_TESTCALLER_V

`include "test/FLTestUtils.v"

module TestCaller #(
  parameter type t_call_msg = logic[31:0],
  parameter type t_ret_msg  = logic[31:0]
)(
  input  logic clk,
  
  output t_call_msg call_msg,
  input  t_ret_msg  ret_msg,
  output logic      en,
  input  logic      rdy
);

  FLTestUtils t( .rst( 1'b0 ), .* );
  
  initial begin
    call_msg = 'x;
    en       = 1'b0;
  end

  //----------------------------------------------------------------------
  // call
  //----------------------------------------------------------------------
  // A function to call the interface

  t_ret_msg dut_ret_msg;

  task call (
    input t_call_msg dut_call_msg,
    input t_ret_msg  exp_ret_msg
  );
    call_msg = dut_call_msg;
    
    while( !rdy ) begin
      @( posedge clk );
      #1;
    end

    // Interface is ready - can call message
    en = 1'b1;

    #2;
    dut_ret_msg = ret_msg;

    @( posedge clk );
    #1;

    `CHECK_EQ( dut_ret_msg, exp_ret_msg );

    en       = 1'b0;
    call_msg = 'x;

  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string test_trace;
  int trace_len;
  initial begin
    test_trace = $sformatf("%x:%x", call_msg, ret_msg);
    trace_len = test_trace.len();
  end

  function string trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    if( en & rdy )
      trace = $sformatf("%x:%x", call_msg, ret_msg);
    else if( rdy )
      trace = {(trace_len){" "}};
    else if( en ) // Violate calling convention
      trace = {(trace_len){"X"}};
    else
      trace = {{(trace_len-1){" "}}, "."};
  endfunction
endmodule

`endif // TEST_FL_TESTCALLER_V
