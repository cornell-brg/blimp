//========================================================================
// seq_num_test_cases.v
//========================================================================
// Basic test cases for a fetch unit that issues sequence numbers

//----------------------------------------------------------------------
// test_case_seq_num_1_basic
//----------------------------------------------------------------------

task test_case_seq_num_1_basic();
  t.test_case_begin( "test_case_seq_num_1_basic" );
  if( !t.run_test ) return;

  for( int i = 0; i < 8; i = i + 1 ) begin
    //               addr             data
    fl_mem.init_mem( 'h000 + (4 * i), i * 2 );
  end

  for( int i = 0; i < 8; i = i + 1 ) begin
    //    inst   pc               seq_num
    recv( i * 2, 'h000 + (4 * i), p_seq_num_bits'(i) );
  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_seq_num_2_capacity
//----------------------------------------------------------------------

task test_case_seq_num_2_capacity();
  t.test_case_begin( "test_case_seq_num_2_capacity" );
  if( !t.run_test ) return;

  for( int i = 0; i < 2 * p_num_seq_nums; i = i + 1 ) begin
    //               addr             data
    fl_mem.init_mem( 'h000 + (4 * i), i * 2 );
  end

  for( int i = 0; i < p_num_seq_nums - 1; i = i + 1 ) begin
    //    inst   pc               seq_num
    recv( i * 2, 'h000 + (4 * i), p_seq_num_bits'(i) );
  end

  // Commit instructions so we can issue more
  for( int i = p_num_seq_nums - 1; i < 2 * p_num_seq_nums; i = i + 1 ) begin
    commit( p_seq_num_bits'(i - (p_num_seq_nums - 1)) );

    //    inst   pc               seq_num
    recv( i * 2, 'h000 + (4 * i), p_seq_num_bits'(i) );
  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_seq_num_3_ooo_commit
//----------------------------------------------------------------------

task test_case_seq_num_3_ooo_commit();
  t.test_case_begin( "test_case_seq_num_3_ooo_commit" );
  if( !t.run_test ) return;

  for( int i = 0; i < 2 * p_num_seq_nums; i = i + 1 ) begin
    //               addr             data
    fl_mem.init_mem( 'h000 + (4 * i), i * 3 );
  end

  for( int i = 0; i < p_num_seq_nums - 1; i = i + 1 ) begin
    //    inst   pc               seq_num
    recv( i * 3, 'h000 + (4 * i), p_seq_num_bits'(i) );
  end

  // Commit outstanding instructions out-of-order
  for( int i = 0; i < p_num_seq_nums - 1; i = i + 1 ) begin
    commit( p_seq_num_bits'(p_num_seq_nums - i - 2) );
  end

  // Can now receive more
  for( int i = p_num_seq_nums - 1; i < ( 2 * p_num_seq_nums ) - 2; i = i + 1 ) begin

    //    inst   pc               seq_num
    recv( i * 3, 'h000 + (4 * i), p_seq_num_bits'(i) );
  end

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_basic_test_cases
//----------------------------------------------------------------------

task run_seq_num_test_cases();
  test_case_seq_num_1_basic();
  test_case_seq_num_2_capacity();
  test_case_seq_num_3_ooo_commit();
endtask
