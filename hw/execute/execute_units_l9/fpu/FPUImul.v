//=========================================================================
// V1 Alternative V1 Unsigned Integer Multiplier Implementation
//=========================================================================
// Booth-recoder unsigned integer multiplier

`ifndef FPU_IMUL_V
`define FPU_IMUL_V

//=========================================================================
// V1 Alternative V1 Unsigned Integer Multiplier Implementation
//=========================================================================

module FPUImul #(
  parameter integer p_opt_level = 0,
  parameter integer p_bitwidth  = 24,
  parameter integer p_groups    = (p_bitwidth + 1) / 2
) (
  input  logic [p_bitwidth-1:0]   a,
  input  logic [p_bitwidth-1:0]   b,
  output logic [2*p_bitwidth-1:0] out
);
  
  generate
    if (p_opt_level >= 4) begin
      logic [2*p_bitwidth-1:0] partial;
      logic [1:0]              digit;
      
      always_comb begin
        out = '0;

        // Skip logic if either operand is zero
        if (a == '0 || b == '0) begin
          out     = '0;
          digit   = '0;
          partial = '0;
        end else begin
          for (int i = 0; i < p_groups; i++) begin

            // Take two digits from b to get digit, create partial from this
            if (((i << 1) + 1) < p_bitwidth) digit = b[(i << 1) + 1 -: 2];
            else                             digit = {1'b0, b[i << 1]};
            case (digit)
              2'b00:   partial = '0;
              2'b01:   partial = a;
              2'b10:   partial = a << 1;
              2'b11:   partial = (a << 1) + a;
              default: partial = '0;
            endcase

            // Shift partial and add to result
            out = out + (partial << (i << 1));
          end
        end
      end
    end else begin
      assign out = a * b;
    end
  endgenerate

endmodule

`endif // FPU_FPU_ALT_V1_IMUL_V