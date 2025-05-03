//========================================================================
// BlimpVfpga_sim.v
//========================================================================
// A module for simulating BlimpV8 on the FPGA network

`include "asm/assemble.v"
`include "fpga/MemXBar.v"
`include "fpga/FPGAMem.v"
`include "fpga/net/MemNetReq.v"
`include "fpga/net/MemNetResp.v"
`include "hw/top/BlimpV8.v"
`include "hw/top/sim/utils/SimUtils.v"
`include "intf/MemIntf.v"
`include "intf/InstTraceNotif.v"
`include "hw/top/sim/utils/FLPeripherals.v"

import "DPI-C" context function void load_elf ( string elf_file );

module BlimpVfpga_sim;

  // Define default simulation parameters
  localparam p_num_phys_regs = 36;
  localparam p_opaq_bits     = 8;
  localparam p_seq_num_bits  = 5;
  
  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk;
  logic rst;

  SimUtils t( .* );

  `MEM_REQ_DEFINE ( p_opaq_bits );
  `MEM_RESP_DEFINE( p_opaq_bits );

  // Memory clock
  logic mem_clk;

  // verilator lint_off BLKSEQ
  initial mem_clk = 1'b1;
  always #1 mem_clk = ~mem_clk;
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Instantiate processor
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits)
  ) mem_intf[2]();

  InstTraceNotif inst_trace_notif();

  BlimpV8 #(
    .p_opaq_bits     (p_opaq_bits),
    .p_seq_num_bits  (p_seq_num_bits),
    .p_num_phys_regs (p_num_phys_regs)
  ) dut (
    .inst_mem   (mem_intf[0]),
    .data_mem   (mem_intf[1]),
    .inst_trace (inst_trace_notif),
    .*
  );

  logic [31:0] inst_trace_pc;
  logic  [4:0] inst_trace_waddr;
  logic [31:0] inst_trace_wdata;
  logic        inst_trace_wen;
  logic        inst_trace_val;

  assign inst_trace_pc    = inst_trace_notif.pc;
  assign inst_trace_waddr = inst_trace_notif.waddr;
  assign inst_trace_wdata = inst_trace_notif.wdata;
  assign inst_trace_wen   = inst_trace_notif.wen;
  assign inst_trace_val   = inst_trace_notif.val;

  always @( posedge clk ) begin
    #2;
    if( inst_trace_val ) begin
      t.inst_trace(
        inst_trace_pc,
        inst_trace_waddr,
        inst_trace_wdata,
        inst_trace_wen
      );
    end
  end

  //----------------------------------------------------------------------
  // Memory Subsystem
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits)
  ) spi_intf();

  MemNetReq #(
    .p_opaq_bits (p_opaq_bits)
  ) bram_req();
  MemNetReq #(
    .p_opaq_bits (p_opaq_bits)
  ) peripheral_req();

  MemNetResp #(
    .p_opaq_bits (p_opaq_bits)
  ) bram_resp();
  MemNetResp #(
    .p_opaq_bits (p_opaq_bits)
  ) peripheral_resp();

  logic go;

  MemXBar #(
    .p_opaq_bits (p_opaq_bits)
  ) xbar (
    .clk (clk),
    .rst (rst),
    .imem (mem_intf[0]),
    .dmem (mem_intf[1]),
    .spi  (spi_intf),
    .*
  );

  FPGAMem #(
    .p_opaq_bits (p_opaq_bits)
  ) bram (
    .req  (bram_req),
    .resp (bram_resp),
    .*
  );

  FLPeripherals #(
    .p_send_intv_delay ( 1 ),
    .p_recv_intv_delay ( 1 ),
    .p_opaq_bits       (p_opaq_bits)
  ) peripherals (
    .req  (peripheral_req),
    .resp (peripheral_resp),
    .*
  );

  assign spi_intf.req_msg  = '0;
  assign spi_intf.req_val  = 1'b0;
  assign spi_intf.resp_rdy = 1'b1;

  logic unused;
  assign unused = &{ spi_intf.req_rdy, spi_intf.resp_val, spi_intf.req_msg };

  //----------------------------------------------------------------------
  // Send data manually inside BRAM
  //----------------------------------------------------------------------

  function void init_mem(
    input bit [31:0] addr,
    input bit [31:0] data
  );
    bram.mem_b0[ addr[17:2] ] = data[ 7: 0];
    bram.mem_b1[ addr[17:2] ] = data[15: 8];
    bram.mem_b2[ addr[17:2] ] = data[23:16];
    bram.mem_b3[ addr[17:2] ] = data[31:24];
  endfunction

  export "DPI-C" function init_mem;

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    trace = "";

    trace = {trace, peripherals.trace( t.trace_level )};
    trace = {trace, " || "};
    trace = {trace, dut.trace( t.trace_level )};
    trace = {trace, " || "};

    // Instruction trace
    if( inst_trace_val ) begin
      trace = {trace, $sformatf("0x%08x: ", inst_trace_pc)};
      if( inst_trace_wen ) begin
        trace = {trace, $sformatf("0x%08x -> R[%0d]", inst_trace_wdata, inst_trace_waddr)};
      end
    end

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Run the simulation
  //----------------------------------------------------------------------

  initial begin
    go = 1'b0;
    t.sim_begin();
    load_elf( t.elf_file );
    go = 1'b1;
  end

endmodule
