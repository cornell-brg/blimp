//========================================================================
// multi_test_cases.v
//========================================================================

typedef struct {
  logic                 [31:0] pc;
  logic   [p_seq_num_bits-1:0] seq_num;
  logic                  [4:0] waddr;
  logic                 [31:0] wdata;
  logic                        wen;
  logic [p_phys_addr_bits-1:0] preg;
  logic [p_phys_addr_bits-1:0] ppreg;
} t_test_send_msg;

typedef struct {
  logic   [p_seq_num_bits-1:0] seq_num [p_num_be_lanes];
  logic                  [4:0] waddr   [p_num_be_lanes];
  logic                 [31:0] wdata   [p_num_be_lanes];
  logic                        wen     [p_num_be_lanes];
  logic [p_phys_addr_bits-1:0] preg    [p_num_be_lanes];
} t_test_complete_msg;

typedef struct {
  logic                 [31:0] pc      [p_num_be_lanes];
  logic   [p_seq_num_bits-1:0] seq_num [p_num_be_lanes];
  logic                  [4:0] waddr   [p_num_be_lanes];
  logic                 [31:0] wdata   [p_num_be_lanes];
  logic                        wen     [p_num_be_lanes];
  logic [p_phys_addr_bits-1:0] ppreg   [p_num_be_lanes];
} t_test_commit_msg;

t_test_complete_msg test_complete_msg;
t_test_commit_msg   test_commit_msg;

//----------------------------------------------------------------------
// test_case_multi_basic_sequential
//----------------------------------------------------------------------

