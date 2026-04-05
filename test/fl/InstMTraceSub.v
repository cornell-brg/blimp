//========================================================================
// InstMTraceSub.v
//========================================================================
// A FL module for checking instruction traces
//
// A new module is used instead of TestSub to conditionally check waddr
// and wdata, based on wen

`ifndef TEST_FL_INSTMTRACESUB_V
`define TEST_FL_INSTMTRACESUB_V

`include "test/FLTestUtils.v"

module InstMTraceSub #(
  parameter p_num_lanes    = 2,
  parameter p_sample_delay = 0
) (
  input logic        clk,
  
  input logic [31:0] pc    [p_num_lanes],
  input logic  [4:0] waddr [p_num_lanes],
  input logic [31:0] wdata [p_num_lanes],
  input logic        wen   [p_num_lanes],
  input logic        val   [p_num_lanes]
);

  logic waiting;

  typedef struct packed {
    logic [31:0] pc;
    logic  [4:0] waddr;
    logic [31:0] wdata;
    logic        wen;
  } t_trace_struct;

  t_trace_struct trace_q [$];

  // Delayed copies of input signals, sampled after signals settle
  logic [31:0] pc_d    [p_num_lanes];
  logic  [4:0] waddr_d [p_num_lanes];
  logic [31:0] wdata_d [p_num_lanes];
  logic        wen_d   [p_num_lanes];
  logic        val_d   [p_num_lanes];

  // Sample delayed copies at +1ns (after clock-to-Q, before linetrace's #2)
  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #1;
    for (int i = 0; i < p_num_lanes; i++) begin
      pc_d[i]    = pc[i];
      waddr_d[i] = waddr[i];
      wdata_d[i] = wdata[i];
      wen_d[i]   = wen[i];
      val_d[i]   = val[i];
    end
  end
  // verilator lint_on BLKSEQ

  // push all valid input traces onto the queue on the posedge
  initial begin
    while (1) begin
      @( posedge clk );
      #((p_sample_delay)*1ns); // prevent data ambiguity at posedge
      for (int i = 0; i < p_num_lanes; i++) begin
        if (val[i]) begin
          if (wen[i])
            trace_q.push_back( '{ pc:    pc[i],
                                  waddr: waddr[i],
                                  wdata: wdata[i],
                                  wen:   wen[i]} );
          else // veri..ator doesn't compare to 'x correctly since it's not a 4-state sim, so need to force dut to 'x
            trace_q.push_back( '{ pc:    pc[i],
                                  waddr: 'x,
                                  wdata: 'x,
                                  wen:   wen[i]} );
        end
      end
    end
  end
  
  FLTestUtils t( .rst( 1'b0), .* );

  //----------------------------------------------------------------------
  // check_trace
  //----------------------------------------------------------------------
  // A function to check an instruction trace

  initial waiting = 1'b0;

  t_trace_struct trace_to_chk;

  function in_trace_q (
    input  t_trace_struct __ref
  );
    automatic bit found;
    found = 0;
    foreach ( trace_q[i] ) begin
      if ( __ref === ( __ref ^ trace_q[i] ^ __ref ) ) begin
        found = 1;
        break;
      end
    end
    return found;
  endfunction

  task check_trace (
    input logic [31:0] exp_pc,
    input logic  [4:0] exp_waddr,
    input logic [31:0] exp_wdata,
    input logic        exp_wen
  );
    waiting = 1'b1;

    trace_to_chk = '{
      pc:    exp_pc,
      waddr: exp_wen ? exp_waddr : 'x,
      wdata: exp_wen ? exp_wdata : 'x,
      wen:   exp_wen
    };

    do begin
      #2;
      @( posedge clk );
      #((p_sample_delay)*1ns);
    end while( !in_trace_q( trace_to_chk ) );
    
    `CHECK_DEL_EQ_Q( trace_q, trace_to_chk );
    // We essentially wait for the desired trace to appear in the queue,
    // if it never does then the program will time out which means a fail,
    // there is likely a better way to do this so that the error message
    // won't just say "timeout" but for now this will work :)

    waiting = 1'b0;

  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  function string trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    int str_len;
    str_len = 8 + 1 + // pc
              1 + 1 + // wen
              2 + 1 + // waddr
              8;      // wdata

    trace = "";
    for( int i = 0; i < p_num_lanes; i++ ) begin
      if( val_d[i] & waiting ) begin
        if( wen_d[i] )
          trace = {trace, $sformatf("%h:%b:%h:%h%s", pc_d[i], wen_d[i], waddr_d[i], wdata_d[i],
                            (i == p_num_lanes-1) ? "" : "  ")};
        else
          trace = {trace, $sformatf("%h:%b:%s:%s%s", pc_d[i], wen_d[i],
                            {2{"x"}},
                            {8{"x"}}, (i == p_num_lanes-1) ? "" : "  ")};
      end
      else if( val_d[i] )
        trace = {trace, {(str_len-1){" "}}, "X", (i == p_num_lanes-1) ? "" : "  "};
      else if( waiting )
        trace = {trace, {(str_len){" "}}, (i == p_num_lanes-1) ? "" : "  "};
      else
        trace = {trace, {(str_len-1){" "}}, ".", (i == p_num_lanes-1) ? "" : "  "};
    end
  endfunction

  function string inst_trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    inst_trace = "";
    for( int i = 0; i < p_num_lanes; i++ ) begin
      if( i != 0 )
        inst_trace = {inst_trace, "  "};

      if( val_d[i] ) begin
        if( wen_d[i] )
          inst_trace = $sformatf("0x%08x: 0x%08x -> R[%02d]", pc_d[i], wdata_d[i], waddr_d[i]);
        else
          inst_trace = $sformatf("0x%08x                     ", pc_d[i]);
      end
    end
  endfunction

endmodule

`endif // TEST_FL_INSTMTRACESUB_V
