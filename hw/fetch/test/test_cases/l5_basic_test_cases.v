//========================================================================
// l5_basic_test_cases.v
//========================================================================
// Basic test cases for the superscalar fetch unit (2-lane)

//----------------------------------------------------------------------
// test_case_1_basic_single_fetch_block
//----------------------------------------------------------------------

task test_case_1_basic_single_fetch_block();
  logic [31:0]               insts      [p_num_fe_lanes];
  logic [31:0]               pcs        [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_num    [p_num_fe_lanes];
  logic                      inst_valid [p_num_fe_lanes];
  logic                      valid      [p_num_fe_lanes];

  t.test_case_begin( "test_case_1_basic_single_fetch_block" );
  if( !t.run_test ) return;

  for( int i = 0; i < p_num_fe_lanes; i = i + 1 ) begin
    insts[i]      = 32'($urandom());
    pcs[i]        = 'h200 + (i << 2);
    seq_num[i]    = p_seq_num_bits'(i);
    inst_valid[i] = 1;
    valid[i]      = 1;
    fl_mem.init_mem( pcs[i], insts[i] );
  end

  recv_f__d_xfer( 
    insts,
    pcs,
    seq_num,
    inst_valid,
    valid
  );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_2_basic_many_fetch_blocks
//----------------------------------------------------------------------

task automatic test_case_2_basic_many_fetch_blocks();
  localparam num_blocks = 10;
  logic [p_seq_num_bits-1:0] curr_sn;
  logic [p_seq_num_bits-1:0] free_sn;

  logic [31:0]               insts      [num_blocks][p_num_fe_lanes];
  logic [31:0]               pcs        [num_blocks][p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_num    [num_blocks][p_num_fe_lanes];
  logic                      inst_valid [num_blocks][p_num_fe_lanes];
  logic                      valid      [num_blocks][p_num_fe_lanes];

  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  t.test_case_begin( "test_case_2_basic_many_fetch_blocks" );
  if( !t.run_test ) return;

  curr_sn = '0;
  free_sn = '0;

  // Set up stimuli
  for( int block = 0; block < num_blocks; block = block + 1 ) begin

    // Set up expected fetch block
    for( int i = 0; i < p_num_fe_lanes; i = i + 1 ) begin
      insts[block][i]      = 32'($urandom());
      pcs[block][i]        = 'h200 + (i << 2) + (block * p_num_fe_lanes * 4);
      seq_num[block][i]    = curr_sn;
      inst_valid[block][i] = 1;
      valid[block][i]      = 1;
      fl_mem.init_mem( pcs[block][i], insts[block][i] );

      curr_sn = curr_sn + 1;
    end
  end

  // Receive each fetch block
  for( int block = 0; block < num_blocks; block = block + 1 ) begin

    // Receive the fetch block
    recv_f__d_xfer(
      insts[block],
      pcs[block],
      seq_num[block],
      inst_valid[block],
      valid[block]
    );

    // Free seq nums from this block, p_num_be_lanes at a time
    for( int freed = 0; freed < p_num_fe_lanes; freed = freed + p_num_be_lanes ) begin
      for( int j = 0; j < p_num_be_lanes; j = j + 1 ) begin
        if( freed + j < p_num_fe_lanes ) begin
          seq_nums_to_free[j] = free_sn;
          valid_to_free[j]    = 1'b1;
          if( free_sn == (2**p_seq_num_bits) - 1 )
            free_sn = '0;
          else
            free_sn = free_sn + 1;
        end else begin
          seq_nums_to_free[j] = '0;
          valid_to_free[j]    = 1'b0;
        end
      end
      seq_free( seq_nums_to_free, valid_to_free );
    end

    // Wait for reclaim to complete
    for( int i = 0; i < (p_num_fe_lanes / p_reclaim_width) + 2; i++ ) begin
      @( posedge clk );
    end

  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_3_seq_nums_not_avail
//----------------------------------------------------------------------

task automatic test_case_3_seq_nums_not_avail();

  // Maximum fetch blocks before seq nums are exhausted (without any freeing)
  localparam max_blocks   = (p_num_seq_nums - 1) / p_num_fe_lanes;
  localparam extra_blocks = 4;
  localparam total_blocks = max_blocks + extra_blocks;

  logic [p_seq_num_bits-1:0] curr_sn;
  logic [p_seq_num_bits-1:0] free_sn;

  logic [31:0]               insts      [total_blocks][p_num_fe_lanes];
  logic [31:0]               pcs        [total_blocks][p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_num    [total_blocks][p_num_fe_lanes];
  logic                      inst_valid [total_blocks][p_num_fe_lanes];
  logic                      valid      [total_blocks][p_num_fe_lanes];

  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  t.test_case_begin( "test_case_3_seq_nums_not_avail" );
  if( !t.run_test ) return;

  curr_sn = '0;
  free_sn = '0;

  // Set up stimuli for all blocks

  for( int block = 0; block < total_blocks; block = block + 1 ) begin
    for( int i = 0; i < p_num_fe_lanes; i = i + 1 ) begin
      insts[block][i]      = 32'($urandom());
      pcs[block][i]        = 'h200 + (i << 2) + (block * p_num_fe_lanes * 4);
      seq_num[block][i]    = curr_sn;
      inst_valid[block][i] = 1;
      valid[block][i]      = 1;
      fl_mem.init_mem( pcs[block][i], insts[block][i] );

      curr_sn = curr_sn + 1;
    end
  end

  // Phase 1: Exhaust all sequence numbers by receiving max_blocks without
  // freeing any. After this, the SeqNumGenL5 cannot allocate anymore
  // sequence numbers and the fetch unit is forced to stall.

  for( int block = 0; block < max_blocks; block = block + 1 ) begin
    recv_f__d_xfer(
      insts[block],
      pcs[block],
      seq_num[block],
      inst_valid[block],
      valid[block]
    );
  end

  // Phase 2: Free one fetch block's worth of seq nums at a time, wait for
  // reclaim, then verify the fetch unit resumes by receiving the next block.

  for( int block = max_blocks; block < total_blocks; block = block + 1 ) begin

    // Free seq nums from the oldest uncommitted block
    for( int freed = 0; freed < p_num_fe_lanes; freed = freed + p_num_be_lanes ) begin
      for( int j = 0; j < p_num_be_lanes; j = j + 1 ) begin
        if( freed + j < p_num_fe_lanes ) begin
          seq_nums_to_free[j] = free_sn;
          valid_to_free[j]    = 1'b1;
          if( free_sn == (2**p_seq_num_bits) - 1 )
            free_sn = '0;
          else
            free_sn = free_sn + 1;
        end else begin
          seq_nums_to_free[j] = '0;
          valid_to_free[j]    = 1'b0;
        end
      end
      seq_free( seq_nums_to_free, valid_to_free );
    end

    // Wait for reclaim to complete
    for( int i = 0; i < (p_num_fe_lanes / p_reclaim_width) + 2; i = i + 1 ) begin
      @( posedge clk );
    end

    // Receive the next fetch block, verifying fetch has resumed
    recv_f__d_xfer(
      insts[block],
      pcs[block],
      seq_num[block],
      inst_valid[block],
      valid[block]
    );

  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_l5_basic_test_cases
//----------------------------------------------------------------------

task run_l5_basic_test_cases();
  test_case_1_basic_single_fetch_block();
  test_case_2_basic_many_fetch_blocks();
  test_case_3_seq_nums_not_avail();
endtask
