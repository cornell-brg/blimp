//========================================================================
// BlimpV8_sim.v
//========================================================================
// A module for simulating BlimpV8

`include "asm/assemble.v"
`include "hw/top/BlimpV8.v"
`include "hw/top/sim/utils/SimUtils.v"
`include "intf/MemIntf.v"
`include "intf/InstTraceNotif.v"
`include "test/fl/MemIntfTestServer_2Port.v"

import "DPI-C" context function void load_elf ( string elf_file );

module BlimpV8_sim;

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
      t.commit_notify( 1 );
    end
  end

  //----------------------------------------------------------------------
  // FL Memory
  //----------------------------------------------------------------------

  MemIntfTestServer_2Port #(
    .t_req_msg         (`MEM_REQ ( p_opaq_bits )),
    .t_resp_msg        (`MEM_RESP( p_opaq_bits )),
    .p_send_intv_delay ( 1 ),
    .p_recv_intv_delay ( 1 ),
    .p_opaq_bits       (p_opaq_bits)
  ) fl_mem (
    .dut (mem_intf),
    .*
  );

  function void init_mem(
    input bit [31:0] addr,
    input bit [31:0] data
  );
    fl_mem.init_mem( addr, data );
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

    trace = {trace, fl_mem.trace( t.trace_level )};
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
    t.sim_begin();
    load_elf( t.elf_file );
  end

endmodule
