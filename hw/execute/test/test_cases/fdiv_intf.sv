//========================================================================
// fdiv_intf.sv
//========================================================================
// Values to track from FDiv
//========================================================================

interface fdiv_intf(input logic clk);
  logic        reset;
  logic        internal_ground;
  logic        internal_roundb;
  logic        internal_sticky;
  logic        internal_last_bit_mantissa;
  logic        internal_denorm_one;
  logic        internal_denorm_two;
  logic        internal_nan_one;
  logic        internal_nan_two;
  logic        is_inf_one;
  logic        is_inf_two;
  logic        zero_one;
  logic        zero_two;
  logic        underflow;
  logic        overflow;
  logic        sign_one;
  logic        sign_two;
  logic [7:0]  biased_exponent_one;
  logic [7:0]  biased_exponent_two;
  logic [22:0] mantissa_one;
  logic [22:0] mantissa_two;
endinterface

