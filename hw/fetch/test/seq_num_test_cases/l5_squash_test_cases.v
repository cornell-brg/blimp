//========================================================================
// l5_squash_test_cases.v
//========================================================================
// Tests that the superscalar sequence number generator handles squashing

//----------------------------------------------------------------------
// test_case_squash_basic
//----------------------------------------------------------------------
// Allocate one batch, squash all but the first seq_num, free the
// first, and verify all entries are reclaimed

task test_case_squash_basic();
  logic [p_seq_num_bits-1:0] seq_nums         [p_num_fe_lanes];
  logic                      valid            [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  t.test_case_begin( "test_case_squash_basic" );
  if( !t.run_test ) return;

  // Allocate p_num_fe_lanes seq_nums (0 through p_num_fe_lanes-1)
  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    seq_nums[i] = p_seq_num_bits'(i);
    valid[i]    = 1'b1;
  end
  recv_seq_alloc( seq_nums, valid );
  check_allocated( p_num_fe_lanes );

  // Squash at 0: seq_nums > 0 are squashed
  squash( p_seq_num_bits'(0) );

  // Free seq_num 0 via commit
  for( int j = 0; j < p_num_be_lanes; j++ ) begin
    seq_nums_to_free[j] = '0;
    valid_to_free[j]    = (j == 0) ? 1'b1 : 1'b0;
  end
  seq_free( seq_nums_to_free, valid_to_free );

  // Wait for reclaim
  for( int i = 0; i < (p_num_fe_lanes / p_reclaim_width) + 2; i++ ) begin
    @( posedge clk );
  end

  check_allocated( 0 );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_squash_resume
//----------------------------------------------------------------------
// After squash, verify seq_nums resume from squash.seq_num + 1

task test_case_squash_resume();
  logic [p_seq_num_bits-1:0] seq_nums         [p_num_fe_lanes];
  logic                      valid            [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  automatic int seq_num_to_free = 0;

  t.test_case_begin( "test_case_squash_resume" );
  if( !t.run_test ) return;

  // First batch: seq_nums 0..p_num_fe_lanes-1
  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    seq_nums[i] = p_seq_num_bits'(i);
    valid[i]    = 1'b1;
  end
  recv_seq_alloc( seq_nums, valid );

  // Second batch: seq_nums p_num_fe_lanes..2*p_num_fe_lanes-1
  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    seq_nums[i] = p_seq_num_bits'(p_num_fe_lanes + i);
    valid[i]    = 1'b1;
  end
  recv_seq_alloc( seq_nums, valid );
  check_allocated( 2 * p_num_fe_lanes );

  // Squash at p_num_fe_lanes-1: second batch is squashed, head resets
  squash( p_seq_num_bits'(p_num_fe_lanes - 1) );

  // Next allocation should resume from p_num_fe_lanes
  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    seq_nums[i] = p_seq_num_bits'(p_num_fe_lanes + i);
    valid[i]    = 1'b1;
  end
  recv_seq_alloc( seq_nums, valid );
  check_allocated( 2 * p_num_fe_lanes );

  // Free all 2*p_num_fe_lanes seq_nums in batches of p_num_be_lanes
  seq_num_to_free = 0;
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

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_squash_capacity
//----------------------------------------------------------------------
// Fill to near capacity, squash all but first, free it, then continue

task test_case_squash_capacity();
  logic [p_seq_num_bits-1:0] seq_nums         [p_num_fe_lanes];
  logic                      valid            [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  automatic int num_batches     = (p_num_seq_nums - 2) / p_num_fe_lanes;
  automatic int total_allocated = num_batches * p_num_fe_lanes;

  t.test_case_begin( "test_case_squash_capacity" );
  if( !t.run_test ) return;

  // Fill to near capacity
  for( int i = 0; i < num_batches; i++ ) begin
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      seq_nums[j] = p_seq_num_bits'(i * p_num_fe_lanes + j);
      valid[j]    = 1'b1;
    end
    recv_seq_alloc( seq_nums, valid );
  end
  check_allocated( total_allocated );

  // Squash at 0: all but seq_num 0 are squashed
  squash( p_seq_num_bits'(0) );

  // Free seq_num 0 via commit
  for( int j = 0; j < p_num_be_lanes; j++ ) begin
    seq_nums_to_free[j] = '0;
    valid_to_free[j]    = (j == 0) ? 1'b1 : 1'b0;
  end
  seq_free( seq_nums_to_free, valid_to_free );

  // Wait for reclaim
  for( int i = 0; i < (total_allocated / p_reclaim_width) + 2; i++ ) begin
    @( posedge clk );
  end

  // Verify we can continue allocating from seq_num 1
  for( int i = 0; i < 4; i++ ) begin
    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      seq_nums[j] = p_seq_num_bits'(1 + i * p_num_fe_lanes + j);
      valid[j]    = 1'b1;
    end
    recv_seq_alloc( seq_nums, valid );
  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_squash_multiple
//----------------------------------------------------------------------
// Multiple squashes in a row, then free all live seq_nums

task test_case_squash_multiple();
  logic [p_seq_num_bits-1:0] seq_nums         [p_num_fe_lanes];
  logic                      valid            [p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  automatic int num_live        = 0;
  automatic int seq_num_to_free = 0;

  t.test_case_begin( "test_case_squash_multiple" );
  if( !t.run_test ) return;

  // Round 1: Allocate 0..p_num_fe_lanes-1, squash at 0
  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    seq_nums[i] = p_seq_num_bits'(i);
    valid[i]    = 1'b1;
  end
  recv_seq_alloc( seq_nums, valid );
  squash( p_seq_num_bits'(0) );

  // Round 2: Allocate 1..p_num_fe_lanes, squash at 1
  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    seq_nums[i] = p_seq_num_bits'(1 + i);
    valid[i]    = 1'b1;
  end
  recv_seq_alloc( seq_nums, valid );
  squash( p_seq_num_bits'(1) );

  // Round 3: Allocate 2..p_num_fe_lanes+1, squash at 2
  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    seq_nums[i] = p_seq_num_bits'(2 + i);
    valid[i]    = 1'b1;
  end
  recv_seq_alloc( seq_nums, valid );
  squash( p_seq_num_bits'(2) );

  // Round 4: Allocate 3..p_num_fe_lanes+2 (no squash)
  for( int i = 0; i < p_num_fe_lanes; i++ ) begin
    seq_nums[i] = p_seq_num_bits'(3 + i);
    valid[i]    = 1'b1;
  end
  recv_seq_alloc( seq_nums, valid );

  // Live seq_nums: 0, 1, 2, 3, ..., p_num_fe_lanes+2
  num_live = p_num_fe_lanes + 3;

  // Free all live seq_nums in batches of p_num_be_lanes
  seq_num_to_free = 0;
  while( seq_num_to_free < num_live ) begin
    for( int j = 0; j < p_num_be_lanes; j++ ) begin
      if( seq_num_to_free + j < num_live ) begin
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

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_squash_test_cases
//----------------------------------------------------------------------

task run_squash_test_cases();
  test_case_squash_basic();
  test_case_squash_resume();
  test_case_squash_capacity();
  test_case_squash_multiple();
endtask