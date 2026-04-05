//========================================================================
// BlimpV8_sim.v
//========================================================================
// A module for simulating BlimpV8

`include "asm/assemble.v"
`ifndef VCS_ASIC
`include "hw/top/BlimpV8.v"
`endif
`include "hw/top/sim/utils/SimUtils.v"
`include "intf/MemIntf.v"
`include "intf/InstTraceNotif.v"
`include "test/fl/MemIntfTestServer.v"

import "DPI-C" context function void load_elf ( string elf_file );

`ifndef P_OPAQ_BITS
  `define P_OPAQ_BITS               8
`endif
`ifndef P_SEQ_NUM_BITS
  `define P_SEQ_NUM_BITS            5
`endif
`ifndef P_NUM_PHYS_REGS
  `define P_NUM_PHYS_REGS           36
`endif
`ifndef P_RECLAIM_WIDTH
  `define P_RECLAIM_WIDTH           4
`endif
`ifndef P_MAX_IN_FLIGHT
  `define P_MAX_IN_FLIGHT           2
`endif
`ifndef P_X_INTF_FIFO_DEPTH
  `define P_X_INTF_FIFO_DEPTH       1
`endif
`ifndef P_ALU_D_INTF_FIFO_DEPTH
  `define P_ALU_D_INTF_FIFO_DEPTH   1
`endif
`ifndef P_MUL_D_INTF_FIFO_DEPTH
  `define P_MUL_D_INTF_FIFO_DEPTH   1
`endif
`ifndef P_MEM_D_INTF_FIFO_DEPTH
  `define P_MEM_D_INTF_FIFO_DEPTH   1
`endif
`ifndef P_CTRL_D_INTF_FIFO_DEPTH
  `define P_CTRL_D_INTF_FIFO_DEPTH  1
`endif
`ifndef P_NUM_ALUS
  `define P_NUM_ALUS                1
`endif
`ifndef P_NUM_MULS
  `define P_NUM_MULS                1
`endif
`ifndef P_NUM_LDSTRS
  `define P_NUM_LDSTRS              1
`endif

module BlimpV8_sim;

  // Define default simulation parameters
  localparam p_opaq_bits              = `P_OPAQ_BITS;
  localparam p_seq_num_bits           = `P_SEQ_NUM_BITS;
  localparam p_num_phys_regs          = `P_NUM_PHYS_REGS;
  localparam p_reclaim_width          = `P_RECLAIM_WIDTH;
  localparam p_max_in_flight          = `P_MAX_IN_FLIGHT;
  localparam p_x_intf_fifo_depth      = `P_X_INTF_FIFO_DEPTH;
  localparam p_alu_d_intf_fifo_depth  = `P_ALU_D_INTF_FIFO_DEPTH;
  localparam p_mul_d_intf_fifo_depth  = `P_MUL_D_INTF_FIFO_DEPTH;
  localparam p_mem_d_intf_fifo_depth  = `P_MEM_D_INTF_FIFO_DEPTH;
  localparam p_ctrl_d_intf_fifo_depth = `P_CTRL_D_INTF_FIFO_DEPTH;
  localparam p_num_alus               = `P_NUM_ALUS;
  localparam p_num_muls               = `P_NUM_MULS;
  localparam p_num_ldstrs             = `P_NUM_LDSTRS;
  localparam p_num_pipes              = p_num_alus + p_num_muls + p_num_ldstrs + 1;

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
  ) imem_intf();

  MemIntf #(
    .p_opaq_bits (p_opaq_bits)
  ) dmem_intf [1]();

  InstTraceNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) inst_trace_notif();

  logic [31:0]               inst_trace_pc;
  logic  [4:0]               inst_trace_waddr;
  logic [31:0]               inst_trace_wdata;
  logic                      inst_trace_wen;
  logic                      inst_trace_val;
  logic [p_seq_num_bits-1:0] inst_trace_seq_num;

