//========================================================================
// multi_test_cases.v
//========================================================================

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
      //   pipe pc  seq_num addr  data          wen preg ppreg
      send(0,   '0, 0,      5'h1, 32'hdeadbeef, 1,  32,  1 );
      send(1,   '1, 1,      5'h2, 32'hcafecafe, 1,  33,  2 );
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
      //   pipe pc     seq_num addr  data          wen preg ppreg
      send(0,   32'h0, 0,      5'h1, 32'hdeadbeef, 1,  32,  1 );
    end

    begin
      //   pipe pc     seq_num addr  data          wen preg ppreg
      send(1,   32'h4, 1,      5'h2, 32'hcafecafe, 1,  33,  2 );
    end

    if ( p_num_be_lanes > 2 ) begin
      //   pipe pc     seq_num addr  data          wen preg ppreg
      send(2,   32'h8, 2,      5'h3, 32'habcd0123, 1,  34,  3 );
    end

    if ( p_num_be_lanes > 3 ) begin
      //   pipe pc     seq_num addr  data          wen preg ppreg
      send(3,   32'hc, 3,      5'h4, 32'h01234567, 1,  35,  4 );
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

integer k;

task test_case_multi_ooo();
  t.test_case_begin( "test_case_multi_ooo" );
  if( !t.run_test ) return;

  fork
    begin
      //   pipe pc       seq_num addr  data          wen preg ppreg
      send(0,   32'h000, 0,      5'h0, 32'h00000000, 0,  10,  1 );
      send(0,   32'h008, 2,      5'h2, 32'h22222222, 1,  12,  3 );
      send(0,   32'h010, 4,      5'h4, 32'h44444444, 1,  14,  5 );
      send(0,   32'h01c, 7,      5'h7, 32'h77777777, 1,  17,  8 );
    end

    begin
      //   pipe pc       seq_num addr  data          wen preg ppreg
      send(1,   32'h014, 5,      5'h5, 32'h55555555, 1,  15,  6 );
      send(1,   32'h00c, 3,      5'h3, 32'h33333333, 1,  13,  4 );
      send(1,   32'h018, 6,      5'h6, 32'h66666666, 1,  16,  7 );
      send(1,   32'h004, 1,      5'h1, 32'h11111111, 1,  11,  2 );
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

// typedef struct {
//   logic           [31:0] mrrarb_head_ptr;
//   logic                  mrob_vals [p_depth];
//   logic [p_msg_bits-1:0] mrob_msgs [p_depth];
//   logic           [31:0] mrob_deq_ptr;
// } t_wcu_model;

// task test_case_multi_random();
//   t.test_case_begin( "test_case_multi_random" );
//   if( !t.run_test ) return;
  
//   // inits

//   for( int i = 0; i < 250; i++ ) begin
//     fork
//       begin
//         //   pipe pc     seq_num addr  data          wen preg ppreg
//         send(0,   32'h0, 0,      5'h1, 32'hdeadbeef, 1,  32,  1 );
//       end

//       begin
//         //   pipe pc     seq_num addr  data          wen preg ppreg
//         send(1,   32'h4, 1,      5'h2, 32'hcafecafe, 1,  33,  2 );
//       end

//       if ( p_num_be_lanes > 2 ) begin
//         //   pipe pc     seq_num addr  data          wen preg ppreg
//         send(2,   32'h8, 2,      5'h3, 32'habcd0123, 1,  34,  3 );
//       end

//       if ( p_num_be_lanes > 3 ) begin
//         //   pipe pc     seq_num addr  data          wen preg ppreg
//         send(3,   32'hc, 3,      5'h4, 32'h01234567, 1,  35,  4 );
//       end

//       begin
//         complete_sub( test_complete_msg.seq_num, test_complete_msg.waddr, test_complete_msg.wdata, test_complete_msg.wen, test_complete_msg.preg, '{default:1} );
//       end

//       begin
//         commit_sub( test_commit_msg.pc, test_commit_msg.seq_num, test_commit_msg.waddr, test_commit_msg.wdata, test_commit_msg.wen, test_commit_msg.ppreg, '{default:1} );
//       end
//     join
//   end

//   t.test_case_end();
// endtask

//----------------------------------------------------------------------
// run_multi_test_cases
//----------------------------------------------------------------------

task run_multi_test_cases();
  test_case_multi_basic_sequential();
  test_case_multi_basic_concurrent();
  test_case_multi_ooo();
endtask
