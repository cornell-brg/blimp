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

  localparam MAX_M = (1 << ($clog2(p_max_m)+1)) - 1;
  localparam MAX_REQ = $countones($unsigned((1 << p_width) - 1));
  localparam MAX_HD_PTR = $countones($unsigned((1 << p_width) - 2));

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

    m: coverpoint vintf.m {
      bins none   = { 0 };
      bins one    = { 1 };
      bins many   = { [2:p_max_m-1] };
      bins max    = { p_max_m };
      bins exceed = { [p_max_m+1:MAX_M]};
    }

    num_req: coverpoint $countones(vintf.req) {
      bins none = { 0 };
      bins one  = { 1 };
      bins many = { [2:MAX_REQ-1] };
      bins max  = { MAX_REQ };
    }

    num_gnt: coverpoint $countones(vintf.gnt) {
      bins none = { 0 };
      bins one  = { 1 };
      bins many = { [2:p_max_m-1] };
      bins max  = { p_max_m };
    }

    head_ptr: coverpoint $countones(~vintf.head_ptr) {
      bins lsb = { 0 };
      bins mid = { [1:MAX_HD_PTR-1] }; // TODO: doesn't work for p_width=1
      bins msb = { MAX_HD_PTR };
    }

    // Cover crosses

    // TODO

  endgroup

  // Function to create an instance of this class: MRRArbCoverage

  function new(virtual MRRArbIntf #(p_width, p_max_m) vintf);
    this.vintf = vintf;
    mrrarb_cg = new();
  endfunction

endclass

`endif /* VERILATOR */
