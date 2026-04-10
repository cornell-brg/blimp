//========================================================================
// BlimpV11TestHarness.v
//========================================================================
// A top-level testing harness for Blimp V11

`ifndef HW_TOP_TEST_BLIMPV11TESTHARNESS_V
`define HW_TOP_TEST_BLIMPV11TESTHARNESS_V

`include "asm/assemble.v"
`include "intf/InstTraceNotif.v"
`include "intf/MemIntf.v"
`ifndef VCS_ASIC
`include "hw/top/BlimpV11.v"
`endif
`include "test/fl/MemIntfTestServer.v"
`include "test/fl/InstMTraceSub.v"
`include "fl/fl_vtrace.v"

import TestEnv::*;

module BlimpV11TestHarness #(
  // Define default simulation parameters
  parameter p_opaq_bits               = 8,
  parameter p_seq_num_bits            = 5,
  parameter p_num_phys_regs           = 36,
  parameter p_num_fe_lanes            = 4,
  parameter p_num_be_lanes            = 4,
  parameter p_iq_depth                = 4,
  parameter p_reclaim_width           = p_num_be_lanes,
  parameter p_max_in_flight           = 8,
  parameter p_f_intf_fifo_depth       = 4,
  parameter p_x_intf_fifo_depth       = 4,
  parameter p_alu_d_intf_fifo_depth   = 4,
  parameter p_mul_d_intf_fifo_depth   = 4,
  parameter p_mem_d_intf_fifo_depth   = 4,
  parameter p_ctrl_d_intf_fifo_depth  = 4,
  parameter p_num_alus                = 4,
  parameter p_num_muls                = 2,
  parameter p_num_ldstrs              = 1,
  parameter p_all_iq_in_order         = 0,
  parameter p_pipe_bypass             = '0,
  parameter p_num_pipes               = p_num_alus + p_num_muls + p_num_ldstrs + 1,
  parameter p_mem_send_intv_delay     = 1,
  parameter p_mem_recv_intv_delay     = 1,

  // Simulation-only backpressure parameters
  parameter [p_num_fe_lanes*8-1:0] p_sim_f2d_bp = '0,
  parameter [p_num_pipes*8-1:0]    p_sim_d2x_bp = '0,
  parameter [p_num_pipes*8-1:0]    p_sim_x2w_bp = '0
);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  initial t.timeout = 20000;

  `MEM_REQ_DEFINE ( p_opaq_bits );
  `MEM_RESP_DEFINE( p_opaq_bits );

  `MEM_REQ_DEFINE_SS ( p_opaq_bits, p_num_fe_lanes );
  `MEM_RESP_DEFINE_SS( p_opaq_bits, p_num_fe_lanes );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  MemIntf #(
    .p_opaq_bits (p_opaq_bits),
    .p_num_words (p_num_fe_lanes)
  ) imem_intf();

  MemIntf #(
    .p_opaq_bits (p_opaq_bits)
  ) dmem_intf [1]();

  InstTraceNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) inst_trace_notif[p_num_be_lanes]();

  logic [31:0] inst_trace_notif_pc    [p_num_be_lanes];
  logic  [4:0] inst_trace_notif_waddr [p_num_be_lanes];
  logic [31:0] inst_trace_notif_wdata [p_num_be_lanes];
  logic        inst_trace_notif_wen   [p_num_be_lanes];
  logic        inst_trace_notif_val   [p_num_be_lanes];

`ifdef VCS_ASIC

  `ifndef INPUT_DELAY
    `define INPUT_DELAY  0.0
  `endif
  `ifndef OUTPUT_DELAY
    `define OUTPUT_DELAY 0.0
  `endif

  // Derived message bit widths (must match BlimpV11SynthWrap)

  localparam p_imem_data_bits = p_num_fe_lanes * 32;
  localparam p_imem_strb_bits = p_num_fe_lanes * 4;
  localparam p_imem_msg_bits  = 1 + p_opaq_bits + 32
                              + p_imem_strb_bits + p_imem_data_bits;
  localparam p_dmem_data_bits = 32;
  localparam p_dmem_strb_bits = 4;
  localparam p_dmem_msg_bits  = 1 + p_opaq_bits + 32
                              + p_dmem_strb_bits + p_dmem_data_bits;

  //--------------------------------------------------------------------
  // Intermediate wires for DUT port connections
  //--------------------------------------------------------------------

  // DUT inputs (testbench -> DUT, delayed by INPUT_DELAY)

  logic                        dut_rst;
  logic                        dut_imem_req_rdy;
  logic                        dut_imem_resp_val;
  logic [p_imem_msg_bits-1:0]  dut_imem_resp_msg;
  logic                        dut_dmem_req_rdy;
  logic                        dut_dmem_resp_val;
  logic [p_dmem_msg_bits-1:0]  dut_dmem_resp_msg;

  //--------------------------------------------------------------------
  // Delayed input drives (testbench -> DUT)
  //--------------------------------------------------------------------

  assign #(`INPUT_DELAY) dut_rst           = rst;
  assign #(`INPUT_DELAY) dut_imem_req_rdy  = imem_intf.req_rdy;
  assign #(`INPUT_DELAY) dut_imem_resp_val = imem_intf.resp_val;
  assign #(`INPUT_DELAY) dut_imem_resp_msg = imem_intf.resp_msg;
  assign #(`INPUT_DELAY) dut_dmem_req_rdy  = dmem_intf[0].req_rdy;
  assign #(`INPUT_DELAY) dut_dmem_resp_val = dmem_intf[0].resp_val;
  assign #(`INPUT_DELAY) dut_dmem_resp_msg = dmem_intf[0].resp_msg;

  //--------------------------------------------------------------------
  // DUT instantiation
  //--------------------------------------------------------------------

  logic [p_num_be_lanes*32-1:0] dut_trace_pc;
  logic [p_num_be_lanes*5-1:0]  dut_trace_waddr;
  logic [p_num_be_lanes*32-1:0] dut_trace_wdata;
  logic [p_num_be_lanes-1:0]    dut_trace_wen;
  logic [p_num_be_lanes-1:0]    dut_trace_val;

  BlimpV11SynthWrap dut (
    .clk            (clk),
    .rst            (dut_rst),
    .imem_req_val   (imem_intf.req_val),
    .imem_req_rdy   (dut_imem_req_rdy),
    .imem_req_msg   (imem_intf.req_msg),
    .imem_resp_val  (dut_imem_resp_val),
    .imem_resp_rdy  (imem_intf.resp_rdy),
    .imem_resp_msg  (dut_imem_resp_msg),
    .dmem_req_val   (dmem_intf[0].req_val),
    .dmem_req_rdy   (dut_dmem_req_rdy),
    .dmem_req_msg   (dmem_intf[0].req_msg),
    .dmem_resp_val  (dut_dmem_resp_val),
    .dmem_resp_rdy  (dmem_intf[0].resp_rdy),
    .dmem_resp_msg  (dut_dmem_resp_msg),
    .trace_pc       (dut_trace_pc),
    .trace_waddr    (dut_trace_waddr),
    .trace_wdata    (dut_trace_wdata),
    .trace_wen      (dut_trace_wen),
    .trace_val      (dut_trace_val),
    .trace_seq_num  ()
  );

  // Unpack trace signals from packed DUT ports
  genvar ti;
  generate
    for( ti = 0; ti < p_num_be_lanes; ti++ ) begin: TRACE_UNPACK
      assign inst_trace_notif_pc[ti]    = dut_trace_pc   [ti*32 +: 32];
      assign inst_trace_notif_waddr[ti] = dut_trace_waddr[ti*5 +: 5];
      assign inst_trace_notif_wdata[ti] = dut_trace_wdata[ti*32 +: 32];
      assign inst_trace_notif_wen[ti]   = dut_trace_wen  [ti];
      assign inst_trace_notif_val[ti]   = dut_trace_val  [ti];
    end
  endgenerate

