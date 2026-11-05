
// author: Anika Sukthankar

class FPUMult_Coverage;

  // ----------------------------
  // Sampled input fields
  // ----------------------------

  logic        in0_sign;
  logic        in1_sign;
  logic [7:0]  in0_exp;
  logic [7:0]  in1_exp;
  logic [22:0] in0_frac;
  logic [22:0] in1_frac;

  // ----------------------------
  // Sampled output/internal fields
  // ----------------------------

  logic        out_sign;
  logic [7:0]  out_exp;
  logic [22:0] out_frac;

  logic        overflow;
  logic        underflow;
  logic        exp_add;

  // operand classes
  logic in0_zero_or_denorm;
  logic in1_zero_or_denorm;

  // ----------------------------
  // Input coverage
  // ----------------------------

  covergroup cg_inputs;
    option.per_instance = 1;

    cp_in0_sign : coverpoint in0_sign {
      bins pos = {0};
      bins neg = {1};
    }

    cp_in1_sign : coverpoint in1_sign {
      bins pos = {0};
      bins neg = {1};
    }

    cp_sign_combo : cross cp_in0_sign, cp_in1_sign;

    cp_in0_type : coverpoint in0_zero_or_denorm {
      bins normal = {0};
      bins zero_or_denorm = {1};
    }

    cp_in1_type : coverpoint in1_zero_or_denorm {
      bins normal = {0};
      bins zero_or_denorm = {1};
    }

    cp_in0_exp : coverpoint in0_exp {
      bins zero     = {8'h00};
      bins small    = {[8'h01:8'h7E]};
      bins bias     = {8'h7F};
      bins large    = {[8'h80:8'hFE]};
      bins all_ones = {8'hFF};
    }

    cp_in1_exp : coverpoint in1_exp {
      bins zero     = {8'h00};
      bins small    = {[8'h01:8'h7E]};
      bins bias     = {8'h7F};
      bins large    = {[8'h80:8'hFE]};
      bins all_ones = {8'hFF};
    }

    cp_in0_frac_zero : coverpoint (in0_frac == 23'd0) {
      bins frac_zero = {1};
      bins frac_nz   = {0};
    }

    cp_in1_frac_zero : coverpoint (in1_frac == 23'd0) {
      bins frac_zero = {1};
      bins frac_nz   = {0};
    }
  endgroup

  // ----------------------------
  // Result coverage
  // ----------------------------

  covergroup cg_results;
    option.per_instance = 1;

    cp_out_sign : coverpoint out_sign {
      bins pos = {0};
      bins neg = {1};
    }

    cp_out_exp : coverpoint out_exp {
      bins zero     = {8'h00};
      bins small    = {[8'h01:8'h7E]};
      bins bias     = {8'h7F};
      bins large    = {[8'h80:8'hFE]};
      bins all_ones = {8'hFF};
    }

    cp_out_frac_zero : coverpoint (out_frac == 23'd0) {
      bins frac_zero = {1};
      bins frac_nz   = {0};
    }

    cp_overflow : coverpoint overflow {
      bins no = {0};
      bins yes = {1};
    }

    cp_underflow : coverpoint underflow {
      bins no = {0};
      bins yes = {1};
    }

    cp_exp_add : coverpoint exp_add {
      bins no = {0};
      bins yes = {1};
    }

    cp_flags : cross cp_overflow, cp_underflow, cp_exp_add;
  endgroup

  function new();
    cg_inputs  = new();
    cg_results = new();
  endfunction

  function void sample_inputs(
    logic        s0,
    logic        s1,
    logic [7:0]  e0,
    logic [7:0]  e1,
    logic [22:0] f0,
    logic [22:0] f1
  );
    in0_sign = s0;
    in1_sign = s1;
    in0_exp  = e0;
    in1_exp  = e1;
    in0_frac = f0;
    in1_frac = f1;

    in0_zero_or_denorm = (e0 == 8'h00);
    in1_zero_or_denorm = (e1 == 8'h00);

    cg_inputs.sample();
  endfunction

  function void sample_results(
    logic        s_out,
    logic [7:0]  e_out,
    logic [22:0] f_out,
    logic        of,
    logic        uf,
    logic        add
  );
    out_sign = s_out;
    out_exp  = e_out;
    out_frac = f_out;
    overflow = of;
    underflow = uf;
    exp_add = add;

    cg_results.sample();
  endfunction

endclass