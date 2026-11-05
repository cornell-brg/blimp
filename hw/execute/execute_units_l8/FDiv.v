//========================================================================
// FDIV_test.v
//========================================================================
// A testbench for our floating point division operation
//========================================================================

`include "defs/UArch.v"
`include "hw/execute/execute_units_l8/FDiv.v"
`include "hw/execute/test/test_cases/adder_intf.sv"
`include "hw/execute/test/test_cases/fdiv_cov.sv"
`include "test/fl/TestIstream.v"
`include "test/fl/TestOstream.v"

import UArch::*;
import TestEnv::*;

//========================================================================
// FDIVTestSuite
//========================================================================

module FDIVTestSuite #(
  parameter p_suite_num    = 0,
  parameter p_seq_num_bits = 5,

  parameter p_D_send_intv_delay = 0,
  parameter p_W_recv_intv_delay = 0
);

  //verilator lint_off UNUSEDSIGNAL
  string suite_name = $sformatf("%0d: FDIVTestSuite_%0d_%0d_%0d",
                                p_suite_num, p_seq_num_bits,
                                p_D_send_intv_delay, p_W_recv_intv_delay);
  //verilator lint_on UNUSEDSIGNAL

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  logic clk, rst;
  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  D__XIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) D__X_intf();

  X__WIntf #(
    .p_seq_num_bits (p_seq_num_bits)
  ) X__W_intf();

  adder_intf adder_intf_inst(clk);

  FDiv dut
  (
    .D (D__X_intf),
    .W (X__W_intf),
    .*
  );

  //----------------------------------------------------------------------
  // Coverage probes (reuse adder_intf)
  //----------------------------------------------------------------------
  // Operand fields come straight from the registered input (dut.D_reg),
  // which is held until the result is accepted. Rounding/flow signals come
  // from FPRound and are only meaningful once the result is ready in DONE
  // on the non-special path, so they are gated with res_ok.

  wire        in_val = dut.D_reg.val;
  wire [31:0] op1    = dut.D_reg.op1;
  wire [31:0] op2    = dut.D_reg.op2;
  wire        res_ok = X__W_intf.val && !dut.is_special_case_reg;

  assign adder_intf_inst.reset               = rst;

  // {sign, exponent}
  assign adder_intf_inst.signed_exponent_one = op1[31:23];
  assign adder_intf_inst.signed_exponent_two = op2[31:23];
  assign adder_intf_inst.mantissa_one        = op1[22:0];
  assign adder_intf_inst.mantissa_two        = op2[22:0];
  assign adder_intf_inst.sign_one            = op1[31];
  assign adder_intf_inst.sign_two            = op2[31];

  // Input classification
  assign adder_intf_inst.internal_denorm_one = in_val && (op1[30:23] == 8'h00) && (op1[22:0] != 23'h0);
  assign adder_intf_inst.internal_denorm_two = in_val && (op2[30:23] == 8'h00) && (op2[22:0] != 23'h0);
  assign adder_intf_inst.internal_nan_one    = in_val && (op1[30:23] == 8'hFF) && (op1[22:0] != 23'h0);
  assign adder_intf_inst.internal_nan_two    = in_val && (op2[30:23] == 8'hFF) && (op2[22:0] != 23'h0);
  assign adder_intf_inst.is_inf_one          = in_val && (op1[30:23] == 8'hFF) && (op1[22:0] == 23'h0);
  assign adder_intf_inst.is_inf_two          = in_val && (op2[30:23] == 8'hFF) && (op2[22:0] == 23'h0);

  // Rounding bits (from FPRound)
  assign adder_intf_inst.internal_ground     = res_ok && dut.fp_round_inst.guard;
  assign adder_intf_inst.internal_roundb     = res_ok && dut.fp_round_inst.round;
  assign adder_intf_inst.internal_sticky     = res_ok && dut.fp_round_inst.sticky;
  assign adder_intf_inst.internal_last_bit_mantissa = res_ok && dut.fp_round_inst.mant[0];
  assign adder_intf_inst.rounding_norm       = res_ok && dut.fp_round_inst.mant_sum[24];

  // Overflow / underflow (as decided inside FPRound, after spillover)
  assign adder_intf_inst.underflow           = res_ok && (dut.fp_round_inst.exp_post < 10'd1);
  assign adder_intf_inst.overflow            = res_ok && (dut.fp_round_inst.exp_post > 10'd254);

  `ifndef VERILATOR
  fp_division_cov cvg = new(adder_intf_inst);
  `endif

  //----------------------------------------------------------------------
  // FL D Interface
  //----------------------------------------------------------------------

  typedef struct packed {
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
    logic               [31:0] op1;
    logic               [31:0] op2;
    logic                [4:0] waddr;
    rv_uop                     uop;
  } t_d__x_msg;

  t_d__x_msg d__x_msg;

  assign D__X_intf.pc      = d__x_msg.pc;
  assign D__X_intf.seq_num = d__x_msg.seq_num;
  assign D__X_intf.op1     = d__x_msg.op1;
  assign D__X_intf.op2     = d__x_msg.op2;
  assign D__X_intf.waddr   = d__x_msg.waddr;
  assign D__X_intf.uop     = d__x_msg.uop;

  assign D__X_intf.preg    = 'x;
  assign D__X_intf.ppreg   = 'x;

  TestIstream #( t_d__x_msg, p_D_send_intv_delay ) D_Istream (
    .msg (d__x_msg),
    .val (D__X_intf.val),
    .rdy (D__X_intf.rdy),
    .*
  );

  t_d__x_msg msg_to_send;

  task send(
    input logic               [31:0] pc,
    input logic [p_seq_num_bits-1:0] seq_num,
    input logic               [31:0] op1,
    input logic               [31:0] op2,
    input logic                [4:0] waddr,
    input rv_uop                     uop
  );
    msg_to_send.pc      = pc;
    msg_to_send.seq_num = seq_num;
    msg_to_send.op1     = op1;
    msg_to_send.op2     = op2;
    msg_to_send.waddr   = waddr;
    msg_to_send.uop     = uop;

    D_Istream.send(msg_to_send);
  endtask

  //----------------------------------------------------------------------
  // FL W Interface
  //----------------------------------------------------------------------

  typedef struct packed {
    logic               [31:0] pc;
    logic [p_seq_num_bits-1:0] seq_num;
    logic                [4:0] waddr;
    logic               [31:0] wdata;
    logic                      wen;
  } t_x__w_msg;

  t_x__w_msg x__w_msg;

  assign x__w_msg.pc      = X__W_intf.pc;
  assign x__w_msg.seq_num = X__W_intf.seq_num;
  assign x__w_msg.waddr   = X__W_intf.waddr;
  assign x__w_msg.wdata   = X__W_intf.wdata;
  assign x__w_msg.wen     = X__W_intf.wen;

  TestOstream #( t_x__w_msg, p_W_recv_intv_delay ) W_Ostream (
    .msg (x__w_msg),
    .val (X__W_intf.val),
    .rdy (X__W_intf.rdy),
    .*
  );

  t_x__w_msg msg_to_recv;

  task recv(
    input logic               [31:0] pc,
    input logic [p_seq_num_bits-1:0] seq_num,
    input logic                [4:0] waddr,
    input logic               [31:0] wdata,
    input logic                      wen
  );
    msg_to_recv.pc      = pc;
    msg_to_recv.seq_num = seq_num;
    msg_to_recv.waddr   = waddr;
    msg_to_recv.wdata   = wdata;
    msg_to_recv.wen     = wen;

    W_Ostream.recv(msg_to_recv);
  endtask

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

  string trace;

  // verilator lint_off BLKSEQ
  always @( posedge clk ) begin
    #2;
    trace = "";

    trace = {trace, D_Istream.trace( t.trace_level )};
    trace = {trace, " | "};
    trace = {trace, dut.trace( t.trace_level )};
    trace = {trace, " | "};
    trace = {trace, W_Ostream.trace( t.trace_level )};

    t.trace( trace );
  end
  // verilator lint_on BLKSEQ

  //----------------------------------------------------------------------
  // Include test cases
  //----------------------------------------------------------------------

  `include "hw/execute/test/test_cases/fdiv_test_cases.sv"

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    run_fdiv_test_cases();
  endtask

endmodule

//========================================================================
// FDIV_test
//========================================================================

module FDIV_test;
  FDIVTestSuite #(1)          suite_1();
  FDIVTestSuite #(2, 6, 0, 0) suite_2();
  FDIVTestSuite #(3, 3, 0, 0) suite_3();
  FDIVTestSuite #(4, 4, 3, 0) suite_4();
  FDIVTestSuite #(5, 9, 0, 3) suite_5();
  FDIVTestSuite #(6, 5, 3, 3) suite_6();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();
    if ((s <= 0) || (s == 2)) suite_2.run_test_suite();
    if ((s <= 0) || (s == 3)) suite_3.run_test_suite();
    if ((s <= 0) || (s == 4)) suite_4.run_test_suite();
    if ((s <= 0) || (s == 5)) suite_5.run_test_suite();
    if ((s <= 0) || (s == 6)) suite_6.run_test_suite();

    test_bench_end();
  end
endmodule

