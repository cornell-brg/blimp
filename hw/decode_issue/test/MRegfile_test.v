//========================================================================
// MRegfile_test.v
//========================================================================
// A testbench for our parametrized pending register file

`include "test/TestUtils.v"
`include "hw/decode_issue/MRegfile.v"

import TestEnv::*;

//========================================================================
// MRegfileTestSuite
//========================================================================
// A test suite for a particular parametrization of the multi-write port regfile

module MRegfileTestSuite #(
  parameter p_suite_num    = 0,
  parameter p_entry_bits   = 32,
  parameter p_num_regs     = 32,
  parameter p_num_be_lanes = 2
);
  string suite_name = $sformatf("%0d: MRegfileTestSuite_%0d_%d", 
                                p_suite_num, p_num_regs, 
                                p_entry_bits);

  //----------------------------------------------------------------------
  // Setup
  //----------------------------------------------------------------------

  // verilator lint_off UNUSED
  logic clk, rst;
  // verilator lint_on UNUSED

  TestUtils t( .* );

  //----------------------------------------------------------------------
  // Instantiate design under test
  //----------------------------------------------------------------------

  localparam p_addr_bits = $clog2(p_num_regs);

  logic                    dut_rst;
  logic [ p_addr_bits-1:0] dut_raddr [1:0];
  logic [p_entry_bits-1:0] dut_rdata [1:0];
  logic [ p_addr_bits-1:0] dut_waddr [p_num_be_lanes];
  logic [p_entry_bits-1:0] dut_wdata [p_num_be_lanes];
  logic                    dut_wen   [p_num_be_lanes];

  MRegfile #(
    .p_entry_bits   (p_entry_bits),
    .p_num_regs     (p_num_regs),
    .p_num_be_lanes (p_num_be_lanes)
  ) DUT (
    .clk                (clk),
    .rst                (rst | dut_rst),
    .raddr              (dut_raddr),
    .rdata              (dut_rdata),
    .waddr              (dut_waddr),
    .wdata              (dut_wdata),
    .wen                (dut_wen)
  );

  //----------------------------------------------------------------------
  // check
  //----------------------------------------------------------------------
  // All tasks start at #1 after the rising edge of the clock. So we
  // write the inputs #1 after the rising edge, and check the outputs #1
  // before the next rising edge.

  task check (
    input logic                    _rst,
    input logic [ p_addr_bits-1:0] raddr0,
    input logic [p_entry_bits-1:0] rdata0,
    input logic [ p_addr_bits-1:0] raddr1,
    input logic [p_entry_bits-1:0] rdata1,
    input logic [ p_addr_bits-1:0] waddr  [p_num_be_lanes],
    input logic [p_entry_bits-1:0] wdata  [p_num_be_lanes],
    input logic                    wen    [p_num_be_lanes]
  );
    if ( !t.failed ) begin
      dut_rst              = _rst;
      dut_raddr[0]         = raddr0;
      dut_raddr[1]         = raddr1;
      dut_waddr            = waddr;
      dut_wdata            = wdata;
      dut_wen              = wen;

      #8;

      if ( t.verbose ) begin
        $display( "%3d: %b %d %d %p %p %p > %h %h", t.cycles,
                  dut_rst, dut_raddr[0], dut_raddr[1],
                  dut_wen, dut_waddr, dut_wdata,
                  dut_rdata[0], dut_rdata[1]);
      end

      `CHECK_EQ( dut_rdata[0], rdata0 );
      `CHECK_EQ( dut_rdata[1], rdata1 );

      #2;

    end
  endtask

  //----------------------------------------------------------------------
  // test_case_1_basic
  //----------------------------------------------------------------------

  task test_case_1_basic();
    t.test_case_begin( "test_case_1_basic" );
    if( !t.run_test ) return;

    //    rst raddr0           rdata0             raddr1           rdata1             waddr                                wdata                                    wen
    check( 0, 0,               'h00,              0,               'h00,              '{'0, '0},                           '{'0, '0},                               '{0, 0} );
    check( 0, 0,               'h00,              0,               'h00,              '{p_addr_bits'(1), p_addr_bits'(2)}, '{p_entry_bits'(32), p_entry_bits'(33)}, '{1, 1} );
    check( 0, p_addr_bits'(1), p_entry_bits'(32), p_addr_bits'(2), p_entry_bits'(33), '{'0, '0},                           '{'0, '0},                               '{0, 0} );

    t.test_case_end();
  endtask

  //----------------------------------------------------------------------
  // test_case_2_reset
  //----------------------------------------------------------------------

  // task test_case_2_reset();
  //   t.test_case_begin( "test_case_2_reset" );
  //   if( !t.run_test ) return;

  //   //    rst raddr0 rdata0 p0 raddr1 rdata1 p1 waddr waddr wen caddr cpend paddr pval
  //   check( 0, 0,     'h00,  0, 0,     'h00,  0, 5,    'hf0, 1,  0,    0,    '0,   0 );
  //   check( 1, 5,     'hf0,  0, 0,     'h00,  0, 0,    'h00, 0,  0,    0,    '0,   0 );
  //   check( 0, 5,     'h00,  0, 0,     'h00,  0, 0,    'h00, 0,  0,    0,    '0,   0 );

  //   t.test_case_end();
  // endtask

  //----------------------------------------------------------------------
  // test_case_3_zero
  //----------------------------------------------------------------------

  // task test_case_3_zero();
  //   t.test_case_begin( "test_case_3_zero" );
  //   if( !t.run_test ) return;

  //   //    rst raddr0              rdata0                 p0 raddr1              rdata1                 p1 waddr               waddr                 wen caddr cpend paddr pval
  //   check( 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h00), p_entry_bits'('hbaad), 1, 0,    0,    '0,   0 );
  //   check( 1, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h00), p_entry_bits'('h4321), 1, 0,    0,    '0,   0 );
  //   check( 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, 0,    0,    '0,   0 );

  //   t.test_case_end();
  // endtask

  //----------------------------------------------------------------------
  // test_case_4_all
  //----------------------------------------------------------------------

  // logic [ p_addr_bits-1:0] curr_addr;
  // logic [p_entry_bits-1:0] curr_data;
  // logic [ p_addr_bits-1:0] prev_addr;
  // logic [p_entry_bits-1:0] prev_data;

  // task test_case_4_all();
  //   t.test_case_begin( "test_case_4_all" );
  //   if( !t.run_test ) return;

  //   prev_addr = '0;
  //   prev_data = '0;

  //   for ( int i = 1; i < p_num_regs; i = i + 1 ) begin
  //     curr_addr = p_addr_bits'(i);
  //     curr_data = p_entry_bits'($urandom());

  //     check( 0, prev_addr, prev_data, 0, prev_addr, prev_data, 0, curr_addr, curr_data, 1, 0, 0, '0, 0 );

  //     prev_addr = curr_addr;
  //     prev_data = curr_data;
  //   end

  //   check( 0, prev_addr, prev_data, 0, prev_addr, prev_data, 0, p_addr_bits'('0), p_entry_bits'('0), 0, 0, 0, '0, 0 );

  //   t.test_case_end();
  // endtask

  //----------------------------------------------------------------------
  // test_case_5_multi_read
  //----------------------------------------------------------------------

  // task test_case_5_multi_read();
  //   t.test_case_begin( "test_case_5_multi_read" );
  //   if( !t.run_test ) return;

  //   //    rst raddr0              rdata0                 p0 raddr1              rdata1                 p1 waddr               waddr                 wen caddr cpend paddr pval
  //   check( 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h06), p_entry_bits'('h1234), 1, 0,    0,    '0,   0 );
  //   check( 0, p_addr_bits'('h06), p_entry_bits'('h1234), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h07), p_entry_bits'('h5678), 1, 0,    0,    '0,   0 );
  //   check( 0, p_addr_bits'('h06), p_entry_bits'('h1234), 0, p_addr_bits'('h07), p_entry_bits'('h5678), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, 0,    0,    '0,   0 );
  //   check( 0, p_addr_bits'('h07), p_entry_bits'('h5678), 0, p_addr_bits'('h06), p_entry_bits'('h1234), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, 0,    0,    '0,   0 );

  //   t.test_case_end();
  // endtask

  //----------------------------------------------------------------------
  // test_case_6_pending
  //----------------------------------------------------------------------

  // task test_case_6_pending();
  //   t.test_case_begin( "test_case_6_pending" );
  //   if( !t.run_test ) return;

  //   //    rst raddr0              rdata0                 p0 raddr1              rdata1                 p1 waddr               waddr                 wen caddr cpend paddr pval
  //   check( 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h01), p_entry_bits'('h0000), 0, p_addr_bits'('h06), p_entry_bits'('h1234), 1, 0,    0,    '0,   0 );
  //   check( 0, p_addr_bits'('h06), p_entry_bits'('h1234), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, p_addr_bits'('h07), p_entry_bits'('h5678), 1, 0,    0,    '0,   0 );
  //   check( 0, p_addr_bits'('h06), p_entry_bits'('h1234), 0, p_addr_bits'('h07), p_entry_bits'('h5678), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, 0,    0,    '0,   0 );
  //   check( 0, p_addr_bits'('h07), p_entry_bits'('h5678), 0, p_addr_bits'('h06), p_entry_bits'('h1234), 0, p_addr_bits'('h00), p_entry_bits'('h0000), 0, 0,    0,    '0,   0 );

  //   t.test_case_end();
  // endtask

  //----------------------------------------------------------------------
  // test_case_7_random
  //----------------------------------------------------------------------

  // logic [p_entry_bits-1:0] rand_regs [p_num_regs-1:0];
  // logic                    pbits     [p_num_regs-1:0];
  // initial begin
  //   rand_regs = '{default: '0};
  //   pbits     = '{default: 1'b0};
  // end

  // logic [ p_addr_bits-1:0] rand_raddr0;
  // logic [ p_addr_bits-1:0] rand_raddr1;
  // logic [ p_addr_bits-1:0] rand_waddr;
  // logic [p_entry_bits-1:0] rand_wdata;
  // logic                    rand_wen;
  // logic [p_entry_bits-1:0] exp_rdata0;
  // logic [p_entry_bits-1:0] exp_rdata1;
  // logic                    exp_pending0;
  // logic                    exp_pending1;
  // logic [ p_addr_bits-1:0] rand_paddr;
  // logic                    rand_pval;
  // logic [ p_addr_bits-1:0] rand_caddr;
  // logic                    exp_cpend;

  // task test_case_7_random();
  //   t.test_case_begin( "test_case_7_random" );
  //   if( !t.run_test ) return;

  //   for ( int i = 0; i < 30; i = i + 1 ) begin
  //     rand_raddr0 = p_addr_bits'($urandom());
  //     rand_raddr1 = p_addr_bits'($urandom());
  //     rand_waddr  = p_addr_bits'($urandom());
  //     rand_wdata  = p_entry_bits'($urandom());
  //     rand_wen    = 1'($urandom());
  //     rand_paddr  = p_addr_bits'($urandom());
  //     rand_pval   = 1'($urandom());
  //     rand_caddr  = p_addr_bits'($urandom());

  //     exp_rdata0   = rand_wen & ( rand_waddr == rand_raddr0 ) & ( rand_waddr != '0 )
  //                    ? rand_wdata : rand_regs[rand_raddr0];
  //     exp_rdata1   = rand_wen & ( rand_waddr == rand_raddr1 ) & ( rand_waddr != '0 )
  //                    ? rand_wdata : rand_regs[rand_raddr1];
  //     exp_pending0 = !( rand_wen & ( rand_waddr == rand_raddr0 )) & pbits[rand_raddr0];
  //     exp_pending1 = !( rand_wen & ( rand_waddr == rand_raddr1 )) & pbits[rand_raddr1];
  //     exp_cpend    = pbits[rand_caddr] & (rand_caddr != '0) & (rand_caddr != rand_waddr);

  //     check( 0, rand_raddr0, exp_rdata0, exp_pending0,
  //            rand_raddr1, exp_rdata1, exp_pending1,
  //            rand_waddr, rand_wdata, rand_wen, 
  //            rand_caddr, exp_cpend,
  //            rand_paddr, rand_pval );

  //     if ( rand_wen & ( rand_waddr != '0 ) ) rand_regs[rand_waddr] = rand_wdata;
  //     for( int j = 1; j < p_num_regs; j = j + 1 ) begin
  //       if( rand_pval & ( rand_paddr == p_addr_bits'(j) ))
  //         pbits[rand_paddr] = 1'b1;
  //       else if( rand_wen & ( rand_waddr == p_addr_bits'(j) ))
  //         pbits[rand_waddr] = 1'b0;
  //     end
  //   end

  //   t.test_case_end();
  // endtask

  //----------------------------------------------------------------------
  // run_test_suite
  //----------------------------------------------------------------------

  task run_test_suite();
    t.test_suite_begin( suite_name );

    test_case_1_basic();
    // test_case_2_reset();
    // test_case_3_zero();
    // test_case_4_all();
    // test_case_5_multi_read();
    // test_case_6_pending();
    // test_case_7_random();

  endtask
endmodule

//========================================================================
// MRegfile_test
//========================================================================

module MRegfile_test;
  MRegfileTestSuite #(1)         suite_1();
  MRegfileTestSuite #(2, 16, 32) suite_2();
  MRegfileTestSuite #(3, 32, 8 ) suite_3();
  MRegfileTestSuite #(4,  8, 64) suite_4();

  int s;

  initial begin
    test_bench_begin( `__FILE__ );
    s = get_test_suite();

    if ((s <= 0) || (s == 1)) suite_1.run_test_suite();
    if ((s <= 0) || (s == 2)) suite_2.run_test_suite();
    if ((s <= 0) || (s == 3)) suite_3.run_test_suite();
    if ((s <= 0) || (s == 4)) suite_4.run_test_suite();

    test_bench_end();
  end
endmodule
