//========================================================================
// basic_test_cases.v
//========================================================================
// Basic test cases for a decode-issue unit (to ensure baseline
// functionality)

//----------------------------------------------------------------------
// test_case_1_fetch_block_no_ctrl_insts
//----------------------------------------------------------------------

task automatic test_case_1_fetch_block_no_ctrl_insts();
  logic               [31:0] send_pc         [p_num_fe_lanes];
  string                     send_assembly   [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] send_seq_num    [p_num_fe_lanes];
  logic                [1:0] send_inst_status [p_num_fe_lanes];
  logic                      send_valid      [p_num_fe_lanes];

  localparam p_num_recv_msgs = p_num_fe_lanes;
  logic                 [31:0] recv_pc      [p_num_recv_msgs];
  logic   [p_seq_num_bits-1:0] recv_seq_num [p_num_recv_msgs];
  logic                 [31:0] recv_op1     [p_num_recv_msgs];
  logic                 [31:0] recv_op2     [p_num_recv_msgs];
  logic                  [4:0] recv_waddr   [p_num_recv_msgs];
  logic [p_phys_addr_bits-1:0] recv_preg    [p_num_recv_msgs];
  logic [p_phys_addr_bits-1:0] recv_ppreg   [p_num_recv_msgs];
  rv_uop                       recv_uop     [p_num_recv_msgs];
  logic  [p_pipe_idx_bits-1:0] recv_pipe    [p_num_recv_msgs];

  t.test_case_begin( "test_case_1_fetch_block_no_ctrl_insts" );
  if( !t.run_test ) return;

  // Form fetch block
  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    send_pc[i]         = 'h200 + i*4;
    send_assembly[i]   = $sformatf("addi x%0d, x0, %0d", i+1, (i+1)*10);
    send_seq_num[i]    = p_seq_num_bits'(i);
    send_inst_status[i] = INST_STATUS_READY;
    send_valid[i]      = 1'b1;
  end

  // Form expected decode-issue output
  for( int i = 0; i < p_num_recv_msgs; i++ ) begin
    recv_pc[i]       = 'h200 + i*4;
    recv_seq_num[i]  = p_seq_num_bits'(i);
    recv_op1[i]      = '0;
    recv_op2[i]      = (i+1)*10;
    recv_waddr[i]    = 5'(i+1);
    recv_preg[i]     = p_phys_addr_bits'(i+1+31);
    recv_ppreg[i]    = p_phys_addr_bits'(i+1);
    recv_uop[i]      = OP_ADD;
    recv_pipe[i]     = p_pipe_idx_bits'(i);
  end

  fork
    begin
      send(
        send_pc,
        send_assembly,
        send_seq_num,
        send_inst_status,
        send_valid
      );
    end

    begin
      for (int i = 0; i < p_num_recv_msgs; i++) begin
        fork
          begin
            // $display("sending");
            recv(
              recv_pc[i],
              recv_seq_num[i],
              recv_op1[i],
              recv_op2[i],
              recv_waddr[i],
              recv_preg[i],
              recv_ppreg[i],
              recv_uop[i],
              recv_pipe[i]
            );
          end
        join_none
      end
      wait fork;
    end
  join

  #100;

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_pending
//----------------------------------------------------------------------

// task test_case_pending();
//   t.test_case_begin( "test_case_pending" );
//   if( !t.run_test ) return;

//   //   seq_num waddr wdata wen
//   pub( 'x,     1,    1,    1 );
//   pub( 'x,     3,    3,    1 );
//   pub( 'x,     5,    5,    1 );

//   fork
//     begin
//       //   addr    inst              seq_num
//       send('h200, "add  x2, x0, x1", 0);
//       send('h204, "add  x4, x3, x2", 1);
//       send('h208, "add  x5, x5, x4", 2);
//       send('h20c, "add  x5, x5, x5", 3);
//       send('h210, "add  x6, x5, x4", 4);
//     end

//     begin
//       //   pc     seq_num op1 op2  waddr uop
//       recv('h200, 0,      0,   1,  2,    OP_ADD);
//       pub( 'x, 2, 1, 1 );
//       recv('h204, 1,      3,   1,  4,    OP_ADD);
//       pub( 'x, 4, 4, 1 );
//       recv('h208, 2,      5,   4,  5,    OP_ADD);
//       pub( 'x, 5, 9, 1 );
//       recv('h20c,  3,     9,   9,  5,    OP_ADD);
//       pub( 'x, 5, 18, 1 );
//       recv('h210, 4,     18,   4,  6,    OP_ADD);
//     end
//   join

//   t.test_case_end();
// endtask

//----------------------------------------------------------------------
// run_basic_test_cases
//----------------------------------------------------------------------

task run_basic_test_cases();
  test_case_1_fetch_block_no_ctrl_insts();
  // test_case_pending();
endtask
