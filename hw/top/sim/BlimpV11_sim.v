//========================================================================
// BlimpV11_sim.v
//========================================================================
// A module for simulating BlimpV11

`include "asm/assemble.v"
`include "hw/top/BlimpV11.v"
`include "hw/top/sim/utils/SimUtils.v"
`include "intf/MemIntf.v"
`include "intf/InstTraceNotif.v"
`include "test/fl/MemIntfTestServer.v"

import "DPI-C" context function void load_elf ( string elf_file );

module BlimpV11_sim;

  // Define default simulation parameters
  localparam p_num_phys_regs = 36;
  localparam p_opaq_bits     = 8;
  localparam p_seq_num_bits  = 5;
  localparam p_num_be_lanes  = 4;
  localparam p_num_fe_lanes  = 4;
  localparam p_iq_depth      = 4;
  
  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk;
  logic rst;

  SimUtils t( .* );

  `MEM_REQ_DEFINE ( p_opaq_bits );
  `MEM_RESP_DEFINE( p_opaq_bits );

  `MEM_REQ_DEFINE_SS ( p_opaq_bits, p_num_fe_lanes );
  `MEM_RESP_DEFINE_SS( p_opaq_bits, p_num_fe_lanes );

  //----------------------------------------------------------------------
  // Instantiate processor
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_words (p_num_fe_lanes)
  ) imem_intf();

  MemIntf #(
    .p_opaq_bits (p_opaq_bits)
  ) dmem_intf();

  InstTraceNotif inst_trace_notif [p_num_be_lanes]();

  BlimpV11 #(
    .p_opaq_bits     (p_opaq_bits),
    .p_seq_num_bits  (p_seq_num_bits),
    .p_num_phys_regs (p_num_phys_regs),
    .p_num_fe_lanes  (p_num_fe_lanes),
    .p_num_be_lanes  (p_num_be_lanes),
    .p_iq_depth      (p_iq_depth)
  ) dut (
    .inst_mem   (imem_intf),
    .data_mem   (dmem_intf),
    .inst_trace (inst_trace_notif),
    .*
  );

  logic [31:0] inst_trace_pc    [p_num_be_lanes];
  logic  [4:0] inst_trace_waddr [p_num_be_lanes];
  logic [31:0] inst_trace_wdata [p_num_be_lanes];
  logic        inst_trace_wen   [p_num_be_lanes];
  logic        inst_trace_val   [p_num_be_lanes];

  genvar i;
  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin : GEN_INST_TRACE_ASSIGN
      assign inst_trace_pc[i]    = inst_trace_notif[i].pc;
      assign inst_trace_waddr[i] = inst_trace_notif[i].waddr;
      assign inst_trace_wdata[i] = inst_trace_notif[i].wdata;
      assign inst_trace_wen[i]   = inst_trace_notif[i].wen;
      assign inst_trace_val[i]   = inst_trace_notif[i].val;
    end
  endgenerate

  always @( posedge clk ) begin
    #2;
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      if( inst_trace_val[j] ) begin
        t.inst_trace(
          inst_trace_pc[j],
          inst_trace_waddr[j],
          inst_trace_wdata[j],
          inst_trace_wen[j]
        );
      end
    end
  end

  //----------------------------------------------------------------------
  // FL Memory
  //----------------------------------------------------------------------

  MemIntfTestServer #(
    .t_req_msg         (`MEM_REQ_SS ( p_opaq_bits, p_num_fe_lanes )),
    .t_resp_msg        (`MEM_RESP_SS( p_opaq_bits, p_num_fe_lanes )),
    .p_send_intv_delay ( 1 ),
    .p_recv_intv_delay ( 1 ),
    .p_opaq_bits       (p_opaq_bits),
    .p_num_words       (p_num_fe_lanes)
  ) fl_imem (
    .dut (imem_intf),
    .*
  );

  MemIntfTestServer #(
    .t_req_msg         (`MEM_REQ ( p_opaq_bits )),
    .t_resp_msg        (`MEM_RESP( p_opaq_bits )),
    .p_send_intv_delay ( 1 ),
    .p_recv_intv_delay ( 1 ),
    .p_opaq_bits       (p_opaq_bits)
  ) fl_dmem (
    .dut (dmem_intf),
    .*
  );

  function void init_mem(
    input bit [31:0] addr,
    input bit [31:0] data
  );

    // Write both with same data, not optimal but I don't want
    // to change the C code lol
    fl_imem.init_mem( addr, data );
    fl_dmem.init_mem( addr, data );
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

    trace = {trace, fl_imem.trace( t.trace_level )};
    trace = {trace, " || "};
    trace = {trace, fl_dmem.trace( t.trace_level )};
    trace = {trace, " || "};
    trace = {trace, dut.trace( t.trace_level )};
    trace = {trace, " || "};

    // Instruction trace
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      if( j != 0 )
        trace = {trace, "  "};

      if( inst_trace_val[j] ) begin
        trace = {trace, $sformatf("0x%08x: ", inst_trace_pc[j])};
        if( inst_trace_wen[j] ) begin
          trace = {trace, $sformatf("0x%08x -> R[%0d]", inst_trace_wdata[j], inst_trace_waddr[j])};
        end
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
