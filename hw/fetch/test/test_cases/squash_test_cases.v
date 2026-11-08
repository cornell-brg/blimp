//========================================================================
// squash_test_cases.v
//========================================================================
// Test cases to check handling of a squash

//----------------------------------------------------------------------
// test_case_squash_basic
//----------------------------------------------------------------------

task test_case_squash_basic();
  t.test_case_begin( "test_case_squash_basic" );
  if( !t.run_test ) return;

  //               addr  data
  fl_mem.init_mem( 'h000, 32'hdeadbeef );
  fl_mem.init_mem( 'h004, 32'hcafef00d );
  fl_mem.init_mem( 'h008, 32'hbaadb0ba );

  //    inst          pc     seq_num
  recv( 32'hdeadbeef, 'h000, 0 );

  //      seq_num target
  squash( 0,      'h008 );

  recv( 32'hbaadb0ba, 'h008, 1 );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_squash_forward
//----------------------------------------------------------------------

task test_case_squash_forward();
  t.test_case_begin( "test_case_squash_forward" );
  if( !t.run_test ) return;

  //               addr  data
  fl_mem.init_mem( 'h000, 32'h10101010 );
  fl_mem.init_mem( 'h004, 32'h20202020 );
  fl_mem.init_mem( 'h008, 32'h30303030 );
  fl_mem.init_mem( 'h00c, 32'h40404040 );
  fl_mem.init_mem( 'h010, 32'h50505050 );

  //    inst          pc     seq_num
  recv( 32'h10101010, 'h000, 0 );
  recv( 32'h20202020, 'h004, 1 );

  //      seq_num target
  squash( 0,      'h00c );

  recv( 32'h40404040, 'h00c, 1 );
  recv( 32'h50505050, 'h010, 2 );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_squash_backward
//----------------------------------------------------------------------

task test_case_squash_backward();
  t.test_case_begin( "test_case_squash_backward" );
  if( !t.run_test ) return;

  //               addr  data
  fl_mem.init_mem( 'h000, 32'hf0f0f0f0 );
  fl_mem.init_mem( 'h004, 32'he0e0e0e0 );
  fl_mem.init_mem( 'h008, 32'hd0d0d0d0 );
  fl_mem.init_mem( 'h00c, 32'hc0c0c0c0 );

  //    inst          pc     seq_num
  recv( 32'hf0f0f0f0, 'h000, 0 );
  recv( 32'he0e0e0e0, 'h004, 1 );
  recv( 32'hd0d0d0d0, 'h008, 2 );

  //      seq_num target
  squash( 1,      'h000 );

  recv( 32'hf0f0f0f0, 'h000, 2 );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_squash_many
//----------------------------------------------------------------------

task test_case_squash_many();
  t.test_case_begin( "test_case_squash_many" );
  if( !t.run_test ) return;

  //               addr  data
  fl_mem.init_mem( 'h000, 32'hf0f0f0f0 );
  fl_mem.init_mem( 'h004, 32'he0e0e0e0 );
  fl_mem.init_mem( 'h008, 32'hd0d0d0d0 );
  fl_mem.init_mem( 'h00c, 32'hc0c0c0c0 );

  //    inst          pc     seq_num
  recv( 32'hf0f0f0f0, 'h000, 0 );

  // Delay to build up in-flight requests
  for( int i = 0; i < 5; i = i + 1 ) begin
    @( posedge clk );
    #1;
  end

  //      seq_num target
  squash( 0,      'h000 );

  recv( 32'hf0f0f0f0, 'h000, 1 );

  for( int i = 0; i < 5; i = i + 1 ) begin
    @( posedge clk );
    #1;
  end

  //      seq_num target
  squash( 1,      'h000 );

  recv( 32'hf0f0f0f0, 'h000, 2 );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_squash_multi
//----------------------------------------------------------------------

task test_case_squash_multi();
  t.test_case_begin( "test_case_squash_multi" );
  if( !t.run_test ) return;

  //               addr  data
  fl_mem.init_mem( 'h000, 32'hf0f0f0f0 );
  fl_mem.init_mem( 'h004, 32'he0e0e0e0 );
  fl_mem.init_mem( 'h008, 32'hd0d0d0d0 );
  fl_mem.init_mem( 'h00c, 32'hc0c0c0c0 );

  //    inst          pc     seq_num
  recv( 32'hf0f0f0f0, 'h000, 0 );

  for( int j = 1; j < 4; j = j + 1 ) begin
    // Delay to build up in-flight requests
    for( int i = 0; i < 10; i = i + 1 ) begin
      @( posedge clk );
      #1;
    end

    //      seq_num                 target
    squash( p_seq_num_bits'(j - 1), 'h000 );

    recv( 32'hf0f0f0f0, 'h000, p_seq_num_bits'(j) );
  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_squash_max_in_flight
//----------------------------------------------------------------------

task test_case_squash_max_in_flight();
  t.test_case_begin( "test_case_squash_max_in_flight" );
  if( !t.run_test ) return;

  for( int i = 0; i < 3 * p_max_in_flight + 4; i = i + 1 ) begin
    //               addr                data
    fl_mem.init_mem( 'h000 + 32'(4 * i), 32'(i) );
  end

  // Wait a while, then squash multiple times
  for( int i = 0; i < 3; i = i + 1 ) begin
    for( int j = 0; j < p_max_in_flight; j = j + 1 ) begin
      @( posedge clk ); // Request is sent out
      #1;
    end
    squash( 0, 'h000 );
  end

  // Check that we still receive the correct messages
  for( int i = 0; i < 2 * p_max_in_flight; i = i + 1 ) begin
    //    inst    pc              seq_num
    recv( 32'(i), 'h000 + 32'(4 * i), p_seq_num_bits'(i + 1) );
    commit( p_seq_num_bits'(i + 1) );
  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_squash_test_cases
//----------------------------------------------------------------------

task run_squash_test_cases();
  test_case_squash_basic();
  test_case_squash_forward();
  test_case_squash_backward();
  test_case_squash_many();
  test_case_squash_multi();
  test_case_squash_max_in_flight();
endtask