`ifdef VCS_ASIC

  `ifndef INPUT_DELAY
    `define INPUT_DELAY  0.1
  `endif
  `ifndef OUTPUT_DELAY
    `define OUTPUT_DELAY 0.1
  `endif

  // Derived message bit widths (must match BlimpV8SynthWrap)

  localparam p_imem_data_bits = 32;
  localparam p_imem_strb_bits = 4;
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

  BlimpV8SynthWrap dut (
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
    .trace_pc       (inst_trace_pc),
    .trace_waddr    (inst_trace_waddr),
    .trace_wdata    (inst_trace_wdata),
    .trace_wen      (inst_trace_wen),
    .trace_val      (inst_trace_val),
    .trace_seq_num  (inst_trace_seq_num)
  );

`else

  BlimpV8 #(
    .p_opaq_bits              (p_opaq_bits),
    .p_seq_num_bits           (p_seq_num_bits),
    .p_num_phys_regs          (p_num_phys_regs),
    .p_reclaim_width          (p_reclaim_width),
    .p_max_in_flight          (p_max_in_flight),
    .p_x_intf_fifo_depth      (p_x_intf_fifo_depth),
    .p_alu_d_intf_fifo_depth  (p_alu_d_intf_fifo_depth),
    .p_mul_d_intf_fifo_depth  (p_mul_d_intf_fifo_depth),
    .p_mem_d_intf_fifo_depth  (p_mem_d_intf_fifo_depth),
    .p_ctrl_d_intf_fifo_depth (p_ctrl_d_intf_fifo_depth),
    .p_num_alus               (p_num_alus),
    .p_num_muls               (p_num_muls),
    .p_num_ldstrs             (p_num_ldstrs)
  ) dut (
    .inst_mem   (imem_intf),
    .data_mem   (dmem_intf),
    .inst_trace (inst_trace_notif),
    .*
  );

  assign inst_trace_pc      = inst_trace_notif.pc;
  assign inst_trace_waddr   = inst_trace_notif.waddr;
  assign inst_trace_wdata   = inst_trace_notif.wdata;
  assign inst_trace_wen     = inst_trace_notif.wen;
  assign inst_trace_val     = inst_trace_notif.val;
  assign inst_trace_seq_num = inst_trace_notif.seq_num;

`endif

  always @( posedge clk ) begin
    `ifndef VCS_ASIC
    #1;
    `else
    #(`CYCLE_TIME-`INPUT_DELAY);
    `endif
    if( inst_trace_val ) begin
      t.inst_trace(
        inst_trace_pc,
        inst_trace_waddr,
        inst_trace_wdata,
        inst_trace_wen
      );
      t.commit_notify( 1 );
      fl_dmem.notify_commit( 1 );
    end
  end

  //----------------------------------------------------------------------
  // FL Memory
  //----------------------------------------------------------------------

  MemIntfTestServer #(
    .t_req_msg         (`MEM_REQ ( p_opaq_bits )),
    .t_resp_msg        (`MEM_RESP( p_opaq_bits )),
    .p_send_intv_delay ( 1 ),
    .p_recv_intv_delay ( 1 ),
    .p_opaq_bits       (p_opaq_bits)
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
    .dut (dmem_intf[0]),
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
    #(`CYCLE_TIME-1);
    trace = "";

    trace = {trace, fl_imem.trace( t.trace_level )};
    trace = {trace, " || "};
    trace = {trace, fl_dmem.trace( t.trace_level )};
    trace = {trace, " || "};
`ifndef VCS_ASIC
    trace = {trace, dut.trace( t.trace_level )};
`endif
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
  // JSON Tracing
  //----------------------------------------------------------------------

  string json_line;
  string commit_json;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #(`CYCLE_TIME-1);
    if( t.dump_json & !rst ) begin
      json_line = $sformatf("{\"cycle\":%0d", t.cycles);

      // Memory interfaces
      json_line = {json_line, ",", fl_imem.trace_json("imem")};
      json_line = {json_line, ",", fl_dmem.trace_json("dmem")};

// `ifndef VCS_ASIC
//       // Processor pipeline
//       json_line = {json_line, ",", dut.trace_json()};
// `endif

      // Committed instructions
      commit_json = "";
      if( inst_trace_val ) begin
        if( inst_trace_wen )
          commit_json = {commit_json, $sformatf("{\"pc\":\"%h\",\"seq\":\"%h\",\"wdata\":\"%h\",\"waddr\":\"%0d\"}",
            inst_trace_pc, inst_trace_seq_num, inst_trace_wdata, inst_trace_waddr)};
        else
          commit_json = {commit_json, $sformatf("{\"pc\":\"%h\",\"seq\":\"%h\",\"wdata\":null,\"waddr\":null}",
            inst_trace_pc, inst_trace_seq_num)};
      end
      if( commit_json != "" )
        json_line = {json_line, ",\"commit\":[", commit_json, "]"};
      else
        json_line = {json_line, ",\"commit\":[]"};

      json_line = {json_line, "}"};
      $fwrite(t.json_fd, "%s\n", json_line);
    end
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // SAIF Dumping
  //----------------------------------------------------------------------

`ifdef VTB_DUMP_SAIF
  `define STRINGIFY(x) `"x`"
`endif

  //----------------------------------------------------------------------
  // Run the simulation
  //----------------------------------------------------------------------

  initial begin
`ifdef VTB_DUMP_SAIF
    $set_gate_level_monitoring("on");
    $set_toggle_region(dut);
    $toggle_start;
    $display("SAIF dumping enabled: dumping to %s", `STRINGIFY(`VTB_DUMP_SAIF));
`endif
    t.sim_begin();
    load_elf( t.elf_file );
  end

`ifdef VTB_DUMP_SAIF
  final begin
    $toggle_stop;
    $toggle_report(`STRINGIFY(`VTB_DUMP_SAIF), 1e-12, dut);
    $display("SAIF dumping complete");
  end
`endif

endmodule
