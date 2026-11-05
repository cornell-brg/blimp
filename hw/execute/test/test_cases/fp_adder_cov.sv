
`ifndef VERILATOR

class adder_cvg;

  virtual adder_intf vif;

  covergroup cg @(posedge vif.clk);

    internal_ground : coverpoint vif.internal_ground
    {
        bins zero = { 0 };
        bins one = { 1 };
    }

    internal_sticky : coverpoint vif.internal_sticky
    {
        bins zero = { 0 };
        bins one = { 1 };
    }

    internal_roundb : coverpoint vif.internal_roundb
    {
        bins zero = { 0 };
        bins one = { 1 };
    }

    internal_denorm_one : coverpoint vif.internal_denorm_one
    {
        bins not_denorm = { 0 };
        bins is_denorm = { 1 };
    }

    internal_denorm_two : coverpoint vif.internal_denorm_two
    {
        bins not_denorm = { 0 };
        bins is_denorm = { 1 };
    }

    internal_nan_one : coverpoint vif.internal_nan_one
    {
        bins not_nan = { 0 };
        bins is_nan = { 1 };
    }

    internal_nan_two : coverpoint vif.internal_nan_two
    {
        bins not_nan = { 0 };
        bins is_nan = { 1 };
    }

    internal_signed_exponent_one : coverpoint vif.signed_exponent_one
    {
        bins zero_or_subnorm = {9'b000000000, 9'b100000000};  // all zeros
        bins pos_small   = {[9'b000000001:9'b000001111]}; // magnitude 1–15
        bins pos_medium  = {[9'b000010000:9'b011111111]}; // magnitude 16–255
        bins neg_small   = {[9'b100000001:9'b100001111]}; // magnitude 1–15
        bins neg_medium  = {[9'b100010000:9'b111111111]}; // magnitude 16–255
    }

    internal_signed_exponent_two : coverpoint vif.signed_exponent_two
    {
        bins zero_or_subnorm = {9'b000000000, 9'b100000000};  // all zeros
        bins pos_small   = {[9'b000000001:9'b000001111]}; // magnitude 1–15
        bins pos_medium  = {[9'b000010000:9'b011111111]}; // magnitude 16–255
        bins neg_small   = {[9'b100000001:9'b100001111]}; // magnitude 1–15
        bins neg_medium  = {[9'b100010000:9'b111111111]}; // magnitude 16–255
    }

    internal_mantissa_one : coverpoint vif.mantissa_one
    {
      bins zero         = {23'd0};
      bins intermediate = {[23'd1 : 23'h7FFFFE]}; // 1 to max-1
      bins max          = {23'h7FFFFF};
    }

    internal_mantissa_two : coverpoint vif.mantissa_two
    {
      bins zero         = {23'd0};
      bins intermediate = {[23'd1 : 23'h7FFFFE]}; // 1 to max-1
      bins max          = {23'h7FFFFF};
    }

    underflow : coverpoint vif.underflow
    {
      bins zero = {0}; //no underflow
      bins one = {1}; //underflow
    }

    is_inf1_cp : coverpoint vif.is_inf_one {
      bins no_inf = {0};
      bins inf    = {1};
    }

    is_inf2_cp : coverpoint vif.is_inf_two {
        bins no_inf = {0};
        bins inf    = {1};
    }

    sign1_cp : coverpoint vif.sign_one {
        bins pos = {0};
        bins neg = {1};
    }

    sign2_cp : coverpoint vif.sign_two {
        bins pos = {0};
        bins neg = {1};
    }

    rounding_norm : coverpoint vif.rounding_norm {
      bins zero = {0};
      bins one = {1};
    }

    overflow : coverpoint vif.overflow {
      bins zero = {0};
      bins one = {1};
    }

    // Crosses must match coverpoint labels and end with semicolon
    grs_combs: 
      cross 
        internal_ground, internal_roundb, internal_sticky; // all GRS combinations
    exponent_cross : 
      cross 
        internal_signed_exponent_one, internal_signed_exponent_two; // exponent difference checks
    exp_underflow_cross : 
      cross 
        internal_denorm_one, internal_denorm_two ,underflow;
    inf_combinations : 
      cross is_inf1_cp, is_inf2_cp, overflow
      {
        ignore_bins is_inf_overflow =
          binsof(overflow.one) &&
          (binsof(is_inf1_cp.inf) || binsof(is_inf2_cp.inf));
      }
  endgroup

  function new(virtual adder_intf vif);
    this.vif = vif;
    cg = new; //create new instance of class
  endfunction


endclass
`endif