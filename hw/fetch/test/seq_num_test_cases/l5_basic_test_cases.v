//========================================================================
// l5_basic_test_cases.v
//========================================================================
// Basic tests for the superscalar sequence number generator (2-lane)

//----------------------------------------------------------------------
// test_case_1_basic_single_lane - Allocate a single lane and check seq num 0
// has been allocated to it
//----------------------------------------------------------------------

task test_case_1_basic_single_lane();
  logic [p_seq_num_bits-1:0] seq_nums [p_num_fe_lanes];
  logic                      valid    [p_num_fe_lanes];

  t.test_case_begin( "test_case_1_basic_single_lane" );
  if( !t.run_test ) return;

  for( int i = 0; i < p_num_fe_lanes; i = i + 1 ) begin
    seq_nums[i] = p_seq_num_bits'(0);
    valid[i]    = i == p_num_fe_lanes - 1; // Only last lane valid
  end

  recv_seq_alloc( seq_nums, valid );

  check_allocated( 1 );

  t.test_case_end();
endtask


//----------------------------------------------------------------------
// test_case_2_basic_multi_lane - Allocate multiple lanes and check seq nums
// have been allocated to them
//----------------------------------------------------------------------

task test_case_2_basic_multi_lane();
  logic [p_seq_num_bits-1:0] seq_nums [p_num_fe_lanes];
  logic                      valid    [p_num_fe_lanes];

  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  automatic int seq_num_to_free = 0;
  automatic int cntr = 0;

  t.test_case_begin( "test_case_2_basic_multi_lane" );
  if( !t.run_test ) return;

  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    seq_nums[i] = p_seq_num_bits'(i);
    valid[i]    = 1'b1; // All lanes valid
  end

  recv_seq_alloc( seq_nums, valid );

  check_allocated( p_num_fe_lanes );
  seq_num_to_free = 0;

  // Free all allocated sequence numbers in batches of p_num_be_lanes
  while( seq_num_to_free < p_num_fe_lanes ) begin
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      if( seq_num_to_free + j < p_num_fe_lanes ) begin
        seq_nums_to_free[j] = p_seq_num_bits'(seq_num_to_free + j);
        valid_to_free[j]    = 1'b1;
      end else begin
        seq_nums_to_free[j] = '0;
        valid_to_free[j]    = 1'b0;
      end
    end
    seq_free( seq_nums_to_free, valid_to_free );
    seq_num_to_free += p_num_be_lanes;
  end

  for( int i = 0; i < (p_num_fe_lanes / p_reclaim_width) + 2; i++ ) begin
    @( posedge clk );
  end
  check_allocated( 0 );

  // Check some lanes are allocated but others are not (only if > 2 lanes)
  if( p_num_fe_lanes > 2 ) begin
    cntr = 0;
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      seq_nums[i] = p_seq_num_bits'(cntr + p_num_fe_lanes);
      valid[i]    = (i % 2) == 0; // Only even lanes valid
      if( valid[i] ) cntr++;
    end

    recv_seq_alloc( seq_nums, valid );

    check_allocated( (p_num_fe_lanes / 2) );
  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_3_consecutive_alloc - Multiple back-to-back allocations
// without freeing, verify allocated count grows correctly
//----------------------------------------------------------------------

task test_case_3_consecutive_alloc();
  logic [p_seq_num_bits-1:0] seq_nums [p_num_fe_lanes];
  logic                      valid    [p_num_fe_lanes];

  t.test_case_begin( "test_case_3_consecutive_alloc" );
  if( !t.run_test ) return;

  for( int b = 0; b < 4; b++ ) begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      seq_nums[i] = p_seq_num_bits'(b * p_num_fe_lanes + i);
      valid[i]    = 1'b1;
    end
    recv_seq_alloc( seq_nums, valid );
    check_allocated( (b + 1) * p_num_fe_lanes );
  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_4_alloc_free_reuse - Allocate, free, reclaim, then
// reallocate to verify the alloc-free cycle works correctly
//----------------------------------------------------------------------

