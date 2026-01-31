//========================================================================
// multi_test_cases.v
//========================================================================

//----------------------------------------------------------------------
// test_case_multi
//----------------------------------------------------------------------

task test_case_multi_sequential();
  t.test_case_begin( "test_case_multi_sequential" );
  if( !t.run_test ) return;

  fork
    begin
      //   pipe pc  seq_num addr  data          wen preg ppreg
      send(0,   '0, 0,      5'h1, 32'hdeadbeef, 1,  32,  1 );
      send(1,   '1, 1,      5'h2, 32'hcafecafe, 1,  33,  2 );
    end

    begin
      //           seq_num   addr         data                 wen       preg       val 
      complete_sub('{0, 'x}, '{5'h1, 'x}, '{32'hdeadbeef, 'x}, '{1, 'x}, '{32, 'x}, '{1, 0} );
      complete_sub('{1, 'x}, '{5'h2, 'x}, '{32'hcafecafe, 'x}, '{1, 'x}, '{33, 'x}, '{1, 0} );
    end

    begin
      //         pc        seq_num   addr          data                wen       ppreg     val
      commit_sub('{0, 'x}, '{0, 'x}, '{5'h1, 'x}, '{32'hdeadbeef, 'x}, '{1, 'x}, '{1, 'x}, '{1, 0} );
      commit_sub('{1, 'x}, '{1, 'x}, '{5'h2, 'x}, '{32'hcafecafe, 'x}, '{1, 'x}, '{2, 'x}, '{1, 0} );
    end
  join

  t.test_case_end();
endtask

task test_case_multi_concurrent();
  t.test_case_begin( "test_case_multi_concurrent" );
  if( !t.run_test ) return;

  fork
    begin
      //   pipe pc  seq_num addr  data          wen preg ppreg
      send(0,   '0, 0,      5'h1, 32'hdeadbeef, 1,  32,  1 );
    end

    begin
      //   pipe pc  seq_num addr  data          wen preg ppreg
      send(1,   '1, 1,      5'h2, 32'hcafecafe, 1,  33,  2 );
    end

    begin
      //           seq_num  addr           data                           wen      preg       val   
      complete_sub('{0, 1}, '{5'h1, 5'h2}, '{32'hdeadbeef, 32'hcafecafe}, '{1, 1}, '{32, 33}, '{1, 1} );
    end

    begin
      //         pc       seq_num  addr           data                           wen      ppreg    val
      commit_sub('{0, 1}, '{0, 1}, '{5'h1, 5'h2}, '{32'hdeadbeef, 32'hcafecafe}, '{1, 1}, '{1, 2}, '{1, 1} );
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_multi_test_cases
//----------------------------------------------------------------------

task run_multi_test_cases();
  test_case_multi_sequential();
  test_case_multi_concurrent();
endtask
