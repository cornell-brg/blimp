//========================================================================
// multi_rename_v10_test_cases.v
//========================================================================
// multi test cases for a renaming decode-issue unit (to ensure baseline
// functionality)

//----------------------------------------------------------------------
// test_case_multi_v10
//----------------------------------------------------------------------

task test_case_multi_v10();
  t.test_case_begin( "test_case_multi_v10" );
  if( !t.run_test ) return;

  fork
    begin
      //   addr   inst               seq_num
      send('h200, "mul  x1, x0, x0", 0);
      send('h204, "addi x1, x0, 10", 1);
    end

    begin
      //   pc     seq_num op1 op2  waddr preg ppreg uop
      recv('h200, 0,      0,   0,  1,    32,  1,    OP_MUL);

      //        seq_num  waddr    wdata    wen      preg      val
      complete( '{0, 0}, '{1, 0}, '{0, 0}, '{1, 0}, '{32, 0}, '{1, 0});

      //      pc            seq_num  waddr    wdata    wen      ppreg    val
      commit( '{'h200, '0}, '{0, 0}, '{1, 0}, '{0, 0}, '{1, 0}, '{33, 0}, '{1, 0} );

      //   pc     seq_num op1 op2  waddr preg ppreg uop
      recv('h204, 1,      0,  10,  1,    33,  32,   OP_ADD);
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_pending
//----------------------------------------------------------------------

// task test_case_pending();
//   t.test_case_begin( "test_case_pending" );
//   if( !t.run_test ) return;

//   //   Initialize (ignore ppreg, write to preg)
//   // 
//   //        pc  seq_num waddr wdata wen preg ppreg
//   complete(     'x,     1,    1,    1,  1       );
//   commit  ( 'x, 'x,     1,    1,    1,       32 );
//   complete(     'x,     3,    3,    1,  3       );
//   commit  ( 'x, 'x,     3,    3,    1,       32 );
//   complete(     'x,     5,    5,    1,  5       );
//   commit  ( 'x, 'x,     5,    5,    1,       32 );

//   fork
//     begin
//       //   addr    inst              seq_num
//       send('h200, "add  x2, x0, x1", 0);
//       send('h204, "add  x4, x3, x2", 1);
//       send('h208, "add  x5, x5, x4", 2);
//       send('h20c, "add  x5, x5, x5", 3);
//       send('h210, "add  x6, x5, x4", 4);
//     end

//     begin
//       //   pc     seq_num op1 op2  waddr preg ppreg uop
//       recv('h200, 0,      0,   1,  2,    32,  2,    OP_ADD);
//       complete(        'x, 2, 1, 1, 32 );
//       commit  ( 'h200, 'x, 2, 1, 1,  2 );

//       recv('h204, 1,      3,   1,  4,    2,   4,    OP_ADD);
//       complete(        'x, 4, 4, 1,  2 );
//       commit  ( 'h204, 'x, 4, 4, 1,  4 );

//       recv('h208, 2,      5,   4,  5,    4,   5,    OP_ADD);
//       complete(        'x, 5, 9, 1,  4 );
//       commit  ( 'h208, 'x, 5, 9, 1,  5 );
      
//       recv('h20c,  3,     9,   9,  5,    5,   4,    OP_ADD);
//       complete(        'x, 5, 18, 1, 5 );
//       commit  ( 'h20c, 'x, 5, 18, 1, 5 );

//       recv('h210, 4,     18,   4,  6,    5,   6,    OP_ADD);
//     end
//   join

//   t.test_case_end();
// endtask

//----------------------------------------------------------------------
// run_multi_test_cases
//----------------------------------------------------------------------

task run_multi_test_cases();
  test_case_multi_v10();
  // test_case_pending();
endtask