`else

  BlimpV11 #(
    .p_opaq_bits               (p_opaq_bits),
    .p_seq_num_bits            (p_seq_num_bits),
    .p_num_phys_regs           (p_num_phys_regs),
    .p_num_fe_lanes            (p_num_fe_lanes),
    .p_num_be_lanes            (p_num_be_lanes),
    .p_iq_depth                (p_iq_depth),
    .p_reclaim_width           (p_reclaim_width),
    .p_max_in_flight           (p_max_in_flight),
    .p_f_intf_fifo_depth       (p_f_intf_fifo_depth),
    .p_x_intf_fifo_depth       (p_x_intf_fifo_depth),
    .p_alu_d_intf_fifo_depth   (p_alu_d_intf_fifo_depth),
    .p_mul_d_intf_fifo_depth   (p_mul_d_intf_fifo_depth),
    .p_mem_d_intf_fifo_depth   (p_mem_d_intf_fifo_depth),
    .p_ctrl_d_intf_fifo_depth  (p_ctrl_d_intf_fifo_depth),
    .p_num_alus                (p_num_alus),
    .p_num_muls                (p_num_muls),
    .p_num_ldstrs              (p_num_ldstrs),
    .p_all_iq_in_order         (p_all_iq_in_order),
    .p_pipe_bypass             (p_pipe_bypass),
    .p_sim_f2d_bp              (p_sim_f2d_bp),
    .p_sim_d2x_bp              (p_sim_d2x_bp),
    .p_sim_x2w_bp              (p_sim_x2w_bp)
  ) dut (
    .inst_mem   (imem_intf),
    .data_mem   (dmem_intf),
    .inst_trace (inst_trace_notif),
    .*
  );

`endif

  //----------------------------------------------------------------------
  // FL Memory
  //----------------------------------------------------------------------

  MemIntfTestServer #(
    .t_req_msg         (`MEM_REQ_SS ( p_opaq_bits, p_num_fe_lanes )),
    .t_resp_msg        (`MEM_RESP_SS( p_opaq_bits, p_num_fe_lanes )),
    .p_send_intv_delay (p_mem_send_intv_delay),
    .p_recv_intv_delay (p_mem_recv_intv_delay),
    .p_opaq_bits       (p_opaq_bits),
    .p_num_words       (p_num_fe_lanes)
  ) fl_imem (
    .dut (imem_intf),
    .*
  );

  MemIntfTestServer #(
    .t_req_msg         (`MEM_REQ ( p_opaq_bits )),
    .t_resp_msg        (`MEM_RESP( p_opaq_bits )),
    .p_send_intv_delay (p_mem_send_intv_delay),
    .p_recv_intv_delay (p_mem_recv_intv_delay),
    .p_opaq_bits       (p_opaq_bits)
  ) fl_dmem (
    .dut (dmem_intf[0]),
    .*
  );

  logic [31:0] asm_binary;

  task asm(
    input logic [31:0] addr,
    input string       inst
  );
    asm_binary = assemble( inst, addr );
    fl_imem.init_mem( addr, asm_binary );
    fl_init         ( addr, asm_binary );
  endtask

  task data(
    input logic [31:0] addr,
    input logic [31:0] data
  );
    fl_dmem.init_mem( addr, data );
    fl_init         ( addr, data );
  endtask

  //----------------------------------------------------------------------
  // Instruction Tracing
  //----------------------------------------------------------------------

