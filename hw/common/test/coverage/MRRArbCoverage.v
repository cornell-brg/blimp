//========================================================================
// MRRArbCoverage
//========================================================================
// A coverage class for a particular parametrization of the arbiter

`ifndef VERILATOR

class MRRArbCoverage #(
  parameter p_width = 4,
  parameter p_max_m = 4
);

  // Declare a MRRArbIntf to interface with the MRRArb

  virtual MRRArbIntf #(p_width, p_max_m) vintf;

  // Covergroup

  covergroup mrrarb_cg @( posedge vintf.clk );

    // Coverpoints

    reset: coverpoint vintf.rst {
      bins zero = { 0 };
      bins one  = { 1 };
      bins reserve = default;
    }

    enable: coverpoint vintf.en {
      bins zero = { 0 };
      bins one  = { 1 };
      bins reserve = default;
    }

    m: coverpoint vintf.m;

    requests: coverpoint vintf.req;

    grants: coverpoint vintf.gnt;

    head_ptr: coverpoint vintf.head_ptr;

    // Cover crosses

  endgroup

  // Function to create an instance of this class: MRRArbCoverage

  function new(virtual MRRArbIntf #(p_width, p_max_m) vintf);
    this.vintf = vintf;
    mrrarb_cg = new();
  endfunction

endclass

`endif /* VERILATOR */
