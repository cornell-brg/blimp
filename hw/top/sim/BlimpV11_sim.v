//========================================================================
// BlimpV11_sim.v
//========================================================================
// A module for simulating BlimpV11

`include "asm/assemble.v"
`ifndef VCS_ASIC
`include "hw/top/BlimpV11.v"
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
`ifndef P_NUM_FE_LANES
  `define P_NUM_FE_LANES            2
`endif
`ifndef P_NUM_BE_LANES
  `define P_NUM_BE_LANES            2
`endif
`ifndef P_IQ_DEPTH
  `define P_IQ_DEPTH                4
`endif
`ifndef P_RECLAIM_WIDTH
  `define P_RECLAIM_WIDTH           4
`endif
`ifndef P_MAX_IN_FLIGHT
  `define P_MAX_IN_FLIGHT           4
`endif
`ifndef P_F_INTF_FIFO_DEPTH
  `define P_F_INTF_FIFO_DEPTH       1
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
`ifndef P_ALL_IQ_IN_ORDER
  `define P_ALL_IQ_IN_ORDER         0
`endif
`ifndef P_NUM_ALUS
  `define P_NUM_ALUS                2
`endif
`ifndef P_NUM_MULS
  `define P_NUM_MULS                1
`endif
`ifndef P_NUM_LDSTRS
  `define P_NUM_LDSTRS              1
`endif
`ifndef P_PIPE_BYPASS
  `define P_PIPE_BYPASS             'b11111
`endif

module BlimpV11_sim;

  // Define default simulation parameters
  localparam p_opaq_bits               = `P_OPAQ_BITS;
  localparam p_seq_num_bits            = `P_SEQ_NUM_BITS;
  localparam p_num_phys_regs           = `P_NUM_PHYS_REGS;
  localparam p_num_fe_lanes            = `P_NUM_FE_LANES;
  localparam p_num_be_lanes            = `P_NUM_BE_LANES;
  localparam p_iq_depth                = `P_IQ_DEPTH;
  localparam p_reclaim_width           = `P_RECLAIM_WIDTH;
  localparam p_max_in_flight           = `P_MAX_IN_FLIGHT;
  localparam p_f_intf_fifo_depth       = `P_F_INTF_FIFO_DEPTH;
  localparam p_x_intf_fifo_depth       = `P_X_INTF_FIFO_DEPTH;
  localparam p_alu_d_intf_fifo_depth   = `P_ALU_D_INTF_FIFO_DEPTH;
  localparam p_mul_d_intf_fifo_depth   = `P_MUL_D_INTF_FIFO_DEPTH;
  localparam p_mem_d_intf_fifo_depth   = `P_MEM_D_INTF_FIFO_DEPTH;
  localparam p_ctrl_d_intf_fifo_depth  = `P_CTRL_D_INTF_FIFO_DEPTH;
  localparam p_num_alus                = `P_NUM_ALUS;
  localparam p_num_muls                = `P_NUM_MULS;
  localparam p_num_ldstrs              = `P_NUM_LDSTRS;
  localparam p_all_iq_in_order         = `P_ALL_IQ_IN_ORDER;
  localparam p_pipe_bypass             = `P_PIPE_BYPASS;
  localparam p_num_pipes               = p_num_alus + p_num_muls + p_num_ldstrs + 1;

  // Simulation-only backpressure: 8 bits per lane/pipe (stall 1/N; 0 = off)
  //                                        lane3  lane2  lane1  lane0
  // localparam [p_num_fe_lanes*8-1:0] p_sim_f2d_bp = {8'd0,  8'd0,  8'd0,  8'd0};
  localparam [p_num_fe_lanes*8-1:0] p_sim_f2d_bp = '0;
  //                                        ctrl   mem    mul1   mul0   alu3   alu2   alu1   alu0
  // localparam [p_num_pipes*8-1:0]    p_sim_d2x_bp = {8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0};
  // localparam [p_num_pipes*8-1:0]    p_sim_x2w_bp = {8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0};
  localparam [p_num_pipes*8-1:0]    p_sim_d2x_bp = '0;
  localparam [p_num_pipes*8-1:0]    p_sim_x2w_bp = '0;
  
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
  ) dmem_intf [1]();

  InstTraceNotif #(
    .p_seq_num_bits (p_seq_num_bits)
  ) inst_trace_notif [p_num_be_lanes]();

  logic [31:0]               inst_trace_pc      [p_num_be_lanes];
  logic  [4:0]               inst_trace_waddr   [p_num_be_lanes];
  logic [31:0]               inst_trace_wdata   [p_num_be_lanes];
  logic                      inst_trace_wen     [p_num_be_lanes];
  logic                      inst_trace_val     [p_num_be_lanes];
  logic [p_seq_num_bits-1:0] inst_trace_seq_num [p_num_be_lanes];

