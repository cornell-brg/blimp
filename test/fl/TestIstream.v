//========================================================================
// TestIstream.v
//========================================================================
// A FL input stream for providing stimulus to DUTs

`ifndef TEST_FL_TESTISTREAM_V
`define TEST_FL_TESTISTREAM_V

module TestIstream #(
  parameter type t_msg        = logic[31:0],
  parameter p_send_intv_delay = 0
)(
  input  logic clk,
  
  output t_msg msg,
  output logic val,
  input  logic rdy
);

  initial begin
    msg = 'x;
    val = 1'b0;
  end
  
  //----------------------------------------------------------------------
  // send
  //----------------------------------------------------------------------
  // A function to send a stimulus across a stream interface

  logic msg_sent;

  // verilator lint_off BLKSEQ
  
  task automatic send (
    input t_msg dut_msg
  );

    val      = 1'b0;
    msg      = 'x;
    msg_sent = 1'b0;
    
    // Delay for the send interval
    for( int i = 0; i < p_send_intv_delay; i = i + 1 ) begin
      @( posedge clk );
      #1;
    end

    val = 1'b1;
    msg = dut_msg;

    do begin
      #2;
      msg_sent = rdy;
      @( posedge clk );
      #1;
    end while( !msg_sent );

    val = 1'b0;
    msg = 'x;

  endtask

  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string test_trace;
  int trace_len;
  initial begin
    test_trace = $sformatf("%x", msg);
    trace_len = test_trace.len();
  end

  function string trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    if( val & rdy )
      trace = $sformatf("%x", msg);
    else if( rdy )
      trace = {(trace_len){" "}};
    else if( val )
      trace = {{(trace_len-1){" "}}, "#"};
    else
      trace = {{(trace_len-1){" "}}, "."};
  endfunction

endmodule

`endif // TEST_FL_TESTISTREAM_V
