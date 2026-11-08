//========================================================================
// csr_test_cases.v
//========================================================================
// Author: Emily Lan
//========================================================================

`ifndef CSR_TEST_CASES_V
`define CSR_TEST_CASES_V

//----------------------------------------------------------------------
// test_case_csrrw_basic
//----------------------------------------------------------------------
// CSRRW (atomic read/write): 
//   rd <= old CSR value
//   CSR <= rs1

task test_case_csrrw_basic();
  t.test_case_begin( "test_case_csrrw_basic" );
  if( !t.run_test ) return;

  fork
    begin
      //   pc  seq_num op1 op2 waddr uop
      send('0, 0, 32'h0000_0011, 32'h001, 5'h1, OP_CSRRW);
      send('0, 1, 32'h0000_0022, 32'h001, 5'h2, OP_CSRRW);
    end

    begin
      // recv( pc, seq_num, waddr, wdata, wen )
      recv('0, 0, 5'h1, 32'h0000_0000, 1);  
      recv('0, 1, 5'h2, 32'h0000_0011, 1);  

    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_csrrw_frm
//----------------------------------------------------------------------

task test_case_csrrw_frm();
  t.test_case_begin( "test_case_csrrw_frm" );
  if( !t.run_test ) return;

  fork
    begin
      send('0, 0, 32'h0000_0005, 32'h002, 5'h1, OP_CSRRW);
      send('0, 1, 32'h0000_0003, 32'h002, 5'h2, OP_CSRRW);
    end

    begin
      recv('0, 0, 5'h1, 32'h0000_0000, 1);  
      recv('0, 1, 5'h2, 32'h0000_0005, 1); 
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_csrrw_fcsr
//----------------------------------------------------------------------

task test_case_csrrw_fcsr();
  t.test_case_begin( "test_case_csrrw_fcsr" );
  if( !t.run_test ) return;

  fork
    begin
      send('0, 0, 32'h0000_00A5, 32'h003, 5'h1, OP_CSRRW);
      send('0, 1, 32'h0000_0073, 32'h003, 5'h2, OP_CSRRW);
    end

    begin
      recv('0, 0, 5'h1, 32'h0000_0000, 1);  
      recv('0, 1, 5'h2, 32'h0000_00A5, 1);  
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_csrrs_basic
//----------------------------------------------------------------------
// CSRRS (atomic read/set bits): 
//   rd <= old CSR value
//   CSR <= old | rs1

task test_case_csrrs_basic();
  t.test_case_begin( "test_case_csrrs_basic" );
  if( !t.run_test ) return;

  fork
    begin
      send('0, 0, 32'h0000_0003, 32'h001, 5'h1, OP_CSRRW);
      send('0, 1, 32'h0000_0014, 32'h001, 5'h2, OP_CSRRS);
      send('0, 2, 32'h0000_0000, 32'h001, 5'h3, OP_CSRRS);
    end

    begin
      recv('0, 0, 5'h1, 32'h0000_0000, 1);  
      recv('0, 1, 5'h2, 32'h0000_0003, 1);  
      recv('0, 2, 5'h3, 32'h0000_0017, 1);  
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_csrrc_basic
//----------------------------------------------------------------------
// CSRRC (atomic read/clear bits):
//   rd <= old CSR value
//   CSR <= old & ~rs1

task test_case_csrrc_basic();
  t.test_case_begin( "test_case_csrrc_basic" );
  if( !t.run_test ) return;

  fork
    begin
      send('0, 0, 32'h0000_001F, 32'h001, 5'h1, OP_CSRRW);
      send('0, 1, 32'h0000_000C, 32'h001, 5'h2, OP_CSRRC);
      send('0, 2, 32'h0000_0000, 32'h001, 5'h3, OP_CSRRC);
    end

    begin
      recv('0, 0, 5'h1, 32'h0000_0000, 1);  
      recv('0, 1, 5'h2, 32'h0000_001F, 1);  
      recv('0, 2, 5'h3, 32'h0000_0013, 1); 
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// test_case_csr_mixed
//----------------------------------------------------------------------

task test_case_csr_mixed();
  t.test_case_begin( "test_case_csr_mixed" );
  if( !t.run_test ) return;

  fork
    begin
      send('0, 0, 32'h0000_0055, 32'h003, 5'h1, OP_CSRRW);
      send('0, 1, 32'h0000_000A, 32'h003, 5'h2, OP_CSRRS);
      send('0, 2, 32'h0000_000C, 32'h003, 5'h3, OP_CSRRC);
    end

    begin
      recv('0, 0, 5'h1, 32'h0000_0000, 1);
      recv('0, 1, 5'h2, 32'h0000_0055, 1);
      recv('0, 2, 5'h3, 32'h0000_005F, 1);
    end
  join

  t.test_case_end();
endtask

//----------------------------------------------------------------------
// run_csr_test_cases
//----------------------------------------------------------------------

task run_csr_test_cases();
  test_case_csrrw_basic();
  test_case_csrrw_frm();
  test_case_csrrw_fcsr();
  test_case_csrrs_basic();
  test_case_csrrc_basic();
  test_case_csr_mixed();
endtask

`endif
