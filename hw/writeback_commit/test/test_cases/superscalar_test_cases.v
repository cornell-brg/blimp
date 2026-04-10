//========================================================================
// superscalar_test_cases.v
//========================================================================

typedef struct {
  logic                 [31:0] pc      [p_num_pipes];
  logic   [p_seq_num_bits-1:0] seq_num [p_num_pipes];
  logic                  [4:0] waddr   [p_num_pipes];
  logic                 [31:0] wdata   [p_num_pipes];
  logic                        wen     [p_num_pipes];
  logic [p_phys_addr_bits-1:0] preg    [p_num_pipes];
  logic [p_phys_addr_bits-1:0] ppreg   [p_num_pipes];
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

t_test_send_msg     test_send_msg;
t_test_complete_msg test_complete_msg;
t_test_commit_msg   test_commit_msg;

//------------------------------------------------------------------------
// test_case_superscalar_basic_sequential
//------------------------------------------------------------------------

task test_case_superscalar_basic_sequential();
  t.test_case_begin( "test_case_superscalar_basic_sequential" );
  if( !t.run_test ) return;

  // X-pipe send sequence
  enq_send('{0:'0,           default:'x}, 
           '{0:0,            default:'x}, 
           '{0:5'h1,         default:'x}, 
           '{0:32'hdeadbeef, default:'x}, 
           '{0:1,            default:'x}, 
           '{0:32,           default:'x}, 
           '{0:1,            default:'x}, 
           '{0:1,            default:1'b0});

  enq_send('{0:'1,           default:'x}, 
           '{0:1,            default:'x}, 
           '{0:5'h2,         default:'x}, 
           '{0:32'hcafecafe, default:'x}, 
           '{0:1,            default:'x}, 
           '{0:33,           default:'x}, 
           '{0:2,            default:'x}, 
           '{0:1,            default:1'b0});
  
  // Complete notifs
  enq_complete('{0:0, default:'x}, '{0:5'h1, default:'x}, '{0:32'hdeadbeef, default:'x}, '{0:1, default:'x}, '{0:32, default:'x}, '{0:1, default:0});
  enq_complete('{0:1, default:'x}, '{0:5'h2, default:'x}, '{0:32'hcafecafe, default:'x}, '{0:1, default:'x}, '{0:33, default:'x}, '{0:1, default:0});

  // Commit notif sequence
  enq_commit('{0:'0, default:'x}, '{0:0, default:'x}, '{0:5'h1, default:'x}, '{0:32'hdeadbeef, default:'x}, '{0:1, default:'x}, '{0:1, default:'x}, '{0:1, default:0} );
  enq_commit('{0:'1, default:'x}, '{0:1, default:'x}, '{0:5'h2, default:'x}, '{0:32'hcafecafe, default:'x}, '{0:1, default:'x}, '{0:2, default:'x}, '{0:1, default:0} );
    
  // Run  the test case
  run();

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_multi_basic_concurrent
//----------------------------------------------------------------------

task test_case_multi_basic_concurrent();
  t.test_case_begin( "test_case_multi_basic_concurrent" );
  if( !t.run_test ) return;

  // X-pipe send sequence
  for( int i = 0; i < p_num_pipes; i++ ) begin
    test_send_msg.pc[i]      = 4*i;
    test_send_msg.seq_num[i] = p_seq_num_bits'( i );
    test_send_msg.waddr[i]   = 5'( i + 1 );
    test_send_msg.wen[i]     = 1'b1;
    test_send_msg.preg[i]    = p_phys_addr_bits'( i + 32 );
    test_send_msg.ppreg[i]   = p_phys_addr_bits'( i + 1 );
    
    case ( i )
      0 : test_send_msg.wdata[i] = 32'hdeadbeef;
      1 : test_send_msg.wdata[i] = 32'hcafecafe;
      2 : test_send_msg.wdata[i] = 32'habcd0123;
      3 : test_send_msg.wdata[i] = 32'h01234567;
      default: test_send_msg.wdata[i] = 32'hx;
    endcase
  end
  enq_send( test_send_msg.pc, test_send_msg.seq_num, test_send_msg.waddr, test_send_msg.wdata, test_send_msg.wen, test_send_msg.preg, test_send_msg.ppreg, '{default:1'b1} );
  
  // Complete notifs
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
  enq_complete( test_complete_msg.seq_num, test_complete_msg.waddr, test_complete_msg.wdata, test_complete_msg.wen, test_complete_msg.preg, '{default:1} );

  // Commit notif sequence
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
  enq_commit( test_commit_msg.pc, test_commit_msg.seq_num, test_commit_msg.waddr, test_commit_msg.wdata, test_commit_msg.wen, test_commit_msg.ppreg, '{default:1} );

  // Run  the test case
  run();

  t.test_case_end();
endtask

//------------------------------------------------------------------------
// run_superscalar_test_cases
//------------------------------------------------------------------------

task run_superscalar_test_cases();
  test_case_superscalar_basic_sequential();
  test_case_multi_basic_concurrent();
endtask
