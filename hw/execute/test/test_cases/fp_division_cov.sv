
`ifndef VERILATOR

class fp_division_cov;

  virtual fp_division_cov divCov;

  covergroup cg @(posedge divCov.clk);

  internal_ground : coverpoint divCov.sign
  {
      bins zero = { 0 };
      bins one = { 1 };
  }

  internal_sticky : coverpoint divCov.exp
  {
      bins zero = { 0 };
      bins one = { 1 };
  }

  internal_roundb : coverpoint divCov.mant
  {
      bins zero = { 0 };
      bins one = { 1 };
  }

  internal_last_bit_mantissa : coverpoint divCov.gaurd
  {
      bins zero = { 0 };
      bins one = { 1 };
  }

  internal_denorm_one : coverpoint divCov.round
  {
      bins not_denorm = { 0 };
      bins is_denorm = { 1 };
  }

  internal_denorm_two : coverpoint divCov.sticky
  {
      bins not_denorm = { 0 };
      bins is_denorm = { 1 };
  }

  internal_nan_one : coverpoint divCov.round_result
  {
      bins not_nan = { 0 };
      bins is_nan = { 1 };
  }
//FINISH INTERNAL SIGNALS
  internal_nan_two : coverpoint divCov.internal_nan_two
  {
      bins not_nan = { 0 };
      bins is_nan = { 1 };
  }

  internal_signed_exponent_one : coverpoint divCov.signed_exponent_one
  {
      bins zero        = {9'b0};                 // all zeros
      bins pos_small   = {[9'b000000001:9'b000001111]}; // magnitude 1–15
      bins pos_medium  = {[9'b000010000:9'b011111111]}; // magnitude 16–255
      bins neg_small   = {[9'b100000001:9'b100001111]}; // magnitude 1–15
      bins neg_medium  = {[9'b100010000:9'b111111111]}; // magnitude 16–255
  }

  internal_signed_exponent_two : coverpoint divCov.signed_exponent_two
  {
      bins zero        = {9'b0};                 // all zeros
      bins pos_small   = {[9'b000000001:9'b000001111]}; // magnitude 1–15
      bins pos_medium  = {[9'b000010000:9'b011111111]}; // magnitude 16–255
      bins neg_small   = {[9'b100000001:9'b100001111]}; // magnitude 1–15
      bins neg_medium  = {[9'b100010000:9'b111111111]}; // magnitude 16–255
  }

  underflow : coverpoint divCov.underflow
  {
    bins zero = {0}; //no underflow
    bins one = {1}; //underflow
  }

  is_inf1_cp : coverpoint divCov.is_inf_one {
    bins no_inf = {0};
    bins inf    = {1};
  }

  is_inf2_cp : coverpoint divCov.is_inf_two {
      bins no_inf = {0};
      bins inf    = {1};
  }

  sign1_cp : coverpoint divCov.sign_one {
      bins pos = {0};
      bins neg = {1};
  }

  sign2_cp : coverpoint divCov.sign_two {
      bins pos = {0};
      bins neg = {1};
  }

  //TODO mantissa bits, zero.

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