task test_case_4_alloc_free_reuse();
  logic [p_seq_num_bits-1:0] seq_nums         [p_num_fe_lanes];
  logic                      valid            [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  automatic int seq_num_to_free = 0;
  automatic int base = 0;

  t.test_case_begin( "test_case_4_alloc_free_reuse" );
  if( !t.run_test ) return;

  // Two full alloc-free cycles
  for( int cycle = 0; cycle < 2; cycle++ ) begin
    base = cycle * p_num_fe_lanes;

    // Allocate one batch
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      seq_nums[i] = p_seq_num_bits'(base + i);
      valid[i]    = 1'b1;
    end
    recv_seq_alloc( seq_nums, valid );
    check_allocated( p_num_fe_lanes );

    // Free the batch
    seq_num_to_free = base;
    while( seq_num_to_free < base + p_num_fe_lanes ) begin
      for( int j = 0; j < p_num_be_lanes; j++ ) begin
        if( seq_num_to_free + j < base + p_num_fe_lanes ) begin
          seq_nums_to_free[j] = p_seq_num_bits'(seq_num_to_free + j);
          valid_to_free[j]    = 1'b1;
        end else begin
          seq_nums_to_free[j] = '0;
          valid_to_free[j]    = 1'b0;
        end
      end
      seq_free( seq_nums_to_free, valid_to_free );
      seq_num_to_free += p_num_be_lanes;
    end

    // Wait for reclaim
    for( int i = 0; i < (p_num_fe_lanes / p_reclaim_width) + 2; i++ ) begin
      @( posedge clk );
    end
    check_allocated( 0 );
  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_5_capacity - Fill to near-max capacity, verify count, then
// free everything and verify full reclaim back to zero
//----------------------------------------------------------------------

task test_case_5_capacity();
  logic [p_seq_num_bits-1:0] seq_nums         [p_num_fe_lanes];
  logic                      valid            [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  automatic int num_batches     = (p_num_seq_nums - 2) / p_num_fe_lanes;
  automatic int total_allocated = num_batches * p_num_fe_lanes;
  automatic int seq_num_to_free = 0;

  t.test_case_begin( "test_case_5_capacity" );
  if( !t.run_test ) return;

  // Fill to near capacity
  for( int b = 0; b < num_batches; b++ ) begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      seq_nums[i] = p_seq_num_bits'(b * p_num_fe_lanes + i);
      valid[i]    = 1'b1;
    end
    recv_seq_alloc( seq_nums, valid );
  end
  check_allocated( total_allocated );

  // Free everything in batches of p_num_be_lanes
  seq_num_to_free = 0;
  while( seq_num_to_free < total_allocated ) begin
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      if( seq_num_to_free + j < total_allocated ) begin
        seq_nums_to_free[j] = p_seq_num_bits'(seq_num_to_free + j);
        valid_to_free[j]    = 1'b1;
      end else begin
        seq_nums_to_free[j] = '0;
        valid_to_free[j]    = 1'b0;
      end
    end
    seq_free( seq_nums_to_free, valid_to_free );
    seq_num_to_free += p_num_be_lanes;
  end

  // Wait for reclaim
  for( int i = 0; i < (total_allocated / p_reclaim_width) + 2; i++ ) begin
    @( posedge clk );
  end
  check_allocated( 0 );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_6_out_of_order_free - Free entries out of order and verify
// reclaim only advances when consecutive entries from the tail are free
//----------------------------------------------------------------------

task test_case_6_out_of_order_free();
  logic [p_seq_num_bits-1:0] seq_nums         [p_num_fe_lanes];
  logic                      valid            [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  automatic int seq_num_to_free = 0;

  t.test_case_begin( "test_case_6_out_of_order_free" );
  if( !t.run_test ) return;

  // Allocate two batches: seq_nums 0..2*p_num_fe_lanes-1
  for( int b = 0; b < 2; b++ ) begin
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      seq_nums[i] = p_seq_num_bits'(b * p_num_fe_lanes + i);
      valid[i]    = 1'b1;
    end
    recv_seq_alloc( seq_nums, valid );
  end
  check_allocated( 2 * p_num_fe_lanes );

  // Free the SECOND batch first (seq_nums p_num_fe_lanes..2*p_num_fe_lanes-1)
  seq_num_to_free = p_num_fe_lanes;
  while( seq_num_to_free < 2 * p_num_fe_lanes ) begin
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      if( seq_num_to_free + j < 2 * p_num_fe_lanes ) begin
        seq_nums_to_free[j] = p_seq_num_bits'(seq_num_to_free + j);
        valid_to_free[j]    = 1'b1;
      end else begin
        seq_nums_to_free[j] = '0;
        valid_to_free[j]    = 1'b0;
      end
    end
    seq_free( seq_nums_to_free, valid_to_free );
    seq_num_to_free += p_num_be_lanes;
  end

  // Wait -- reclaim should NOT advance past the un-freed first batch
  for( int i = 0; i < (p_num_fe_lanes / p_reclaim_width) + 2; i++ ) begin
    @( posedge clk );
  end
  check_allocated( 2 * p_num_fe_lanes );

  // Now free the FIRST batch (seq_nums 0..p_num_fe_lanes-1)
  seq_num_to_free = 0;
  while( seq_num_to_free < p_num_fe_lanes ) begin
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      if( seq_num_to_free + j < p_num_fe_lanes ) begin
        seq_nums_to_free[j] = p_seq_num_bits'(seq_num_to_free + j);
        valid_to_free[j]    = 1'b1;
      end else begin
        seq_nums_to_free[j] = '0;
        valid_to_free[j]    = 1'b0;
      end
    end
    seq_free( seq_nums_to_free, valid_to_free );
    seq_num_to_free += p_num_be_lanes;
  end

  // Now reclaim should advance through all entries
  for( int i = 0; i < (2 * p_num_fe_lanes / p_reclaim_width) + 2; i++ ) begin
    @( posedge clk );
  end
  check_allocated( 0 );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_basic_test_cases
//----------------------------------------------------------------------

task run_basic_test_cases();
  test_case_1_basic_single_lane();
  test_case_2_basic_multi_lane();
  test_case_3_consecutive_alloc();
  test_case_4_alloc_free_reuse();
  test_case_5_capacity();
  test_case_6_out_of_order_free();
endtask