//========================================================================
// fpinst_test_cases.v
//========================================================================
// Test cases for FPInstUnitL8

task test_case_fsgnj_basic();
  t.test_case_begin( "test_case_fsgnj_basic" );
  if ( !t.run_test ) return;

  fork
    send( 32'h0000_0200, p_seq_num_bits'(1),
          32'h3FA0_0000, // +1.25
          32'h8000_0000, // sign bit = 1
          5'd10,
          6'd12, 6'd3,
          1'b1,
          OP_FSGNJ_S );
    recv( 32'h0000_0200, p_seq_num_bits'(1),
          5'd10,
          32'hBFA0_0000, // -1.25
          1'b1,
          6'd12, 6'd3,
          1'b1 );
  join

  t.test_case_end();
endtask

task test_case_fsgnj_keep_positive();
  t.test_case_begin( "test_case_fsgnj_keep_positive" );
  if ( !t.run_test ) return;

  fork
    send( 32'h0000_0204, p_seq_num_bits'(2),
          32'hC048_0000, // -3.125
          32'h0000_0000, // sign bit = 0
          5'd11,
          6'd13, 6'd4,
          1'b1,
          OP_FSGNJ_S );
    recv( 32'h0000_0204, p_seq_num_bits'(2),
          5'd11,
          32'h4048_0000, // +3.125
          1'b1,
          6'd13, 6'd4,
          1'b1 );
  join

  t.test_case_end();
endtask

task test_case_fmv_x_w_passthrough_bits();
  t.test_case_begin( "test_case_fmv_x_w_passthrough_bits" );
  if ( !t.run_test ) return;

  fork
    send( 32'h0000_0208, p_seq_num_bits'(3),
          32'h4050_0000, // 3.25 bit pattern
          32'hDEAD_BEEF, // unused
          5'd12,
          6'd14, 6'd5,
          1'b0,          // destination is integer domain
          OP_FMV_X_W );
    recv( 32'h0000_0208, p_seq_num_bits'(3),
          5'd12,
          32'h4050_0000,
          1'b1,
          6'd14, 6'd5,
          1'b0 );
  join

  t.test_case_end();
endtask

task test_case_fmv_w_x_passthrough_bits();
  t.test_case_begin( "test_case_fmv_w_x_passthrough_bits" );
  if ( !t.run_test ) return;

  fork
    send( 32'h0000_020C, p_seq_num_bits'(4),
          32'hC120_0000, // arbitrary 32b pattern
          32'h1234_5678, // unused
          5'd13,
          6'd15, 6'd6,
          1'b1,          // destination is fp domain
          OP_FMV_W_X );
    recv( 32'h0000_020C, p_seq_num_bits'(4),
          5'd13,
          32'hC120_0000,
          1'b1,
          6'd15, 6'd6,
          1'b1 );
  join

  t.test_case_end();
endtask

task test_case_fcvt_w_s_positive_truncate();
  t.test_case_begin( "test_case_fcvt_w_s_positive_truncate" );
  if ( !t.run_test ) return;

  fork
    send( 32'h0000_0210, p_seq_num_bits'(5),
          32'h4050_0000, // 3.25
          32'h0000_0000, // unused
          5'd14,
          6'd16, 6'd7,
          1'b0,          // destination is integer domain
          OP_FCVT_W_S );
    recv( 32'h0000_0210, p_seq_num_bits'(5),
          5'd14,
          32'h0000_0003,
          1'b1,
          6'd16, 6'd7,
          1'b0 );
  join

  t.test_case_end();
endtask

task test_case_fcvt_w_s_negative_truncate();
  t.test_case_begin( "test_case_fcvt_w_s_negative_truncate" );
  if ( !t.run_test ) return;

  fork
    send( 32'h0000_0214, p_seq_num_bits'(6),
          32'hC030_0000, // -2.75
          32'h0000_0000, // unused
          5'd15,
          6'd17, 6'd8,
          1'b0,
          OP_FCVT_W_S );
    recv( 32'h0000_0214, p_seq_num_bits'(6),
          5'd15,
          32'hFFFF_FFFE, // -2
          1'b1,
          6'd17, 6'd8,
          1'b0 );
  join

  t.test_case_end();
endtask

task test_case_fcvt_w_s_underflow_to_zero();
  t.test_case_begin( "test_case_fcvt_w_s_underflow_to_zero" );
  if ( !t.run_test ) return;

  fork
    send( 32'h0000_0218, p_seq_num_bits'(7),
          32'h3DCC_CCCD, // ~0.1
          32'h0000_0000,
          5'd16,
          6'd18, 6'd9,
          1'b0,
          OP_FCVT_W_S );
    recv( 32'h0000_0218, p_seq_num_bits'(7),
          5'd16,
          32'h0000_0000,
          1'b1,
          6'd18, 6'd9,
          1'b0 );
  join

  t.test_case_end();
endtask

task test_case_fcvt_w_s_pos_inf_saturate();
  t.test_case_begin( "test_case_fcvt_w_s_pos_inf_saturate" );
  if ( !t.run_test ) return;

  fork
    send( 32'h0000_021C, p_seq_num_bits'(8),
          32'h7F80_0000, // +inf
          32'h0000_0000,
          5'd17,
          6'd19, 6'd10,
          1'b0,
          OP_FCVT_W_S );
    recv( 32'h0000_021C, p_seq_num_bits'(8),
          5'd17,
          32'h7FFF_FFFF,
          1'b1,
          6'd19, 6'd10,
          1'b0 );
  join

  t.test_case_end();
endtask

task test_case_fcvt_w_s_neg_inf_saturate();
  t.test_case_begin( "test_case_fcvt_w_s_neg_inf_saturate" );
  if ( !t.run_test ) return;

  fork
    send( 32'h0000_0220, p_seq_num_bits'(9),
          32'hFF80_0000, // -inf
          32'h0000_0000,
          5'd18,
          6'd20, 6'd11,
          1'b0,
          OP_FCVT_W_S );
    recv( 32'h0000_0220, p_seq_num_bits'(9),
          5'd18,
          32'h8000_0000,
          1'b1,
          6'd20, 6'd11,
          1'b0 );
  join

  t.test_case_end();
endtask

task run_fpinst_test_cases();
  test_case_fsgnj_basic();
  test_case_fsgnj_keep_positive();
  test_case_fmv_x_w_passthrough_bits();
  test_case_fmv_w_x_passthrough_bits();
  test_case_fcvt_w_s_positive_truncate();
  test_case_fcvt_w_s_negative_truncate();
  test_case_fcvt_w_s_underflow_to_zero();
  test_case_fcvt_w_s_pos_inf_saturate();
  test_case_fcvt_w_s_neg_inf_saturate();
endtask
