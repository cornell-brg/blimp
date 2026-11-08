//========================================================================
// basic_test_cases.v
//========================================================================
// Basic test cases for a modular fetch unit

//----------------------------------------------------------------------
// test_case_basic
//----------------------------------------------------------------------

task test_case_basic();
  t.test_case_begin( "test_case_basic" );
  if( !t.run_test ) return;

  //               addr  data
  fl_mem.init_mem( 'h000, 32'hdeadbeef );
  fl_mem.init_mem( 'h004, 32'hcafef00d );
  fl_mem.init_mem( 'h008, 32'hbaadb0ba );

  //    inst          pc     seq_num
  recv( 32'hdeadbeef, 'h000, 0 );
  recv( 32'hcafef00d, 'h004, 1 );
  recv( 32'hbaadb0ba, 'h008, 2 );

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_basic_test_cases
//----------------------------------------------------------------------

task run_basic_test_cases();
  test_case_basic();
endtask