`ifndef VCS_ASIC
  genvar i;
  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign inst_trace_notif_pc[i]    = inst_trace_notif[i].pc;
      assign inst_trace_notif_waddr[i] = inst_trace_notif[i].waddr;
      assign inst_trace_notif_wdata[i] = inst_trace_notif[i].wdata;
      assign inst_trace_notif_wen[i]   = inst_trace_notif[i].wen;
      assign inst_trace_notif_val[i]   = inst_trace_notif[i].val;
    end
  endgenerate
`endif

`ifdef VCS_ASIC
  InstMTraceSub #(
    .p_num_lanes    (p_num_be_lanes),
    .p_sample_delay (`OUTPUT_DELAY)
  ) inst_trace_sub (
`else
  InstMTraceSub #(
    .p_num_lanes (p_num_be_lanes)
  ) inst_trace_sub (
`endif
    .pc    (inst_trace_notif_pc),
    .waddr (inst_trace_notif_waddr),
    .wdata (inst_trace_notif_wdata),
    .wen   (inst_trace_notif_wen),
    .val   (inst_trace_notif_val),
    .*
  );

  task check_trace(
    input logic [31:0] pc,
    input logic  [4:0] waddr,
    input logic [31:0] wdata,
    input logic        wen
  );

    inst_trace_sub.check_trace(
      pc,
      waddr,
      wdata,
      wen
    );
  endtask

  logic      check_traces_success;
  inst_trace check_traces_fl_trace;

  task check_traces();
    while( 1 ) begin
      check_traces_success = fl_trace( check_traces_fl_trace );
      if( !check_traces_success ) return;

      inst_trace_sub.check_trace(
        check_traces_fl_trace.pc,
        check_traces_fl_trace.waddr,
        check_traces_fl_trace.wdata,
        check_traces_fl_trace.wen
      );
    end
  endtask

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
`ifndef VCS_ASIC
    trace = {trace, dut.trace( t.trace_level )};
`endif
    trace = {trace, " || "};
    trace = {trace, inst_trace_sub.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ
endmodule

`endif // HW_TOP_TEST_BLIMPV11TESTHARNESS_V
