//========================================================================
// SimUtils.v
//========================================================================
// Simulation utilities, to be used in processor simulations

`ifndef HW_TOP_SIM_SIM_UTILS_V
`define HW_TOP_SIM_SIM_UTILS_V

//------------------------------------------------------------------------
// Colors
//------------------------------------------------------------------------

`define RED    "\033[31m"
`define YELLOW "\033[33m"
`define GREEN  "\033[32m"
`define BLUE   "\033[34m"
`define PURPLE "\033[35m"
`define RESET  "\033[0m"

//------------------------------------------------------------------------
// SimUtils
//------------------------------------------------------------------------

module SimUtils
(
  output logic clk,
  output logic rst
);

  // ---------------------------------------------------------------------
  // Clocking
  // ---------------------------------------------------------------------
  
  // verilator lint_off BLKSEQ
  initial clk = 1'b1;
  always #5 clk = ~clk;
  // verilator lint_on BLKSEQ

  // ---------------------------------------------------------------------
  // Filtering Utilities
  // ---------------------------------------------------------------------

  // verilator lint_off UNUSEDSIGNAL
  logic verbose;
  int trace_level;
  // verilator lint_on UNUSEDSIGNAL

  initial begin
    if ( $test$plusargs ("vverbose") ) begin
      verbose     = 1'b1;
      trace_level = 1;
    end
    else if ( $test$plusargs ("vv") ) begin
      verbose     = 1'b1;
      trace_level = 1;
    end
    else if ( $test$plusargs ("verbose") ) begin
      verbose     = 1'b1;
      trace_level = 0;
    end
    else if ( $test$plusargs ("v") ) begin
      verbose     = 1'b1;
      trace_level = 0;
    end
    else begin
      verbose     = 1'b0;
      trace_level = 0;
    end
  end

  string elf_file;
  initial begin
    if( !$value$plusargs( "elf=%s", elf_file ) )
      $fatal(0, "No ELF file specified with +elf=/path/to/elf" );
  end

  // ---------------------------------------------------------------------
  // Waveform Dumping
  // ---------------------------------------------------------------------

  string filename;
  initial begin
    if ( $value$plusargs( "dump-vcd=%s", filename ) ) begin
      $dumpfile(filename);
      $dumpvars();
    end
  end

  int fd;
  logic dump_trace;
  string trace_filename;
  initial begin
    if ( $value$plusargs( "dump-trace=%s", trace_filename ) ) begin
      fd = $fopen (trace_filename, "w");
      dump_trace = 1'b1;
    end else begin
      dump_trace = 1'b0;
    end
  end

  // verilator lint_off UNUSEDSIGNAL
  int    json_fd;
  logic  dump_json;
  string json_filename;
  // verilator lint_on UNUSEDSIGNAL
  initial begin
    if ( $value$plusargs( "trace-json=%s", json_filename ) ) begin
      json_fd   = $fopen (json_filename, "w");
      dump_json = 1'b1;
    end else begin
      dump_json = 1'b0;
    end
  end

  // ---------------------------------------------------------------------
  // Timeout
  // ---------------------------------------------------------------------

  int   cycles;
  int   timeout     = 10000;
  logic timeout_val = 1'b0;

  initial begin
    if( $value$plusargs( "timeout=%d", timeout ) )
      timeout_val = 1'b1;
  end

  always @( posedge clk ) begin

    if ( rst )
      cycles <= 0;
    else
      cycles <= cycles + 1;

    if ( timeout_val & ( cycles > timeout ) ) begin
      $write("\n");
      // $fatal("ERROR (cycles=%0d): timeout!", cycles );
      $finish;
    end

  end

  // ---------------------------------------------------------------------
  // Random Seeding
  // ---------------------------------------------------------------------

  // Seed random test cases
  int seed = 32'hdeadbeef;
  initial seed = $urandom(seed);

  task sim_begin();
    rst = 1'b1;
    for( int i = 0; i < 3; i = i + 1 ) begin
      @(posedge clk);
    end
    rst = 1'b0;
  endtask

  //----------------------------------------------------------------------
  // trace
  //----------------------------------------------------------------------

  task trace( string msg_to_trace );
    if( verbose )
      $display( msg_to_trace );
  endtask

  //----------------------------------------------------------------------
  // inst_trace
  //----------------------------------------------------------------------

  task inst_trace(
    input logic [31:0] pc,
    input logic  [4:0] waddr,
    input logic [31:0] wdata,
    input logic        wen
  );
    if( dump_trace ) begin
      $fwrite(fd, "0x%08x: ", pc);
      if( wen ) begin
        $fwrite(fd, "0x%08x -> R[%0d]",
          wdata,
          waddr
        );
      end
      $fdisplay(fd, "");
    end
  endtask

endmodule

`endif // HW_TOP_SIM_SIM_UTILS_V
