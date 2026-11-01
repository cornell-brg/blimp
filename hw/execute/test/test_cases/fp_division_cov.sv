
`ifndef VERILATOR

class fp_division_cov;

  virtual fp_division_cov divCov;

  covergroup cg @(posedge divCov.clk);

  // Rounding
  internal_ground : coverpoint divCov.internal_ground
  {
      bins zero = { 0 };
      bins one = { 1 };
  }

  internal_sticky : coverpoint divCov.internal_sticky
  {
      bins zero = { 0 };
      bins one = { 1 };
  }

  internal_roundb : coverpoint divCov.internal_roundb
  {
      bins zero = { 0 };
      bins one = { 1 };
  }

  internal_last_bit_mantissa : coverpoint divCov.internal_last_bit_mantissa
  {
      bins zero = { 0 };
      bins one = { 1 };
  }

  // Special types of inputs: Denormal, Underflow, NaN, Inf, Zero
  internal_denorm_one : coverpoint divCov.internal_denorm_one
  {
      bins not_denorm = { 0 };
      bins is_denorm = { 1 };
  }

  internal_denorm_two : coverpoint divCov.internal_denorm_two
  {
      bins not_denorm = { 0 };
      bins is_denorm = { 1 };
  }

  underflow : coverpoint divCov.underflow
  {
    bins zero = {0}; //no underflow
    bins one = {1}; //underflow
  }

  internal_nan_one : coverpoint divCov.internal_nan_one
  {
      bins not_nan = { 0 };
      bins is_nan = { 1 };
  }

  internal_nan_two : coverpoint divCov.internal_nan_two
  {
      bins not_nan = { 0 };
      bins is_nan = { 1 };
  }

  is_inf1_cp : coverpoint divCov.is_inf_one {
    bins no_inf = {0};
    bins inf    = {1};
  }

  is_inf2_cp : coverpoint divCov.is_inf_two {
      bins no_inf = {0};
      bins inf    = {1};
  }

  zero1_cp : coverpoint divCov.zero_one {
      bins not_zero = {0};
      bins is_zero = {1};
  }

  zero2_cp : coverpoint divCov.zero_two {
      bins not_zero = {0};
      bins is_zero = {1};
  }

  // Exponent ranges (bias of 127)
  internal_biased_exponent_one : coverpoint divCov.signed_exponent_one
  {
      bins zero        = {8'b0};                 // all zeros, denorm
      bins neg_large   = {[8'b00000001:8'b00111111]}; // magnitude 1–191 (-126 to -64)
      bins neg_small  = {[8'b01000000:8'b01111111]}; // magnitude 16–127 (-63 to 0)
      bins pos_small   = {[8'b10000001:8'b10001111]}; // magnitude 128-191 (1-64)
      bins pos_large  = {[8'b10010000:8'b11111110]}; // magnitude 192-254 (65-127)
      bins one =       = {8'hFF}; // all ones, inf/nan
  }

  internal_biased_exponent_two : coverpoint divCov.signed_exponent_two
  {
      bins zero        = {8'b0};                 // all zeros, denorm
      bins neg_large   = {[8'b00000001:8'b00111111]}; // magnitude 1–191 (-126 to -64)
      bins neg_small  = {[8'b01000000:8'b01111111]}; // magnitude 16–127 (-63 to 0)
      bins pos_small   = {[8'b10000001:8'b10001111]}; // magnitude 128-191 (1-64)
      bins pos_large  = {[8'b10010000:8'b11111110]}; // magnitude 192-254 (65-127)
      bins one =       = {8'hFF}; // all ones, inf/nan
  }

  //Mantissa ranges
  internal_mantissa_one : coverpoint divCov.mantissa_one
  {
      bins zero        = {23'b0};                 // all zeros
      bins mag_low   = {[23'h000001:23'h2AAAAA]}; // magnitude 1st third
      bins mag_medium  = {[23'h2AAAAB:23'h555554]}; // magnitude 2nd third
      bins mag_high   = {[23'h555555:23'h7FFFFE]}; // magnitude 3rd third
      bins one  = {23'h7FFFFF}; // all ones
  }

  internal_mantissa_two : coverpoint divCov.mantissa_two
  {
      bins zero        = {23'b0};                 // all zeros
      bins mag_low   = {[23'h000001:23'h2AAAAA]}; // magnitude 1st third
      bins mag_medium  = {[23'h2AAAAB:23'h555554]}; // magnitude 2nd third
      bins mag_high   = {[23'h555555:23'h7FFFFE]}; // magnitude 3rd third
      bins one  = {23'h7FFFFF}; // all ones
  }

  //Positive and negative signs
  sign1_cp : coverpoint divCov.sign_one {
      bins pos = {0};
      bins neg = {1};
  }

  sign2_cp : coverpoint divCov.sign_two {
      bins pos = {0};
      bins neg = {1};
  }

  // Crosses must match coverpoint labels and end with semicolon
  mantissa_rounding : cross internal_last_bit_mantissa, internal_ground; // for rounding
  grs_combs: cross internal_ground, internal_roundb, internal_sticky; // all GRS combinations
  exponent_cross : cross internal_signed_exponent_one, internal_signed_exponent_two; // exponent difference checks
  exp_underflow_cross : cross internal_signed_exponent_one,
                       internal_signed_exponent_two,
                       underflow {
  illegal_bins uf_no_negative_partner =
    binsof(underflow.one) &&
    binsof(internal_signed_exponent_one) intersect { [9'b000000000:9'b011111111] } &&
    binsof(internal_signed_exponent_two) intersect { [9'b000000000:9'b011111111] };
  
  ignore_bins uf_max_pos_neg = 
    binsof(underflow.one) &&
    binsof(internal_signed_exponent_one) intersect { [9'b000100000:9'b011111111] } &&
    binsof(internal_signed_exponent_two) intersect { [9'b100100000:9'b111111111] };
}
  inf_sign_cross : cross is_inf1_cp, is_inf2_cp, sign1_cp, sign2_cp; //compares all combinations of signed inf as inputs
  endgroup

  function new(virtual adder_intf divCov);
    this.divCov = divCov;
    cg = new; //create new instance of class
  endfunction


endclass
`endif