task test_case_multi_basic_sequential();
  t.test_case_begin( "test_case_multi_basic_sequential" );
  if( !t.run_test ) return;

  fork
    begin
      //   pipe pc  seq_num addr  data          wen preg ppreg val
      send(0,   '0, 0,      5'h1, 32'hdeadbeef, 1,  32,  1,    1 );
      send(1,   '1, 1,      5'h2, 32'hcafecafe, 1,  33,  2,    1 );
    end

    begin
      //           seq_num             addr                   data                           wen                 preg                 val 
      complete_sub('{0:0, default:'x}, '{0:5'h1, default:'x}, '{0:32'hdeadbeef, default:'x}, '{0:1, default:'x}, '{0:32, default:'x}, '{0:1, default:0} );
      complete_sub('{0:1, default:'x}, '{0:5'h2, default:'x}, '{0:32'hcafecafe, default:'x}, '{0:1, default:'x}, '{0:33, default:'x}, '{0:1, default:0} );
    end

    begin
      //         pc                   seq_num             addr                   data                           wen                 ppreg               val
      commit_sub('{0:'0, default:'x}, '{0:0, default:'x}, '{0:5'h1, default:'x}, '{0:32'hdeadbeef, default:'x}, '{0:1, default:'x}, '{0:1, default:'x}, '{0:1, default:0} );
      commit_sub('{0:'1, default:'x}, '{0:1, default:'x}, '{0:5'h2, default:'x}, '{0:32'hcafecafe, default:'x}, '{0:1, default:'x}, '{0:2, default:'x}, '{0:1, default:0} );
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_multi_basic_concurrent
//----------------------------------------------------------------------

task test_case_multi_basic_concurrent();
  t.test_case_begin( "test_case_multi_basic_concurrent" );
  if( !t.run_test ) return;

  fork
    begin
      //   pipe pc     seq_num addr  data          wen preg ppreg val
      send(0,   32'h0, 0,      5'h1, 32'hdeadbeef, 1,  32,  1,    1 );
    end

    begin
      //   pipe pc     seq_num addr  data          wen preg ppreg val
      send(1,   32'h4, 1,      5'h2, 32'hcafecafe, 1,  33,  2,    1 );
    end

    if ( p_num_be_lanes > 2 ) begin
      //   pipe pc     seq_num addr  data          wen preg ppreg val
      send(2,   32'h8, 2,      5'h3, 32'habcd0123, 1,  34,  3,    1 );
    end

    if ( p_num_be_lanes > 3 ) begin
      //   pipe pc     seq_num addr  data          wen preg ppreg val
      send(3,   32'hc, 3,      5'h4, 32'h01234567, 1,  35,  4,    1 );
    end

    begin
      for( int i = 0; i < p_num_be_lanes; i++ ) begin
        test_complete_msg.seq_num[i] = p_seq_num_bits'( i );
        test_complete_msg.waddr[i]   = 5'( i + 1 );
        test_complete_msg.wen[i]     = 1'b1;
        test_complete_msg.preg[i]    = p_phys_addr_bits'( i + 32 );
        
        case ( i )
          0 : test_complete_msg.wdata[i] = 32'hdeadbeef;
          1 : test_complete_msg.wdata[i] = 32'hcafecafe;
          2 : test_complete_msg.wdata[i] = 32'habcd0123;
          3 : test_complete_msg.wdata[i] = 32'h01234567;
          default: test_complete_msg.wdata[i] = 32'hx;
        endcase
      end
      complete_sub( test_complete_msg.seq_num, test_complete_msg.waddr, test_complete_msg.wdata, test_complete_msg.wen, test_complete_msg.preg, '{default:1} );
    end

    begin
      for( int i = 0; i < p_num_be_lanes; i++ ) begin
        test_commit_msg.pc[i]      = 4*i;
        test_commit_msg.seq_num[i] = p_seq_num_bits'( i );
        test_commit_msg.waddr[i]   = 5'( i + 1 );
        test_commit_msg.wen[i]     = 1'b1;
        test_commit_msg.ppreg[i]   = p_phys_addr_bits'( i + 1 );
        
        case ( i )
          0 : test_commit_msg.wdata[i] = 32'hdeadbeef;
          1 : test_commit_msg.wdata[i] = 32'hcafecafe;
          2 : test_commit_msg.wdata[i] = 32'habcd0123;
          3 : test_commit_msg.wdata[i] = 32'h01234567;
          default: test_commit_msg.wdata[i] = 32'hx;
        endcase
      end
      commit_sub( test_commit_msg.pc, test_commit_msg.seq_num, test_commit_msg.waddr, test_commit_msg.wdata, test_commit_msg.wen, test_commit_msg.ppreg, '{default:1} );
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_multi_ooo
//----------------------------------------------------------------------

logic test_commit_val [p_num_be_lanes];

int k;

task test_case_multi_ooo();
  t.test_case_begin( "test_case_multi_ooo" );
  if( !t.run_test ) return;

  fork
    begin
      //   pipe pc       seq_num addr  data          wen preg ppreg val
      send(0,   32'h000, 0,      5'h0, 32'h00000000, 0,  10,  1,    1 );
      send(0,   32'h008, 2,      5'h2, 32'h22222222, 1,  12,  3,    1 );
      send(0,   32'h010, 4,      5'h4, 32'h44444444, 1,  14,  5,    1 );
      send(0,   32'h01c, 7,      5'h7, 32'h77777777, 1,  17,  8,    1 );
    end

    begin
      //   pipe pc       seq_num addr  data          wen preg ppreg val
      send(1,   32'h014, 5,      5'h5, 32'h55555555, 1,  15,  6,    1 );
      send(1,   32'h00c, 3,      5'h3, 32'h33333333, 1,  13,  4,    1 );
      send(1,   32'h018, 6,      5'h6, 32'h66666666, 1,  16,  7,    1 );
      send(1,   32'h004, 1,      5'h1, 32'h11111111, 1,  11,  2,    1 );
    end

    begin
      //           seq_num                  addr                           data                                           wen                      preg                       val 
      complete_sub('{0:0, 1:5, default:'x}, '{0:5'h0, 1:5'h5, default:'x}, '{0:32'h00000000, 1:32'h55555555, default:'x}, '{0:0, 1:1, default:'x}, '{0:10, 1:15, default:'x}, '{0:1, 1:1, default:0} );
      complete_sub('{0:2, 1:3, default:'x}, '{0:5'h2, 1:5'h3, default:'x}, '{0:32'h22222222, 1:32'h33333333, default:'x}, '{0:1, 1:1, default:'x}, '{0:12, 1:13, default:'x}, '{0:1, 1:1, default:0} );
      complete_sub('{0:4, 1:6, default:'x}, '{0:5'h4, 1:5'h6, default:'x}, '{0:32'h44444444, 1:32'h66666666, default:'x}, '{0:1, 1:1, default:'x}, '{0:14, 1:16, default:'x}, '{0:1, 1:1, default:0} );
      complete_sub('{0:7, 1:1, default:'x}, '{0:5'h7, 1:5'h1, default:'x}, '{0:32'h77777777, 1:32'h11111111, default:'x}, '{0:1, 1:1, default:'x}, '{0:17, 1:11, default:'x}, '{0:1, 1:1, default:0} );
    end

    begin
      //         pc                  seq_num             addr                   data                           wen                 ppreg                val 
      commit_sub('{0:0, default:'x}, '{0:0, default:'x}, '{0:5'h0, default:'x}, '{0:32'h00000000, default:'x}, '{0:0, default:'x}, '{0:1, default:'x}, '{0:1, default:0} );

      k = 1;
      while ( k < 8 ) begin
        for( int i = 0; i < p_num_be_lanes; i++ ) begin
          test_commit_msg.pc[i]      = 4*k;
          test_commit_msg.seq_num[i] = p_seq_num_bits'( k );
          test_commit_msg.waddr[i]   = 5'( k );
          test_commit_msg.wdata[i]   = {8{4'(k)}};
          test_commit_msg.wen[i]     = 1'b1;
          test_commit_msg.ppreg[i]   = p_phys_addr_bits'( k + 1 );
          test_commit_val[i]         = (k < 8);

          k = k + 1;
        end

        commit_sub( test_commit_msg.pc, test_commit_msg.seq_num, test_commit_msg.waddr, test_commit_msg.wdata, test_commit_msg.wen, test_commit_msg.ppreg, test_commit_val );
      end
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_multi_random
//----------------------------------------------------------------------

localparam RAND_NUM_ITER = 250;

typedef struct {
  logic    [31:0] arb_hd_ptr;
  logic           mrob_vals [2**p_seq_num_bits];
  t_test_send_msg mrob_msgs [2**p_seq_num_bits];
  logic    [31:0] mrob_deq_ptr;
} t_wcu_model;

t_wcu_model         wcu;
logic wcu_send_rdy [p_num_pipes];

logic               rand_send_val [RAND_NUM_ITER][p_num_pipes];
logic               rand_send_rdy [p_num_pipes];
t_test_send_msg     rand_send_msg [RAND_NUM_ITER][p_num_pipes];
logic               rand_complete_val [RAND_NUM_ITER][p_num_be_lanes];
t_test_complete_msg rand_complete_msg [RAND_NUM_ITER];
logic               rand_commit_val [RAND_NUM_ITER][p_num_be_lanes];
t_test_commit_msg   rand_commit_msg [RAND_NUM_ITER];

logic seq_num_free [2**p_seq_num_bits];
int   scan_ptr;
logic first_scan;
logic prev_val;
int   commit_idx;

// Random test case

/* verilator lint_off WIDTHEXPAND */
task test_case_multi_random();
  t.test_case_begin( "test_case_multi_random" );
  if( !t.run_test ) return;

  // Initialize the WCU model

  wcu.arb_hd_ptr = 0;
  wcu.mrob_deq_ptr = 0;
  for( int p = 0; p < p_num_pipes; p++ ) begin
    wcu_send_rdy[p] = 1'b1;
  end
  for( int i = 0; i < 2**p_seq_num_bits; i++ ) begin
    wcu.mrob_vals[i] = 1'b0;
    seq_num_free[i] = 1'b1;
  end
  
  // Lay out the randomized test

  commit_idx = 0;

  for( int i = 0; i < RAND_NUM_ITER; i++ ) begin
    // Initialize send valid to zero
    for( int p = 0; p < p_num_pipes; p++ ) begin
      rand_send_val[i][p] = 1'b0;
    end

    // Determine the pipe send data
    for( int p = 0; p < p_num_be_lanes; p++ ) begin
      // Randomly generate pipe send data iff the previous send on pipe p was sent
      rand_send_val[i][p] = 1'b0;

      if( wcu_send_rdy[p] ) begin
        rand_send_val[i][p]         = 1'b1;
        rand_send_msg[i][p].pc      = $urandom();
        rand_send_msg[i][p].seq_num = p_seq_num_bits'( $urandom() );
        rand_send_msg[i][p].wen     = 1'( $urandom() ) && seq_num_free[rand_send_msg[i][p].seq_num];
        rand_send_msg[i][p].waddr   = 5'( $urandom() );
        rand_send_msg[i][p].wdata   = 32'( $urandom() );
        rand_send_msg[i][p].preg    = p_phys_addr_bits'( $urandom() );
        rand_send_msg[i][p].ppreg   = p_phys_addr_bits'( $urandom() );
      end

      // Find a free sequence number if not yet found
      k = 0;
      while ( (k < 10) && !seq_num_free[rand_send_msg[i][p].seq_num] ) begin
        rand_send_msg[i][p].seq_num = p_seq_num_bits'( $urandom() );
        k = k + 1;
      end

      // Update sequence number free list
      if ( seq_num_free[rand_send_msg[i][p].seq_num] ) begin
        seq_num_free[rand_send_msg[i][p].seq_num] = 1'b0;
        wcu_send_rdy[p] = 1'b0;
      end
      else
        rand_send_val[i][p] = 1'b0;
    end

    // Determine the complete notif data
    scan_ptr = wcu.arb_hd_ptr;
    first_scan = 1'b1;

    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      rand_complete_val[i][j] = 1'b0;

      while ( !rand_complete_val[i][j] && (first_scan || (wcu.arb_hd_ptr != scan_ptr)) ) begin
        // Determine the correct complete message
        rand_complete_val[i][j]         = rand_send_val[i][scan_ptr];
        rand_complete_msg[i].seq_num[j] = rand_send_msg[i][scan_ptr].seq_num;
        rand_complete_msg[i].waddr[j]   = rand_send_msg[i][scan_ptr].waddr;
        rand_complete_msg[i].wdata[j]   = rand_send_msg[i][scan_ptr].wdata;
        rand_complete_msg[i].wen[j]     = rand_send_msg[i][scan_ptr].wen && (rand_send_msg[i][scan_ptr].waddr != '0);
        rand_complete_msg[i].preg[j]    = rand_send_msg[i][scan_ptr].preg;

        // Update the WCU model
        if ( rand_complete_val[i][j] ) begin
          wcu.mrob_vals[rand_complete_msg[i].seq_num[j]] = rand_complete_val[i][j];
          wcu.mrob_msgs[rand_complete_msg[i].seq_num[j]] = rand_send_msg[i][scan_ptr];
          wcu.mrob_msgs[rand_complete_msg[i].seq_num[j]].wen = rand_complete_msg[i].wen[j];

          wcu_send_rdy[scan_ptr] = 1'b1;
        end

        // Update the scan pointer
        first_scan = 1'b0;
        scan_ptr = (scan_ptr + 1) % p_num_pipes;
      end
    end
    
    // Update the MRRArb head pointer
    wcu.arb_hd_ptr = scan_ptr;

    // Determine the commit notif data
    scan_ptr = wcu.mrob_deq_ptr;
    prev_val = 1'b1;

    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      // Determine the correct commit message
      rand_commit_val[commit_idx][j]         = prev_val && wcu.mrob_vals[scan_ptr];
      rand_commit_msg[commit_idx].pc[j]      = wcu.mrob_msgs[scan_ptr].pc;
      rand_commit_msg[commit_idx].seq_num[j] = wcu.mrob_msgs[scan_ptr].seq_num;
      rand_commit_msg[commit_idx].waddr[j]   = wcu.mrob_msgs[scan_ptr].waddr;
      rand_commit_msg[commit_idx].wdata[j]   = wcu.mrob_msgs[scan_ptr].wdata;
      rand_commit_msg[commit_idx].wen[j]     = wcu.mrob_msgs[scan_ptr].wen;
      rand_commit_msg[commit_idx].ppreg[j]   = wcu.mrob_msgs[scan_ptr].ppreg;

      // Update the scan pointer
      prev_val = rand_commit_val[commit_idx][j];
      scan_ptr = (scan_ptr + 1) % (2**p_seq_num_bits);

      // Update the free list and dequeue pointer
      if ( rand_commit_val[commit_idx][j] ) begin
        seq_num_free[rand_commit_msg[commit_idx].seq_num[j]] = 1'b1;
        wcu.mrob_deq_ptr = scan_ptr;
      end
    end

    // Update the commit index
    if ( rand_commit_val[commit_idx][0] ) begin
      commit_idx = commit_idx + 1;
    end

    // Debug
    // for( int j = 0; j < p_num_pipes; j++ ) begin
    //   $display( "[%3d] send_msg (pipe %0d): %b %h", i, j, rand_send_val[i][j], {rand_send_msg[i][j].pc, rand_send_msg[i][j].seq_num, rand_send_msg[i][j].waddr, rand_send_msg[i][j].wdata, rand_send_msg[i][j].wen, rand_send_msg[i][j].preg, rand_send_msg[i][j].ppreg} );
    //   $display( "[%3d] send_msg (pipe %0d expanded): %b %h %h %h %h %h %h %h", i, j, rand_send_val[i][j], rand_send_msg[i][j].pc, rand_send_msg[i][j].seq_num, rand_send_msg[i][j].waddr, rand_send_msg[i][j].wdata, rand_send_msg[i][j].wen, rand_send_msg[i][j].preg, rand_send_msg[i][j].ppreg );
    // end
    // for( int j = 0; j < p_num_be_lanes; j++ ) begin
    //   $display( "[%3d] complete_msg (lane %0d): %b %h", i, j, rand_complete_val[i][j], {rand_complete_msg[i].seq_num[j], rand_complete_msg[i].waddr[j], rand_complete_msg[i].wdata[j], rand_complete_msg[i].wen[j], rand_complete_msg[i].preg[j]} );
    //   $display( "[%3d] complete_msg (lane %0d expanded): %b %h %h %h %h %h", i, j, rand_complete_val[i][j], rand_complete_msg[i].seq_num[j], rand_complete_msg[i].waddr[j], rand_complete_msg[i].wdata[j], rand_complete_msg[i].wen[j], rand_complete_msg[i].preg[j] );
    // end
    // for( int p = 0; p < p_num_pipes; p++ ) begin
    //   $display( "val=%b seq_num=%0d rdy=%b", rand_send_val[i][p], rand_send_msg[i][p].seq_num, wcu_send_rdy[p]);
    // end
  end

  // for( int i = 0; i < commit_idx; i++ ) begin
  //   for( int j = 0; j < p_num_be_lanes; j++ ) begin
  //     $display( "[%3d] commit_msg (lane %0d): %b %h", i, j, rand_commit_val[i][j], {rand_commit_msg[i].pc[j], rand_commit_msg[i].seq_num[j], rand_commit_msg[i].waddr[j], rand_commit_msg[i].wdata[j], rand_commit_msg[i].wen[j], rand_commit_msg[i].ppreg[j]} );
  //     $display( "[%3d] commit_msg (lane %0d expanded): %b %h %h %h %h %h %h", i, j, rand_commit_val[i][j], rand_commit_msg[i].pc[j], rand_commit_msg[i].seq_num[j], rand_commit_msg[i].waddr[j], rand_commit_msg[i].wdata[j], rand_commit_msg[i].wen[j], rand_commit_msg[i].ppreg[j] );
  //   end
  // end

  // Run the test

  fork
    begin
      for( int i = 0; i < RAND_NUM_ITER; i++ ) begin
        for( int j = 0; j < p_num_be_lanes; j++ ) begin
          fork
            automatic int jj = j;
            if ( rand_send_val[i][j] ) begin
              send(jj, rand_send_msg[i][jj].pc, rand_send_msg[i][jj].seq_num, rand_send_msg[i][jj].waddr, rand_send_msg[i][jj].wdata, rand_send_msg[i][jj].wen, rand_send_msg[i][jj].preg, rand_send_msg[i][jj].ppreg, rand_send_val[i][jj] );
            end
          join_none
        end
        wait fork;
      end
    end

    begin
      k = 0;
      for( int g = 0; g < RAND_NUM_ITER; g++ ) begin
        complete_sub( rand_complete_msg[g].seq_num, rand_complete_msg[g].waddr, rand_complete_msg[g].wdata, rand_complete_msg[g].wen, rand_complete_msg[g].preg, rand_complete_val[g] );
        k = k + 1;
      end
    end

    begin
      for( int n = 0; n < commit_idx; n++ ) begin
        commit_sub( rand_commit_msg[n].pc, rand_commit_msg[n].seq_num, rand_commit_msg[n].waddr, rand_commit_msg[n].wdata, rand_commit_msg[n].wen, rand_commit_msg[n].ppreg, rand_commit_val[n] );
      end
    end
  join

  t.test_case_end();
endtask
/* verilator lint_on WIDTHEXPAND */

//----------------------------------------------------------------------
// run_multi_test_cases
//----------------------------------------------------------------------

task run_multi_test_cases();
  test_case_multi_basic_sequential();
  test_case_multi_basic_concurrent();
  test_case_multi_ooo();
  // test_case_multi_random();
endtask
