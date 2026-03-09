//========================================================================
// TestMCaller.v
//========================================================================
// A FL operation-centric caller

`ifndef TEST_FL_TESTM_CALLER_V
`define TEST_FL_TESTM_CALLER_V

`include "test/FLTestUtils.v"

module TestMCaller #(
  parameter type t_call_msg = logic[31:0],
  parameter type t_ret_msg  = logic[31:0],
  parameter int  p_num_msgs = 2
)(
  input  logic clk,
  
  output t_call_msg call_msg [p_num_msgs],
  input  t_ret_msg  ret_msg  [p_num_msgs],
  output logic      en,
  input  logic      rdy
);

  FLTestUtils t( .rst( 1'b0 ), .* );
  
  initial begin
    for( int i = 0; i < p_num_msgs; i++ )
      call_msg[i] = 'x;
    en       = 1'b0;
  end

  //----------------------------------------------------------------------
  // call
  //----------------------------------------------------------------------
  // A function to call the interface

  t_ret_msg dut_ret_msg [p_num_msgs];

  task call (
    input t_call_msg dut_call_msg    [p_num_msgs],
    input t_ret_msg  exp_ret_msg     [p_num_msgs],
    input logic      exp_ret_msg_val [p_num_msgs] = '{default: 1'b1}
  );
    for( int i = 0; i < p_num_msgs; i++ )
      call_msg[i] = dut_call_msg[i];

    // Interface is ready - can call message
    en = 1'b1;
    
    while( !rdy ) begin
      // @( posedge clk );
      #1;
    end

    #2;
    for( int i = 0; i < p_num_msgs; i++ )
      dut_ret_msg[i] = ret_msg[i];

    @( posedge clk );
    #1;

    for( int i = 0; i < p_num_msgs; i++ )
      if (exp_ret_msg_val[i])
        `CHECK_EQ( dut_ret_msg[i], exp_ret_msg[i] );

    en       = 1'b0;
    for( int i = 0; i < p_num_msgs; i++ )
      call_msg[i] = 'x;

  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string test_trace;
  int trace_len;
  initial begin
`ifdef VERILATOR
    test_trace = $sformatf("%x:%x", call_msg, ret_msg);
`else
    test_trace = $sformatf("%p:%p", call_msg, ret_msg);
`endif
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

      if( en & rdy )
        trace = {trace, $sformatf("%x:%x", call_msg[i], ret_msg[i])};
      else if( rdy )
        trace = {trace, {((trace_len)/4){" "}}};
      else if( en ) // Violate calling convention
        trace = {trace, {((trace_len)/4){"X"}}};
      else
        trace = {trace, {((trace_len-1)/4){" "}}, "."};
      end
  endfunction
endmodule

`endif // TEST_FL_TESTMCALLER_V
