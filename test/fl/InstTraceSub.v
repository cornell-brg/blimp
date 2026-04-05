//========================================================================
// InstTraceSub.v
//========================================================================
// A FL module for checking instruction traces
//
// A new module is used instead of TestSub to conditionally check waddr
// and wdata, based on wen

`ifndef TEST_FL_INSTTRACESUB_V
`define TEST_FL_INSTTRACESUB_V

`include "test/FLTestUtils.v"

module InstTraceSub #(
  parameter p_sample_delay = 0
) (
  input logic        clk,

  input logic [31:0] pc,
  input logic  [4:0] waddr,
  input logic [31:0] wdata,
  input logic        wen,
  input logic        val
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
  logic [31:0] pc_d;
  logic  [4:0] waddr_d;
  logic [31:0] wdata_d;
  logic        wen_d;
  logic        val_d;

  // Sample delayed copies at +1ns (after clock-to-Q, before linetrace's #2)
  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #1;
    pc_d    = pc;
    waddr_d = waddr;
    wdata_d = wdata;
    wen_d   = wen;
    val_d   = val;
  end
  // verilator lint_on BLKSEQ

  // push all valid input traces onto the queue on the posedge
  initial begin
    while (1) begin
      @( posedge clk );
      #((p_sample_delay)*1ns); // prevent data ambiguity at posedge
      if (val) begin
        if (wen)
          trace_q.push_back( '{ pc:    pc,
                                waddr: waddr,
                                wdata: wdata,
                                wen:   wen} );
        else // veri..ator doesn't compare to 'x correctly since it's not a 4-state sim, so need to force dut to 'x
          trace_q.push_back( '{ pc:    pc,
                                waddr: 'x,
                                wdata: 'x,
                                wen:   wen} );
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

    if( val_d & waiting ) begin
      if( wen_d )
        trace = $sformatf("%h:%b:%h:%h", pc_d, wen_d, waddr_d, wdata_d);
      else
        trace = $sformatf("%h:%b:%s:%s", pc_d, wen_d,
                          {2{"x"}},
                          {8{"x"}});
    end
    else if( val_d )
      trace = {{(str_len-1){" "}}, "X"};
    else if( waiting )
      trace = {(str_len){" "}};
    else
      trace = {{(str_len-1){" "}}, "."};
  endfunction

  function string inst_trace(
    // verilator lint_off UNUSEDSIGNAL
    int trace_level
    // verilator lint_on UNUSEDSIGNAL
  );
    if( val_d ) begin
      if( wen_d )
        inst_trace = $sformatf("0x%08x: 0x%08x -> R[%02d]", pc_d, wdata_d, waddr_d);
      else
        inst_trace = $sformatf("0x%08x                     ", pc_d);
    end
  endfunction

endmodule

`endif // TEST_FL_INSTTRACESUB_V