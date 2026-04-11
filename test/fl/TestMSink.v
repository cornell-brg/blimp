//========================================================================
// TestMSink.v
//========================================================================
// A FL multi test sink for inputting messages to DUTs

`ifndef TEST_FL_TESTMSINK_V
`define TEST_FL_TESTMSINK_V

// `include "test/fl/TestSink.v"

`include "test/TestUtils.v"

`define SINK_UNORDERED 1'b0
`define SINK_ORDERED 1'b1

module TestMSink #(
  parameter logic p_ordered = `SINK_ORDERED,
  parameter type  t_msg = logic[31:0],
  parameter int   p_num_sinks = 2,
  parameter int   p_seq_len = 100
)(
  input  logic clk,
  input  logic go,

  input  logic val [p_num_sinks],
  output logic rdy [p_num_sinks],
  input  t_msg msg [p_num_sinks],

  output logic done
);

  //----------------------------------------------------------------------
  // Message test sequence
  //----------------------------------------------------------------------

  logic seq_val [p_num_sinks][p_seq_len];
  t_msg seq_msg [p_num_sinks][p_seq_len];
  
  integer seq_end_ptr[p_num_sinks];
  integer run_ptr[p_num_sinks];
  logic   sink_done[p_num_sinks];

  initial begin
    for( int i = 0; i < p_num_sinks; i++ ) begin
      seq_end_ptr[i] = '0;
      run_ptr[i] = '0;
    end
  end

  //----------------------------------------------------------------------
  // clear
  //----------------------------------------------------------------------
  // Task that clears the internal message sequence for a new test case

  task clear();
    for( int i = 0; i < p_num_sinks; i++ ) begin
      seq_end_ptr[i] = '0;
      run_ptr[i] = '0;
    end
  endtask

  //----------------------------------------------------------------------
  // add_exp
  //----------------------------------------------------------------------
  // Task that appends a test message to the current test sequence

  task add_exp (
    input logic add_val [p_num_sinks],
    input t_msg add_msg [p_num_sinks]
  );
    for( int i = 0; i < p_num_sinks; i++ ) begin
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

  t_msg recv_msg;
  integer num_valid [p_num_sinks];

  genvar k;
  generate
    if ( p_ordered == `SINK_ORDERED ) begin
      for( k = 0; k < p_num_sinks; k++ ) begin

        assign sink_done[k] = ( run_ptr[k] == seq_end_ptr[k] );

        always @( posedge clk ) begin
          #1;
          if ( go && !sink_done[k] ) begin
            if ( seq_val[k][run_ptr[k]] )  begin
              rdy[k] <= 1'b1;
              #2;
              if ( val[k] ) begin
                `CHECK_EQ( msg[k], seq_msg[k][run_ptr[k]] );
                run_ptr[k] <= run_ptr[k] + 1;
              end
            end
            else begin
              rdy[k] <= 1'b0;
              run_ptr[k] <= run_ptr[k] + 1;
            end
          end
          else begin
            rdy[k] <= 1'b0;
          end
        end

      end
    end

    else if ( p_ordered == `SINK_UNORDERED ) begin
      for( k = 0; k < p_num_sinks; k++ ) begin

        always_comb begin
          num_valid[k] = 0;
          for ( int i = 0; i < p_seq_len; i++ )
            num_valid[k] += int'(seq_val[k][i]);
        end
        
        assign sink_done[k] = ( run_ptr[k] == num_valid[k] );

        always @( posedge clk ) begin
          #1;
          if ( go && !sink_done[k] ) begin
            rdy[k] <= 1'b1;
            #2;
            if ( val[k] ) begin
              `CHECK_EQ_SET( msg[k], seq_msg[k], seq_val[k] );
              run_ptr[k] <= run_ptr[k] + 1;
            end
          end
          else begin
            rdy[k] <= 1'b0;
          end
        end

      end
    end
  endgenerate

  always @( * ) begin
    done = 1'b1;
    for( int i = 0; i < p_num_sinks; i++ ) begin
      done = done & sink_done[i];
    end
  end

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

endmodule

`endif /* TEST_FL_TESTMSINK_V */
