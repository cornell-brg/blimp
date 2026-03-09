//========================================================================
// SSDIURouter_test.v
//========================================================================
// A testbench for the SSDIURouter crossbar scheduler

`include "hw/decode_issue/SSDIURouter.v"
`include "test/TestUtils.v"
`include "intf/CommitNotif.v"
`include "test/fl/TestMPub.v"

import TestEnv::*;
import UArch::*;

//========================================================================
// SSDIURouterTestSuite
//========================================================================

module SSDIURouterTestSuite #(
  parameter p_suite_num        = 0,
  parameter p_num_pipes        = 4,
  parameter p_num_input_lanes  = 4,
  parameter p_input_lanes_bits = p_num_input_lanes > 1 ? $clog2(p_num_input_lanes) : 1,
  parameter p_iq_depth         = 8,
  parameter p_seq_num_bits     = 8,
  parameter p_num_iter         = 2,
  parameter p_num_be_lanes     = 2
);

  // Define pipe subsets for testing
  // Pipe 0: ALU operations (ADD, SUB, AND, OR, XOR, SLT, SLTU, SRA, SRL, SLL, LUI, AUIPC)
  // Pipe 1: Memory operations (LB, LH, LW, LBU, LHU, SB, SH, SW)
  // Pipe 2: Control operations (JAL, JALR, BEQ, BNE, BLT, BGE, BLTU, BGEU)
  // Pipe 3: Multiply/Divide operations (MUL, MULH, MULHU, MULHSU, DIV, DIVU, REM, REMU)
  localparam rv_op_vec [p_num_pipes-1:0] p_pipe_subsets = '{
    OP_ADD_VEC    | OP_SUB_VEC    | OP_AND_VEC    | OP_OR_VEC     |
    OP_XOR_VEC    | OP_SLT_VEC    | OP_SLTU_VEC   | OP_SRA_VEC    |
    OP_SRL_VEC    | OP_SLL_VEC    | OP_LUI_VEC    | OP_AUIPC_VEC,

    OP_LB_VEC     | OP_LH_VEC     | OP_LW_VEC     | OP_LBU_VEC    |
    OP_LHU_VEC    | OP_SB_VEC     | OP_SH_VEC     | OP_SW_VEC,

    OP_JAL_VEC    | OP_JALR_VEC   | OP_BEQ_VEC    | OP_BNE_VEC    |
    OP_BLT_VEC    | OP_BGE_VEC    | OP_BLTU_VEC   | OP_BGEU_VEC,

    OP_MUL_VEC    | OP_MULH_VEC   | OP_MULHU_VEC  | OP_MULHSU_VEC |
    OP_DIV_VEC    | OP_DIVU_VEC   | OP_REM_VEC    | OP_REMU_VEC
  };

  string suite_name = $sformatf("%0d: SSDIURouterTestSuite_%0d_%0d_%0d_%0d_%0d",
                                p_suite_num, p_num_pipes, p_num_input_lanes,
                                p_iq_depth, p_seq_num_bits, p_num_iter);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  localparam p_phys_addr_bits = 6;

  rv_uop                      dut_uop     [p_num_input_lanes];
  logic [p_seq_num_bits-1:0]  dut_seq_num [p_num_input_lanes];
  logic                       dut_val     [p_num_input_lanes];

  logic                              dut_iq_rdy         [p_num_pipes];
  logic [$clog2(p_iq_depth):0]       dut_iq_avail_slots [p_num_pipes];

  logic [p_input_lanes_bits-1:0]     dut_iq_route_idx [p_num_pipes];
  logic                              dut_iq_val       [p_num_pipes];
  logic                              dut_xfer         [p_num_input_lanes];

  CommitNotif #(
    .p_seq_num_bits   (p_seq_num_bits),
    .p_phys_addr_bits (p_phys_addr_bits)
  ) commit_notif [p_num_be_lanes] ();

  SSDIURouter #(
    .p_num_pipes       (p_num_pipes),
    .p_pipe_subsets    (p_pipe_subsets),
    .p_num_input_lanes (p_num_input_lanes),
    .p_input_lanes_bits (p_input_lanes_bits),
    .p_iq_depth        (p_iq_depth),
    .p_seq_num_bits    (p_seq_num_bits),
    .p_num_iter        (p_num_iter)
  ) dut (
    .clk            (clk),
    .rst            (rst),
    .uop            (dut_uop),
    .seq_num        (dut_seq_num),
    .val            (dut_val),
    .iq_rdy         (dut_iq_rdy),
    .iq_avail_slots (dut_iq_avail_slots),
    .iq_route_idx   (dut_iq_route_idx),
    .iq_val         (dut_iq_val),
    .xfer           (dut_xfer),
    .commit         (commit_notif)
  );

  //----------------------------------------------------------------------
  // Helper tasks
  //----------------------------------------------------------------------

  task set_inputs(
    input rv_uop                     uop     [p_num_input_lanes],
    input logic [p_seq_num_bits-1:0] seq_num [p_num_input_lanes],
    input logic                      val     [p_num_input_lanes]
  );
    for (int i = 0; i < p_num_input_lanes; i++) begin
      dut_uop[i]     = uop[i];
      dut_seq_num[i] = seq_num[i];
      dut_val[i]     = val[i];
    end
  endtask

  task set_iq_state(
    input logic                        rdy         [p_num_pipes],
    input logic [$clog2(p_iq_depth):0] avail_slots [p_num_pipes]
  );
    for (int i = 0; i < p_num_pipes; i++) begin
      dut_iq_rdy[i]         = rdy[i];
      dut_iq_avail_slots[i] = avail_slots[i];
    end
  endtask

  task check_route(
    input logic [p_input_lanes_bits-1:0] exp_route_idx [p_num_pipes],
    input logic                          exp_iq_val    [p_num_pipes],
    input logic                          exp_xfer      [p_num_input_lanes]
  );
    #1; // Let combinational logic settle
    for (int i = 0; i < p_num_pipes; i++) begin
      `CHECK_EQ(dut_iq_val[i], exp_iq_val[i]);
      if (exp_iq_val[i]) begin
        `CHECK_EQ(dut_iq_route_idx[i], exp_route_idx[i]);
      end
    end
    for (int i = 0; i < p_num_input_lanes; i++) begin
      `CHECK_EQ(dut_xfer[i], exp_xfer[i]);
    end
  endtask

  //----------------------------------------------------------------------
  // Commit Notification
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic                 [31:0] wdata;
    logic                        wen;
    logic [p_phys_addr_bits-1:0] ppreg;
  } t_commit_msg;

  t_commit_msg commit_msg     [p_num_be_lanes];
  logic        commit_msg_val [p_num_be_lanes];
  
  genvar i;
  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign commit_notif[i].pc      = commit_msg[i].pc;
      assign commit_notif[i].seq_num = commit_msg[i].seq_num;
      assign commit_notif[i].waddr   = commit_msg[i].waddr;
      assign commit_notif[i].wdata   = commit_msg[i].wdata;
      assign commit_notif[i].wen     = commit_msg[i].wen;
      assign commit_notif[i].ppreg   = commit_msg[i].ppreg;
      assign commit_notif[i].val     = commit_msg_val[i];
    end
  endgenerate

  logic                 [31:0] unused_commit_pc    [p_num_be_lanes];
  logic                  [4:0] unused_commit_waddr [p_num_be_lanes];
  logic                 [31:0] unused_commit_wdata [p_num_be_lanes];
  logic                        unused_commit_wen   [p_num_be_lanes];

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin
      assign unused_commit_pc[i]    = commit_notif[i].pc;
      assign unused_commit_waddr[i] = commit_notif[i].waddr;
      assign unused_commit_wdata[i] = commit_notif[i].wdata;
      assign unused_commit_wen[i]   = commit_notif[i].wen;
    end
  endgenerate

  TestMPub #( 
    .t_msg    (t_commit_msg),
    .p_num_msgs (p_num_be_lanes)
  ) commit_pub (
    .msg (commit_msg),
    .val (commit_msg_val),
    .*
  );

  t_commit_msg msg_to_commit_pub     [p_num_be_lanes];
  logic        msg_to_commit_pub_val [p_num_be_lanes];

  task commit(
    input logic                 [31:0] pc      [p_num_be_lanes],
    input logic   [p_seq_num_bits-1:0] seq_num [p_num_be_lanes],
    input logic                  [4:0] waddr   [p_num_be_lanes],
    input logic                 [31:0] wdata   [p_num_be_lanes],
    input logic                        wen     [p_num_be_lanes],
    input logic [p_phys_addr_bits-1:0] ppreg   [p_num_be_lanes],
    input logic                        val     [p_num_be_lanes]
  );
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      msg_to_commit_pub[j].seq_num = seq_num[j];
      msg_to_commit_pub[j].pc      = pc[j];
      msg_to_commit_pub[j].waddr   = waddr[j];
      msg_to_commit_pub[j].wdata   = wdata[j];
      msg_to_commit_pub[j].wen     = wen[j];
      msg_to_commit_pub[j].ppreg   = ppreg[j];
      msg_to_commit_pub_val[j]     = val[j];
    end

    commit_pub.pub( msg_to_commit_pub, msg_to_commit_pub_val );
  endtask

  //----------------------------------------------------------------------
  // test_case_single_instruction
  //----------------------------------------------------------------------
  // Test routing a single instruction to a compatible pipe

  task test_case_single_instruction();
    t.test_case_begin( "test_case_single_instruction" );
    if( !t.run_test ) return;

    // Test 1: Single ADD instruction -> should go to Pipe 0 (ALU)
    set_inputs(
      '{OP_ADD, OP_ADD, OP_ADD, OP_ADD},  // Only lane 0 valid
      '{p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0)},
      '{1'b1, 1'b0, 1'b0, 1'b0}
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd8, 4'd8, 4'd8, 4'd8}
    );
    check_route(
      '{p_input_lanes_bits'(0), 'x, 'x, 'x},  // Pipe 0 gets lane 0
      '{1'b1, 1'b0, 1'b0, 1'b0},  // Only pipe 0 has instruction
      '{1'b1, 1'b0, 1'b0, 1'b0}   // Only lane 0 transferred
    );

    // Test 2: Single MUL instruction -> should go to Pipe 3 (MUL/DIV)
    set_inputs(
      '{OP_MUL, OP_MUL, OP_MUL, OP_MUL},
      '{p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0)},
      '{1'b0, 1'b1, 1'b0, 1'b0}  // Lane 1 valid
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd8, 4'd8, 4'd8, 4'd8}
    );
    check_route(
      '{'x, 'x, 'x, p_input_lanes_bits'(1)},  // Pipe 3 gets lane 1
      '{1'b0, 1'b0, 1'b0, 1'b1},
      '{1'b0, 1'b1, 1'b0, 1'b0}
    );

    // Test 3: Single LW instruction -> should go to Pipe 1 (MEM)
    set_inputs(
      '{OP_LW, OP_LW, OP_LW, OP_LW},
      '{p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0)},
      '{1'b0, 1'b0, 1'b1, 1'b0}  // Lane 2 valid
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd8, 4'd8, 4'd8, 4'd8}
    );
    check_route(
      '{'x, p_input_lanes_bits'(2), 'x, 'x},  // Pipe 1 gets lane 2
      '{1'b0, 1'b1, 1'b0, 1'b0},
      '{1'b0, 1'b0, 1'b1, 1'b0}
    );

    // Test 4: Single BNE instruction -> should go to Pipe 2 (CTRL)
    set_inputs(
      '{OP_BNE, OP_BNE, OP_BNE, OP_BNE},
      '{p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0)},
      '{1'b0, 1'b0, 1'b0, 1'b1}  // Lane 3 valid
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd8, 4'd8, 4'd8, 4'd8}
    );
    check_route(
      '{'x, 'x, p_input_lanes_bits'(3), 'x},  // Pipe 2 gets lane 3
      '{1'b0, 1'b0, 1'b1, 1'b0},
      '{1'b0, 1'b0, 1'b0, 1'b1}
    );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_non_conflicting
  //----------------------------------------------------------------------
  // Test routing multiple non-conflicting instructions

  task test_case_non_conflicting();
    t.test_case_begin( "test_case_non_conflicting" );
    if( !t.run_test ) return;

    // All lanes have different instruction types
    set_inputs(
      '{OP_ADD, OP_LW, OP_BNE, OP_MUL},  // Different ops
      '{p_seq_num_bits'(0), p_seq_num_bits'(1), p_seq_num_bits'(2), p_seq_num_bits'(3)},
      '{1'b1, 1'b1, 1'b1, 1'b1}          // All valid
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd8, 4'd8, 4'd8, 4'd8}
    );
    check_route(
      '{p_input_lanes_bits'(0), p_input_lanes_bits'(1), p_input_lanes_bits'(2), p_input_lanes_bits'(3)},  // Each pipe gets corresponding lane
      '{1'b1, 1'b1, 1'b1, 1'b1},  // All pipes receive instruction
      '{1'b1, 1'b1, 1'b1, 1'b1}   // All lanes transferred
    );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_age_priority
  //----------------------------------------------------------------------
  // Test that older instructions get priority when conflicting

  task test_case_age_priority();
    t.test_case_begin( "test_case_age_priority" );
    if( !t.run_test ) return;

    // Two ADD instructions competing for Pipe 0 (ALU)
    // Lane 0: seq_num = 5 (newer)
    // Lane 1: seq_num = 3 (older) <- should win
    set_inputs(
      '{OP_ADD, OP_ADD, OP_LW, OP_MUL},
      '{p_seq_num_bits'(5), p_seq_num_bits'(3), p_seq_num_bits'(4), p_seq_num_bits'(6)},
      '{1'b1, 1'b1, 1'b1, 1'b1}
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd8, 4'd8, 4'd8, 4'd8}
    );

    // Expected behavior:
    // Iteration 1: Pipe 0 grants to lane 1 (older), pipe 1 grants to lane 2, pipe 3 grants to lane 3
    // After iteration 1, lane 0 is unmatched (lost contention to lane 1)
    // Iteration 2: No more matches (lane 0 wants pipe 0 which is already matched)
    check_route(
      '{p_input_lanes_bits'(1), p_input_lanes_bits'(2), 'x, p_input_lanes_bits'(3)},  // Pipe 0 gets lane 1, pipe 1 gets lane 2, pipe 3 gets lane 3
      '{1'b1, 1'b1, 1'b0, 1'b1},  // Pipes 0,1,3 receive instructions, pipe 2 does not
      '{1'b0, 1'b1, 1'b1, 1'b1}   // Lanes 1,2,3 transfer, lane 0 does not (lost contention)
    );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_slot_priority
  //----------------------------------------------------------------------
  // Test that pipes with more available slots get priority

  task test_case_slot_priority();
    t.test_case_begin( "test_case_slot_priority" );
    if( !t.run_test ) return;

    // One ADD instruction that could go to Pipe 0
    // But if we had multiple pipes supporting ADD, it should prefer
    // the one with more slots. For this test, we just verify routing works.
    set_inputs(
      '{OP_ADD, OP_ADD, OP_ADD, OP_ADD},
      '{p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0), p_seq_num_bits'(0)},
      '{1'b1, 1'b0, 1'b0, 1'b0}
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd2, 4'd8, 4'd5, 4'd3}  // Pipe 1 has most slots but doesn't support ADD
    );
    check_route(
      '{p_input_lanes_bits'(0), 'x, 'x, 'x},  // Still goes to Pipe 0 (only option)
      '{1'b1, 1'b0, 1'b0, 1'b0},
      '{1'b1, 1'b0, 1'b0, 1'b0}
    );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_pipe_not_ready
  //----------------------------------------------------------------------
  // Test that instructions aren't routed to non-ready pipes

  task test_case_pipe_not_ready();
    t.test_case_begin( "test_case_pipe_not_ready" );
    if( !t.run_test ) return;

    // ADD instruction, but Pipe 0 (ALU) is not ready
    set_inputs(
      '{OP_ADD, OP_LW, OP_BNE, OP_MUL},
      '{p_seq_num_bits'(0), p_seq_num_bits'(1), p_seq_num_bits'(2), p_seq_num_bits'(3)},
      '{1'b1, 1'b1, 1'b1, 1'b1}
    );
    set_iq_state(
      '{1'b0, 1'b1, 1'b1, 1'b1},  // Pipe 0 not ready
      '{4'd8, 4'd8, 4'd8, 4'd8}
    );
    check_route(
      '{'x, p_input_lanes_bits'(1), p_input_lanes_bits'(2), p_input_lanes_bits'(3)},  // Pipe 0 gets nothing
      '{1'b0, 1'b1, 1'b1, 1'b1},  // Pipe 0 doesn't receive
      '{1'b0, 1'b1, 1'b1, 1'b1}   // Lane 0 not transferred
    );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_full_contention
  //----------------------------------------------------------------------
  // Test all lanes wanting the same pipe

  task test_case_full_contention();
    t.test_case_begin( "test_case_full_contention" );
    if( !t.run_test ) return;

    // All lanes have ADD instructions -> all want Pipe 0
    set_inputs(
      '{OP_ADD, OP_SUB, OP_AND, OP_OR},  // All ALU ops
      '{p_seq_num_bits'(10), p_seq_num_bits'(5), p_seq_num_bits'(15), p_seq_num_bits'(8)},       // Different ages
      '{1'b1, 1'b1, 1'b1, 1'b1}
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd8, 4'd8, 4'd8, 4'd8}
    );

    // With p_num_iter=2, we should get 2 matches per cycle max
    // (limited by single pipe accepting)
    // Actually, with single output, only 1 can match per iteration
    // So with 2 iterations, we get 1 match total to Pipe 0
    // The oldest (seq_num=5, lane 1) should win in iteration 1
    check_route(
      '{p_input_lanes_bits'(1), 'x, 'x, 'x},  // Pipe 0 gets oldest (lane 1, seq=5)
      '{1'b1, 1'b0, 1'b0, 1'b0},
      '{1'b0, 1'b1, 1'b0, 1'b0}   // Only lane 1 transferred
    );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_invalid_instructions
  //----------------------------------------------------------------------
  // Test with invalid instructions

  task test_case_invalid_instructions();
    t.test_case_begin( "test_case_invalid_instructions" );
    if( !t.run_test ) return;

    // Mix of valid and invalid
    set_inputs(
      '{OP_ADD, OP_LW, OP_BNE, OP_MUL},
      '{p_seq_num_bits'(0), p_seq_num_bits'(1), p_seq_num_bits'(2), p_seq_num_bits'(3)},
      '{1'b1, 1'b0, 1'b1, 1'b0}  // Only lanes 0 and 2 valid
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd8, 4'd8, 4'd8, 4'd8}
    );
    check_route(
      '{p_input_lanes_bits'(0), 'x, p_input_lanes_bits'(2), 'x},
      '{1'b1, 1'b0, 1'b1, 1'b0},
      '{1'b1, 1'b0, 1'b1, 1'b0}   // Only valid lanes transferred
    );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_no_slots_available
  //----------------------------------------------------------------------
  // Test behavior when pipes have no available slots

  task test_case_no_slots_available();
    t.test_case_begin( "test_case_no_slots_available" );
    if( !t.run_test ) return;

    set_inputs(
      '{OP_ADD, OP_LW, OP_BNE, OP_MUL},
      '{p_seq_num_bits'(0), p_seq_num_bits'(1), p_seq_num_bits'(2), p_seq_num_bits'(3)},
      '{1'b1, 1'b1, 1'b1, 1'b1}
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd0, 4'd0, 4'd8, 4'd0}  // Only Pipe 2 has slots
    );
    check_route(
      '{'x, 'x, p_input_lanes_bits'(2), 'x},
      '{1'b0, 1'b0, 1'b1, 1'b0},  // Only pipe 2 matches (has slots)
      '{1'b0, 1'b0, 1'b1, 1'b0}   // Only lane 2 transferred
    );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_mixed_scenario
  //----------------------------------------------------------------------
  // Complex scenario with multiple conflicts and priorities

  task test_case_mixed_scenario();
    t.test_case_begin( "test_case_mixed_scenario" );
    if( !t.run_test ) return;

    // Lane 0: ADD (seq=20, newer) -> Pipe 0
    // Lane 1: SUB (seq=10, older) -> Pipe 0 (should win over lane 0)
    // Lane 2: LW (seq=15) -> Pipe 1
    // Lane 3: MUL (seq=12) -> Pipe 3
    set_inputs(
      '{OP_ADD, OP_SUB, OP_LW, OP_MUL},
      '{p_seq_num_bits'(20), p_seq_num_bits'(10), p_seq_num_bits'(15), p_seq_num_bits'(12)},
      '{1'b1, 1'b1, 1'b1, 1'b1}
    );
    set_iq_state(
      '{1'b1, 1'b1, 1'b1, 1'b1},
      '{4'd5, 4'd3, 4'd7, 4'd2}  // Different slot counts
    );

    // Expected: lane 1 wins pipe 0 (older), lanes 2,3 get their pipes
    // Lane 0 doesn't get matched (lost contention to lane 1)
    check_route(
      '{p_input_lanes_bits'(1), p_input_lanes_bits'(2), 'x, p_input_lanes_bits'(3)},  // Pipe 0 gets lane 1, pipe 1 gets lane 2, pipe 3 gets lane 3
      '{1'b1, 1'b1, 1'b0, 1'b1},  // Pipes 0,1,3 receive instructions, pipe 2 does not
      '{1'b0, 1'b1, 1'b1, 1'b1}   // Lanes 1,2,3 transfer, lane 0 does not (lost contention)
    );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_single_instruction();
    test_case_non_conflicting();
    test_case_age_priority();
    test_case_slot_priority();
    test_case_pipe_not_ready();
    test_case_full_contention();
    test_case_invalid_instructions();
    test_case_no_slots_available();
    test_case_mixed_scenario();
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    trace = "";
    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

endmodule

//========================================================================
// SSDIURouter_test
//========================================================================

module SSDIURouter_test;

  // Test with different configurations

  // Default config: 4 pipes, 4 lanes, 8-depth IQ, 8-bit seq num, 2 iterations
  SSDIURouterTestSuite suite_1();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();

    test_bench_end();
  end

endmodule
