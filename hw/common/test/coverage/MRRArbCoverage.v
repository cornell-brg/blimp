//========================================================================
// MRRArbCoverage
//========================================================================
// A coverage class for a particular parametrization of the arbiter

//------------------------------------------------------------------------
// VCS Coverage
//------------------------------------------------------------------------
`ifndef VERILATOR

// Interface between the DUT and coverage class --------------------------

interface MRRArbTestIntf #(
  parameter p_width = 4,
  parameter p_max_m = 4
) (
  input logic clk
);

  // Module port signals

  logic                     rst;
  logic                     en;
  logic [$clog2(p_max_m):0] m;
  logic [p_width-1:0]       req;
  logic [p_width-1:0]       gnt;
  
  // Internal signals

  logic [p_width-1:0]       head_ptr;

endinterface

// Coverage class --------------------------------------------------------

class MRRArbCoverage #(
  parameter p_width = 4,
  parameter p_max_m = 4
);

  // Declare a MRRArbTestIntf to interface with the MRRArb

  virtual MRRArbTestIntf #(p_width, p_max_m) vintf;

  localparam MAX_M = (1 << ($clog2(p_max_m)+1)) - 1;
  localparam MAX_REQ = $countones($unsigned((1 << p_width) - 1));
  localparam MAX_HD_PTR = $countones($unsigned((1 << p_width) - 2));

  // Covergroup (for p_width == 1) ---------------------------------------

  covergroup mrrarb_cg_1_bit @( posedge vintf.clk );

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
      bins msb = { MAX_HD_PTR };
    }

  endgroup

  // Covergroup (for p_width > 1) ----------------------------------------

  covergroup mrrarb_cg_multi_bit @( posedge vintf.clk );

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
      bins mid = { [1:MAX_HD_PTR-1] 
      bins msb = { MAX_HD_PTR };
    }

  endgroup

  // Function to create an instance of this class

  function new( virtual MRRArbTestIntf #(p_width, p_max_m) vintf );
    this.vintf = vintf;
    if (p_width > 1)
      mrrarb_cg_multi_bit = new();
    else
      mrrarb_cg_1_bit = new();
  endfunction

endclass

//------------------------------------------------------------------------
// Verilator Coverage
//------------------------------------------------------------------------
`else

module MRRArbCoverage #(
  parameter p_width = 4,
  parameter p_max_m = 4
)(
  input logic                     clk,
  input logic                     rst,
  input logic                     en,
  input logic [$clog2(p_max_m):0] m,
  input logic [p_width-1:0]       req,
  input logic [p_width-1:0]       gnt,
  
  // Internal signals

  input logic [p_width-1:0]       head_ptr
);

  // Localparams

  localparam MAX_M = (1 << ($clog2(p_max_m)+1)) - 1;
  localparam MAX_REQ = $countones($unsigned((1 << p_width) - 1));
  localparam MAX_GNT = (p_max_m < p_width) ? p_max_m : p_width;
  localparam MAX_HD_PTR = $countones($unsigned((1 << p_width) - 2));

  // Coverpoints ---------------------------------------------------------

  // Reset
  cover property ( @(posedge clk) rst == 0 );
  cover property ( @(posedge clk) rst == 1 );
  
  // Enable
  cover property ( @(posedge clk) en == 0 );
  cover property ( @(posedge clk) en == 1 );
  
  // M-select
  cover property ( @(posedge clk) m == 0 );
  cover property ( @(posedge clk) m == 1 );
  cover property ( @(posedge clk) (m >= 2) && (m <= p_max_m-1) );
  cover property ( @(posedge clk) m == p_max_m );
  /* verilator lint_off CMPCONST */
  cover property ( @(posedge clk) (m >= p_max_m+1) && (m <= MAX_M) );
  /* verilator lint_on CMPCONST */

  // Request
  cover property ( @(posedge clk) $countones(req) == 0 );
  cover property ( @(posedge clk) $countones(req) == 1 );
  generate
    if ( p_width != 1 ) begin : g_req_mid
      cover property ( @(posedge clk) ($countones(req) >= 2) && ($countones(req) <= MAX_REQ-1) );
    end
  endgenerate
  cover property ( @(posedge clk) $countones(req) == MAX_REQ );

  // Grant
  cover property ( @(posedge clk) $countones(gnt) == 0 );
  cover property ( @(posedge clk) $countones(gnt) == 1 );
  generate
    if ( p_width != 1 ) begin : g_gnt_mid
      cover property ( @(posedge clk) ($countones(gnt) >= 2) && ($countones(gnt) <= MAX_GNT-1) );
    end
  endgenerate
  cover property ( @(posedge clk) $countones(gnt) == MAX_GNT );
  
  // Head pointer
  cover property ( @(posedge clk) $countones(~head_ptr) == 0 );
  generate
    if ( p_width != 1 ) begin : g_head_ptr_mid
      cover property ( @(posedge clk) ($countones(~head_ptr) >= 1) && ($countones(~head_ptr) <= MAX_HD_PTR-1) );
    end
  endgenerate
  cover property ( @(posedge clk) $countones(~head_ptr) == MAX_HD_PTR );

endmodule

`endif /* VERILATOR */
