//========================================================================
// fdiv_cov.sv
//========================================================================
// Functional coverage for floating point division
//========================================================================

`ifndef FDIV_COV_SV
`define FDIV_COV_SV

`ifndef VERILATOR

class fp_division_cov;

  virtual fdiv_intf divCov;

  covergroup cg @(posedge divCov.clk);

    // ------------------------------------------------------------------
    // Rounding bits
    // ------------------------------------------------------------------
    internal_ground : coverpoint divCov.internal_ground {
      bins zero = { 0 };
      bins one  = { 1 };
    }

    internal_roundb : coverpoint divCov.internal_roundb {
      bins zero = { 0 };
      bins one  = { 1 };
    }

    internal_sticky : coverpoint divCov.internal_sticky {
      bins zero = { 0 };
      bins one  = { 1 };
    }

    internal_last_bit_mantissa : coverpoint divCov.internal_last_bit_mantissa {
      bins zero = { 0 };
      bins one  = { 1 };
    }

    // ------------------------------------------------------------------
    // Special inputs / results: denormal, NaN, Inf, zero, under/overflow
    // ------------------------------------------------------------------
    internal_denorm_one : coverpoint divCov.internal_denorm_one {
      bins not_denorm = { 0 };
      bins is_denorm  = { 1 };
    }

    internal_denorm_two : coverpoint divCov.internal_denorm_two {
      bins not_denorm = { 0 };
      bins is_denorm  = { 1 };
    }

    internal_nan_one : coverpoint divCov.internal_nan_one {
      bins not_nan = { 0 };
      bins is_nan  = { 1 };
    }

    internal_nan_two : coverpoint divCov.internal_nan_two {
      bins not_nan = { 0 };
      bins is_nan  = { 1 };
    }

    is_inf1_cp : coverpoint divCov.is_inf_one {
      bins no_inf = { 0 };
      bins inf    = { 1 };
    }

    is_inf2_cp : coverpoint divCov.is_inf_two {
      bins no_inf = { 0 };
      bins inf    = { 1 };
    }

    zero1_cp : coverpoint divCov.zero_one {
      bins not_zero = { 0 };
      bins is_zero  = { 1 };
    }

    zero2_cp : coverpoint divCov.zero_two {
      bins not_zero = { 0 };
      bins is_zero  = { 1 };
    }

    underflow : coverpoint divCov.underflow {
      bins no_underflow = { 0 };
      bins underflow    = { 1 };
    }

    overflow : coverpoint divCov.overflow {
      bins no_overflow = { 0 };
      bins overflow    = { 1 };
    }

    // ------------------------------------------------------------------
    // Biased exponent ranges (bias = 127)
    // ------------------------------------------------------------------
    biased_exponent_one : coverpoint divCov.biased_exponent_one {
      bins zero      = { 8'h00 };                  // zero / denormal
      bins neg_large = { [8'h01:8'h3F] };          // 2^-126 .. 2^-64
      bins neg_small = { [8'h40:8'h7F] };          // 2^-63  .. 2^0
      bins pos_small = { [8'h80:8'h8F] };          // 2^1    .. 2^16
      bins pos_large = { [8'h90:8'hFE] };          // 2^17   .. 2^127
      bins all_ones  = { 8'hFF };                  // inf / NaN
    }

    biased_exponent_two : coverpoint divCov.biased_exponent_two {
      bins zero      = { 8'h00 };
      bins neg_large = { [8'h01:8'h3F] };
      bins neg_small = { [8'h40:8'h7F] };
      bins pos_small = { [8'h80:8'h8F] };
      bins pos_large = { [8'h90:8'hFE] };
      bins all_ones  = { 8'hFF };
    }

    // ------------------------------------------------------------------
    // Mantissa ranges
    // ------------------------------------------------------------------
    internal_mantissa_one : coverpoint divCov.mantissa_one {
      bins zero       = { 23'h000000 };
      bins mag_low    = { [23'h000001:23'h2AAAAA] };
      bins mag_medium = { [23'h2AAAAB:23'h555554] };
      bins mag_high   = { [23'h555555:23'h7FFFFE] };
      bins all_ones   = { 23'h7FFFFF };
    }

    internal_mantissa_two : coverpoint divCov.mantissa_two {
      bins zero       = { 23'h000000 };
      bins mag_low    = { [23'h000001:23'h2AAAAA] };
      bins mag_medium = { [23'h2AAAAB:23'h555554] };
      bins mag_high   = { [23'h555555:23'h7FFFFE] };
      bins all_ones   = { 23'h7FFFFF };
    }

    // ------------------------------------------------------------------
    // Signs
    // ------------------------------------------------------------------
    sign1_cp : coverpoint divCov.sign_one {
      bins pos = { 0 };
      bins neg = { 1 };
    }

    sign2_cp : coverpoint divCov.sign_two {
      bins pos = { 0 };
      bins neg = { 1 };
    }

    // ------------------------------------------------------------------
    // Crosses (names must match coverpoint labels above)
    // ------------------------------------------------------------------
    mantissa_rounding : cross internal_last_bit_mantissa, internal_ground;
    grs_combs         : cross internal_ground, internal_roundb, internal_sticky;
    exponent_cross    : cross biased_exponent_one, biased_exponent_two;
    exp_flow_cross    : cross biased_exponent_one, biased_exponent_two, underflow;
    exp_ovf_cross     : cross biased_exponent_one, biased_exponent_two, overflow;
    inf_sign_cross    : cross is_inf1_cp, is_inf2_cp, sign1_cp, sign2_cp;
    zero_sign_cross   : cross zero1_cp, zero2_cp, sign1_cp, sign2_cp;

  endgroup

  function new(virtual fdiv_intf divCov);
    this.divCov = divCov;
    cg = new;
  endfunction

endclass

`endif // VERILATOR

`endif // FDIV_COV_SV
