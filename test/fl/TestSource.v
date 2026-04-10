//========================================================================
// TestSource.v
//========================================================================
// A FL test source for inputting messages to DUTs

`ifndef TEST_FL_TESTSOURCE_V
`define TEST_FL_TESTSOURCE_V

module TestSource #(
  parameter type t_msg = logic[31:0],
  parameter int  p_seq_len = 100
)(
  input  logic clk,
  input  logic go,

  output logic val,
  input  logic rdy,
  output t_msg msg,

  output logic done
);

  //----------------------------------------------------------------------
  // Message test sequence
  //----------------------------------------------------------------------

  logic seq_val [p_seq_len];
  t_msg seq_msg [p_seq_len];
  
  integer seq_end_ptr;
  integer run_ptr;

  initial begin
    for( int i = 0; i < p_seq_len; i++ )begin
      seq_val[i] = 1'b0;
    end

    seq_end_ptr = '0;
    run_ptr = '0;
  end

  //----------------------------------------------------------------------
  // clear
  //----------------------------------------------------------------------
  // Task that clears the internal message sequence for a new test case

  task clear();
    seq_end_ptr = '0;
    run_ptr = '0;
  endtask

  //----------------------------------------------------------------------
  // add_send
  //----------------------------------------------------------------------
  // Task that appends a test message to the current test sequence

  task add_send (
    input logic add_val,
    input t_msg add_msg
  );
    if( seq_end_ptr < p_seq_len ) begin
      seq_val[seq_end_ptr] = add_val;
      seq_msg[seq_end_ptr] = add_msg;
      seq_end_ptr = seq_end_ptr + 1;
    end
  endtask

  //----------------------------------------------------------------------
  // Run logic
  //----------------------------------------------------------------------
  // Logic that runs the entire test sequence following the val/rdy 
  // handshake protocol.

  assign done = ( run_ptr == seq_end_ptr );

  always @( posedge clk ) begin
    #1;
    if ( go && !done ) begin
      if ( seq_val[run_ptr] )  begin
        val <= 1'b1;
        msg <= seq_msg[run_ptr];
        #2;
        if ( rdy )
          run_ptr <= run_ptr + 1;
      end
      else begin
        val <= 1'b0;
        run_ptr <= run_ptr + 1;
      end
    end
    else begin
      val <= 1'b0;
    end
  end

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

endmodule

`endif /* TEST_FL_TESTSOURCE_V */
