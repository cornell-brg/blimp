//========================================================================
// adder_intf.sv
//========================================================================
// Author: Rohan Kalluraya
//========================================================================
// Values to track from ALUF
// =======================================================================

interface adder_intf(input logic clk);
  logic reset;
  logic internal_ground;
  logic internal_sticky;
  logic internal_roundb;
  logic internal_denorm_one;
  logic internal_denorm_two;
  logic internal_nan_one;
  logic internal_nan_two;
  logic [22:0] mantissa_one;
  logic [22:0] mantissa_two;
  logic underflow;
  logic overflow;
  logic is_inf_one;
  logic is_inf_two;
  logic rounding_norm;
  logic [8:0] signed_exponent_one;
  logic [8:0] signed_exponent_two;
  logic sign_one;
  logic sign_two;

endinterface