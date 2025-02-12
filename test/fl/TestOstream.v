//========================================================================
// TestOstream.v
//========================================================================
// A FL output stream for receiving messages from DUTs

`ifndef TEST_FL_TESTOSTREAM_V
`define TEST_FL_TESTOSTREAM_V

`include "intf/StreamIntf"
`include "test/FLTestUtils.v"

module TestOstream #(
  parameter type t_msg   = logic[31:0],
  parameter      p_delay = 0
)(
  input  logic clk,
  input  logic rst,
  
  StreamIntf.istream dut
);

  FLTestUtils t( .* );

  initial begin
    dut.rdy = 1'b0;
  end

  //----------------------------------------------------------------------
  // recv
  //----------------------------------------------------------------------
  // A function to receive a message across a stream interface

  t_msg dut_msg;
  logic msg_recv;

  // verilator lint_off BLKSEQ
  
  task recv (
    input t_msg exp_msg
  );

    dut.rdy  = 1'b0;
    msg_recv = 1'b0;
    
    // Delay for the send interval
    for( int i = 0; i < p_delay; i = i + 1 ) begin
      @( posedge clk );
      #1;
    end

    dut.rdy = 1'b1;

    do begin
      #2
      msg_recv = dut.val;
      dut_msg  = dut.msg;
      @( posedge clk );
      #1;
    end while( !msg_recv );

    `CHECK_EQ( dut_msg, exp_msg );

    dut.rdy = 1'b0;

  endtask

  // verilator lint_on BLKSEQ

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Tracing
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  string msg_str;
  int trace_len;

  function string trace();
    msg_str = $sformatf( "%x", dut.msg );
    trace_len = msg_str.len();

    if( dut.val & dut.rdy )
      trace = msg_str;
    else if( !dut.val & dut.rdy )
      trace = {trace_len{" "}};
    else if( dut.val & !dut.rdy )
      trace = {{(trace_len-1){" "}}, "#"};
    else // !dut.val & !dut.rdy
      trace = {{(trace_len-1){" "}}, "."};
  endfunction

endmodule

`endif // TEST_FL_TESTISTREAM_V
