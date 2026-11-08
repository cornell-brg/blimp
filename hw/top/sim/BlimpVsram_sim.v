//========================================================================
// BlimpVsram_sim.v
//========================================================================
// A module for simulating BlimpV8 on the memory network with srams

`include "asm/assemble.v"
`include "fpga/MemXBar.v"

`include "sram/SRAMMem.v"

`include "fpga/net/MemNetReq.v"
`include "fpga/net/MemNetResp.v"
`include "hw/top/BlimpV8.v"
`include "hw/top/sim/utils/SimUtils.v"
`include "intf/MemIntf.v"
`include "intf/InstTraceNotif.v"
`include "hw/top/sim/utils/FLPeripherals.v"

import "DPI-C" context function void load_elf ( string elf_file );

module BlimpVsram_sim;

  // Define default simulation parameters
  localparam p_num_phys_regs = 36;
  localparam p_opaq_bits     = 8;
  localparam p_seq_num_bits  = 5;
  localparam p_num_entries   = 65536;
  localparam p_num_bits      = $clog2( p_num_entries );
  
  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk;
  logic rst;

  SimUtils t( .* );

  `MEM_REQ_DEFINE ( p_opaq_bits );
  `MEM_RESP_DEFINE( p_opaq_bits );

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

  // BlimpV8_sp26 #(
  //   .p_opaq_bits     (p_opaq_bits),
  //   .p_seq_num_bits  (p_seq_num_bits),
  //   .p_num_phys_regs (p_num_phys_regs)
  // ) dut (
  //   .inst_mem   (mem_intf[0]),
  //   .data_mem   (mem_intf[1]),
  //   .inst_trace (inst_trace_notif),
  //   .inst_trace_deq_rdy (1),
  //   .debug              (0),
  //   .*
  // );

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
  ) sram_req();
  MemNetReq #(
    .p_opaq_bits (p_opaq_bits)
  ) peripheral_req();

  MemNetResp #(
    .p_opaq_bits (p_opaq_bits)
  ) sram_resp();
  MemNetResp #(
    .p_opaq_bits (p_opaq_bits)
  ) peripheral_resp();

  logic go;

  MemXBar #(
    .p_opaq_bits (p_opaq_bits)
  ) xbar (
    .clk (clk),
    .rst (rst),
    // Clients
    .imem (mem_intf[0]),
    .dmem (mem_intf[1]),
    .spi  (spi_intf),
    // Servers
    .mem_req (sram_req),
    .mem_resp(sram_resp),
    .*
  );

  SRAMMem #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_entries(p_num_entries)
  ) sram (
    .req  (sram_req),
    .resp (sram_resp),
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
  // Send data manually inside SRAM
  //----------------------------------------------------------------------

  function void init_mem(
    input bit [31:0] addr,
    input bit [31:0] data
  );
    // sram.sram_minion.sram.sram.mem[addr[p_num_bits+1:2]] = data;
    sram.init_mem( addr, data );
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