`ifdef VCS_ASIC

  `ifndef INPUT_DELAY
    `define INPUT_DELAY  0.1
  `endif
  `ifndef OUTPUT_DELAY
    `define OUTPUT_DELAY 0.1
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

  logic [p_num_be_lanes*32-1:0]             dut_trace_pc;
  logic [p_num_be_lanes*5-1:0]              dut_trace_waddr;
  logic [p_num_be_lanes*32-1:0]             dut_trace_wdata;
  logic [p_num_be_lanes-1:0]                dut_trace_wen;
  logic [p_num_be_lanes-1:0]                dut_trace_val;
  logic [p_num_be_lanes*p_seq_num_bits-1:0] dut_trace_seq_num;

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
    .trace_seq_num  (dut_trace_seq_num)
  );

  // Unpack trace signals from packed DUT ports
  genvar ti;
  generate
    for( ti = 0; ti < p_num_be_lanes; ti++ ) begin: TRACE_UNPACK
      assign inst_trace_pc[ti]      = dut_trace_pc      [ti*32 +: 32];
      assign inst_trace_waddr[ti]   = dut_trace_waddr   [ti*5 +: 5];
      assign inst_trace_wdata[ti]   = dut_trace_wdata   [ti*32 +: 32];
      assign inst_trace_wen[ti]     = dut_trace_wen      [ti];
      assign inst_trace_val[ti]     = dut_trace_val      [ti];
      assign inst_trace_seq_num[ti] = dut_trace_seq_num  [ti*p_seq_num_bits +: p_seq_num_bits];
    end
  endgenerate

`else

  BlimpV11 #(
    .p_opaq_bits              (p_opaq_bits),
    .p_seq_num_bits           (p_seq_num_bits),
    .p_num_phys_regs          (p_num_phys_regs),
    .p_num_fe_lanes           (p_num_fe_lanes),
    .p_num_be_lanes           (p_num_be_lanes),
    .p_iq_depth               (p_iq_depth),
    .p_reclaim_width          (p_reclaim_width),
    .p_max_in_flight          (p_max_in_flight),
    .p_f_intf_fifo_depth      (p_f_intf_fifo_depth),
    .p_x_intf_fifo_depth      (p_x_intf_fifo_depth),
    .p_alu_d_intf_fifo_depth  (p_alu_d_intf_fifo_depth),
    .p_mul_d_intf_fifo_depth  (p_mul_d_intf_fifo_depth),
    .p_mem_d_intf_fifo_depth  (p_mem_d_intf_fifo_depth),
    .p_ctrl_d_intf_fifo_depth (p_ctrl_d_intf_fifo_depth),
    .p_num_alus               (p_num_alus),
    .p_num_muls               (p_num_muls),
    .p_num_ldstrs             (p_num_ldstrs),
    .p_all_iq_in_order        (p_all_iq_in_order),
    .p_pipe_bypass            (p_pipe_bypass),
    .p_sim_f2d_bp             (p_sim_f2d_bp),
    .p_sim_d2x_bp             (p_sim_d2x_bp),
    .p_sim_x2w_bp             (p_sim_x2w_bp)
  ) dut (
    .inst_mem   (imem_intf),
    .data_mem   (dmem_intf),
    .inst_trace (inst_trace_notif),
    .*
  );

  genvar i;
  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin : GEN_INST_TRACE_ASSIGN
      assign inst_trace_pc[i]      = inst_trace_notif[i].pc;
      assign inst_trace_waddr[i]   = inst_trace_notif[i].waddr;
      assign inst_trace_wdata[i]   = inst_trace_notif[i].wdata;
      assign inst_trace_wen[i]     = inst_trace_notif[i].wen;
      assign inst_trace_val[i]     = inst_trace_notif[i].val;
      assign inst_trace_seq_num[i] = inst_trace_notif[i].seq_num;
    end
  endgenerate

`endif

  always @( posedge clk ) begin
    `ifndef VCS_ASIC
    #1;
    `else
    #(`CYCLE_TIME-`INPUT_DELAY);
    `endif
    begin
      int num_committed;
      num_committed = 0;
      for( int j = 0; j < p_num_be_lanes; j++ ) begin
        if( inst_trace_val[j] ) begin
          num_committed = num_committed + 1;
          t.inst_trace(
            inst_trace_pc[j],
            inst_trace_waddr[j],
            inst_trace_wdata[j],
            inst_trace_wen[j]
          );
        end
      end
      if( num_committed > 0 ) begin
        t.commit_notify( num_committed );
        fl_dmem.notify_commit( num_committed );
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

`ifndef VCS_ASIC
      // Processor pipeline
      json_line = {json_line, ",", dut.trace_json()};
`endif

      // Committed instructions
      commit_json = "";
      for( int j = 0; j < p_num_be_lanes; j++ ) begin
        if( inst_trace_val[j] ) begin
          if( commit_json != "" )
            commit_json = {commit_json, ","};
          if( inst_trace_wen[j] )
            commit_json = {commit_json, $sformatf("{\"pc\":\"%h\",\"seq\":\"%h\",\"wdata\":\"%h\",\"waddr\":\"%0d\"}",
              inst_trace_pc[j], inst_trace_seq_num[j], inst_trace_wdata[j], inst_trace_waddr[j])};
          else
            commit_json = {commit_json, $sformatf("{\"pc\":\"%h\",\"seq\":\"%h\",\"wdata\":null,\"waddr\":null}",
              inst_trace_pc[j], inst_trace_seq_num[j])};
        end
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
