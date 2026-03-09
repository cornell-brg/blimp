//========================================================================
// squash_test_cases.v
//========================================================================
// Test cases to check handling of a squash

//----------------------------------------------------------------------
// test_case_1_squash_fetch_base_before
//----------------------------------------------------------------------

task automatic test_case_1_squash_fetch_base_before();
  localparam num_blocks = 2;
  logic [p_seq_num_bits-1:0] curr_sn;
  logic [p_seq_num_bits-1:0] free_sn;

  logic [31:0]               insts      [num_blocks][p_num_fe_lanes];
  logic [31:0]               pcs        [num_blocks][p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_num    [num_blocks][p_num_fe_lanes];
  logic                      inst_valid [num_blocks][p_num_fe_lanes];
  logic                      valid      [num_blocks][p_num_fe_lanes];

  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  t.test_case_begin( "test_case_1_squash_fetch_base_before" );
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

  
  // Receive all fetch blocks
  for ( int block = 0; block < num_blocks; block = block + 1 ) begin
    recv_f__d_xfer( 
      insts[block],
      pcs[block],
      seq_num[block],
      inst_valid[block],
      valid[block]
    );

    // Free seq nums from this block if not many sequence number available
    if (p_seq_num_bits < 4) begin
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
    end
  end

  // Squash to base of first fetch block
  squash( 0, 'h200 );

  // Check we re-fetch the first block
  // with sequence numbers starting at 1 after the squash's seq num
  for( int i = 0; i < p_num_fe_lanes; i = i + 1 ) begin
    seq_num[0][i] = p_seq_num_bits'(i + 1);
  end
  recv_f__d_xfer(
    insts[0],
    pcs[0],
    seq_num[0],
    inst_valid[0],
    valid[0]
  );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_2_squash_fetch_base_after
//----------------------------------------------------------------------

task automatic test_case_2_squash_fetch_base_after();
  localparam num_blocks = 5;
  logic [p_seq_num_bits-1:0] curr_sn;
  logic [p_seq_num_bits-1:0] free_sn;

  logic [31:0]               insts      [num_blocks][p_num_fe_lanes];
  logic [31:0]               pcs        [num_blocks][p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_num    [num_blocks][p_num_fe_lanes];
  logic                      inst_valid [num_blocks][p_num_fe_lanes];
  logic                      valid      [num_blocks][p_num_fe_lanes];

  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  t.test_case_begin( "test_case_2_squash_fetch_base_after" );
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

  
  // Receive first fetch block
  recv_f__d_xfer( 
    insts[0],
    pcs[0],
    seq_num[0],
    inst_valid[0],
    valid[0]
  );

  // Free seq nums from this block if not many sequence number available
  if (p_seq_num_bits < 4) begin
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
  end

  // Squash to base of fifth fetch block
  squash(0, 'h200 + (4 * p_num_fe_lanes * 4) );

  // Check we fetch the fifth block
  // with sequence numbers starting at 1 after the squash's seq num
  for( int i = 0; i < p_num_fe_lanes; i = i + 1 ) begin
    seq_num[4][i] = p_seq_num_bits'(i + 1);
  end
  recv_f__d_xfer(
    insts[4],
    pcs[4],
    seq_num[4],
    inst_valid[4],
    valid[4]
  );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_3_squash_fetch_middle_before
//----------------------------------------------------------------------

task automatic test_case_3_squash_fetch_middle_before();
  localparam num_blocks = 2;
  logic [p_seq_num_bits-1:0] curr_sn;
  logic [p_seq_num_bits-1:0] free_sn;

  logic [31:0]               insts      [num_blocks][p_num_fe_lanes];
  logic [31:0]               pcs        [num_blocks][p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_num    [num_blocks][p_num_fe_lanes];
  logic                      inst_valid [num_blocks][p_num_fe_lanes];
  logic                      valid      [num_blocks][p_num_fe_lanes];

  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  t.test_case_begin( "test_case_3_squash_fetch_middle_before" );
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

  // Receive all fetch blocks
  for ( int block = 0; block < num_blocks; block = block + 1 ) begin
    recv_f__d_xfer( 
      insts[block],
      pcs[block],
      seq_num[block],
      inst_valid[block],
      valid[block]
    );

    // Free seq nums from this block if not many sequence number available
    if (p_seq_num_bits < 4) begin
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
    end
  end

  // Squash to middle of first fetch block
  if (p_num_fe_lanes > 1) begin
    squash( 1, 'h204 );
    inst_valid[0][0] = 0;
    for( int i = 1; i < p_num_fe_lanes; i = i + 1 ) begin
      seq_num[0][i] = p_seq_num_bits'(i + 1);
    end
  end else begin
    squash( 0, 'h200 );
    seq_num[0][0] = 1;
  end

  // Check we re-fetch the first block
  // with sequence numbers starting at 1 after the squash's seq num
  recv_f__d_xfer(
    insts[0],
    pcs[0],
    seq_num[0],
    inst_valid[0],
    valid[0]
  );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_4_squash_fetch_middle_after
//----------------------------------------------------------------------

task automatic test_case_4_squash_fetch_middle_after();
  localparam num_blocks = 5;
  logic [p_seq_num_bits-1:0] curr_sn;
  logic [p_seq_num_bits-1:0] free_sn;

  logic [31:0]               insts      [num_blocks][p_num_fe_lanes];
  logic [31:0]               pcs        [num_blocks][p_num_fe_lanes];
  logic [p_seq_num_bits-1:0] seq_num    [num_blocks][p_num_fe_lanes];
  logic                      inst_valid [num_blocks][p_num_fe_lanes];
  logic                      valid      [num_blocks][p_num_fe_lanes];

  logic [p_seq_num_bits-1:0] seq_nums_to_free [p_num_be_lanes];
  logic                      valid_to_free    [p_num_be_lanes];

  t.test_case_begin( "test_case_4_squash_fetch_middle_after" );
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


  // Receive first fetch block
  recv_f__d_xfer(
    insts[0],
    pcs[0],
    seq_num[0],
    inst_valid[0],
    valid[0]
  );

  // Free seq nums from this block if not many sequence number available
  if (p_seq_num_bits < 4) begin
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
  end

  // Squash to middle of fifth fetch block (ahead of current)
  if (p_num_fe_lanes > 1) begin
    squash( 1, 'h200 + (4 * p_num_fe_lanes * 4) + 4 );
    inst_valid[4][0] = 0;
    seq_num[4][0]    = 0;
    for( int i = 1; i < p_num_fe_lanes; i = i + 1 ) begin
      seq_num[4][i] = p_seq_num_bits'(i + 1);
    end
  end else begin
    squash( 0, 'h200 + (4 * p_num_fe_lanes * 4) );
    seq_num[4][0] = 1;
  end

  // Check we fetch the fifth block with correct inst_valid and seq nums
  recv_f__d_xfer(
    insts[4],
    pcs[4],
    seq_num[4],
    inst_valid[4],
    valid[4]
  );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_l5_squash_test_cases
//----------------------------------------------------------------------

task run_l5_squash_test_cases();
  test_case_1_squash_fetch_base_before();
  test_case_2_squash_fetch_base_after();
  test_case_3_squash_fetch_middle_before();
  test_case_4_squash_fetch_middle_after();
endtask
