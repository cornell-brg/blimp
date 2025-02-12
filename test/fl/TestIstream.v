//========================================================================
// TestIstream.v
//========================================================================
// A FL input stream for providing stimulus to DUTs

`ifndef TEST_FL_TESTISTREAM_V
`define TEST_FL_TESTISTREAM_V

`include "intf/StreamIntf"

module TestIstream #(
  parameter type t_msg   = logic[31:0],
  parameter      p_delay = 0
)(
  input  logic clk,
  
  StreamIntf.ostream dut
);

  initial begin
    dut.msg = 'x;
    dut.val = 1'b0;
  end
  
  //----------------------------------------------------------------------
  // send
  //----------------------------------------------------------------------
  // A function to send a stimulus across a stream interface

  logic msg_sent;

  // verilator lint_off BLKSEQ
  
  task send (
    input t_msg dut_msg
  );

    dut.val  = 1'b0;
    dut.msg  = 'x;
    msg_sent = 1'b0;
    
    // Delay for the send interval
    for( int i = 0; i < p_delay; i = i + 1 ) begin
      @( posedge clk );
      #1;
    end

    dut.val = 1'b1;
    dut.msg = dut_msg;

    do begin
      #2
      msg_sent = dut.rdy;
      @( posedge clk );
      #1;
    end while( !msg_sent );

    dut.val = 1'b0;
    dut.msg = 'x;

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
