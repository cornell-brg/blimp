//========================================================================
// TestMSource.v
//========================================================================
// A FL multi test source for inputting messages to DUTs

`ifndef TEST_FL_TESTMSOURCE_V
`define TEST_FL_TESTMSOURCE_V

module TestMSource #(
  parameter type t_msg = logic[31:0],
  parameter int  p_num_srcs = 2,
  parameter int  p_seq_len = 100
)(
  input  logic clk,
  input  logic go,

  output logic val [p_num_srcs],
  input  logic rdy [p_num_srcs],
  output t_msg msg [p_num_srcs],

  output logic done
);

  //----------------------------------------------------------------------
  // Message test sequence
  //----------------------------------------------------------------------

  logic seq_val [p_num_srcs][p_seq_len];
  t_msg seq_msg [p_num_srcs][p_seq_len];
  
  integer seq_end_ptr[p_num_srcs];
  integer run_ptr[p_num_srcs];
  logic   src_done[p_num_srcs];

  initial begin
    for( int i = 0; i < p_num_srcs; i++ ) begin
      seq_end_ptr[i] = '0;
      run_ptr[i] = '0;
    end
  end

  //----------------------------------------------------------------------
  // clear
  //----------------------------------------------------------------------
  // Task that clears the internal message sequence for a new test case

  task clear();
    for( int i = 0; i < p_num_srcs; i++ ) begin
      seq_end_ptr[i] = '0;
      run_ptr[i] = '0;
    end
  endtask

  //----------------------------------------------------------------------
  // add_send
  //----------------------------------------------------------------------
  // Task that appends a test message to the current test sequence

  task add_send (
    input logic add_val [p_num_srcs],
    input t_msg add_msg [p_num_srcs]
  );
    for( int i = 0; i < p_num_srcs; i++ ) begin
      if( seq_end_ptr[i] < p_seq_len ) begin
        seq_val[i][seq_end_ptr[i]] = add_val[i];
        seq_msg[i][seq_end_ptr[i]] = add_msg[i];
        seq_end_ptr[i] = seq_end_ptr[i] + 1;
      end
    end
  endtask

  //----------------------------------------------------------------------
  // Run logic
  //----------------------------------------------------------------------
  // Logic that runs the entire test sequence following the val/rdy 
  // handshake protocol.

  genvar k;
  generate
    for( k = 0; k < p_num_srcs; k++ ) begin

      assign src_done[k] = ( run_ptr[k] == seq_end_ptr[k] );

      always @( posedge clk ) begin
        #1;
        if ( go && !src_done[k] ) begin
          if ( seq_val[k][run_ptr[k]] )  begin
            val[k] <= 1'b1;
            msg[k] <= seq_msg[k][run_ptr[k]];
            #2;
            if ( rdy[k] )
              run_ptr[k] <= run_ptr[k] + 1;
          end
          else begin
            val[k] <= 1'b0;
            run_ptr[k] <= run_ptr[k] + 1;
          end
        end
        else begin
          val[k] <= 1'b0;
        end
      end

    end
  endgenerate

  always @( * ) begin
    done = 1'b1;
    for( int i = 0; i < p_num_srcs; i++ ) begin
      done = done & src_done[i];
    end
  end

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

endmodule

`endif /* TEST_FL_TESTMSOURCE_V */
