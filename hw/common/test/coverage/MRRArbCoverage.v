//========================================================================
// MRRArbCoverage
//========================================================================
// A coverage class for a particular parametrization of the arbiter

`ifndef HW_COMMON_TEST_COVERAGE_MRRARB_COVERAGE_V
`define HW_COMMON_TEST_COVERAGE_MRRARB_COVERAGE_V

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

  // Localparams & logic conversion --------------------------------------

  localparam MAX_M = (1 << ($clog2(p_max_m)+1)) - 1;
  localparam MAX_REQ = $countones($unsigned((1 << p_width) - 1));
  localparam MAX_GNT = (p_max_m < p_width) ? p_max_m : p_width;
  localparam MAX_HD_PTR = $countones($unsigned((1 << p_width) - 2));

  logic [31:0] req_count;
  logic [31:0] gnt_count;
  logic [31:0] head_ptr_value;

  assign req_count = $countones(req);
  assign gnt_count = $countones(gnt);
  assign head_ptr_value = $countones(~head_ptr);

  // Coverpoints ---------------------------------------------------------

  // Reset
  RST_0: cover property ( @(posedge clk) rst == 0 );
  RST_1: cover property ( @(posedge clk) rst == 1 );
  
  // Enable
  EN_0: cover property ( @(posedge clk) en == 0 );
  EN_1: cover property ( @(posedge clk) en == 1 );
  
  // M-select
  M_0:   cover property ( @(posedge clk) m == 0 );
  M_1:   cover property ( @(posedge clk) m == 1 );
  M_MID: cover property ( @(posedge clk) (m >= 2) && (m <= p_max_m-1) );
  M_MAX: cover property ( @(posedge clk) m == p_max_m );
  /* verilator lint_off CMPCONST */
  M_EXCEED_MAX: cover property ( @(posedge clk) (m >= p_max_m+1) && (m <= MAX_M) );
  /* verilator lint_on CMPCONST */

  // Request
  REQ_0: cover property ( @(posedge clk) req_count == 0 );
  REQ_1: cover property ( @(posedge clk) req_count == 1 );
  generate
    if ( p_width != 1 ) begin : g_cov_req__p_width_not1
      REQ_MID: cover property ( @(posedge clk) (req_count >= 2) && (req_count <= MAX_REQ-1) );
      REQ_MAX: cover property ( @(posedge clk) req_count == MAX_REQ );
    end
  endgenerate

  // Grant
  GNT_0: cover property ( @(posedge clk) gnt_count == 0 );
  GNT_1: cover property ( @(posedge clk) gnt_count == 1 );
  generate
    if ( p_width != 1 ) begin : g_cov_gnt__p_width_not1
      GNT_MID: cover property ( @(posedge clk) (gnt_count >= 2) && (gnt_count <= MAX_GNT-1) );
      GNT_MAX: cover property ( @(posedge clk) gnt_count == MAX_GNT );
    end
  endgenerate
  
  // Head pointer
  HEAD_PTR_0: cover property ( @(posedge clk) head_ptr_value == 0 );
  generate
    if ( p_width != 1 ) begin : g_cov_head_ptr__p_width_not1
      HEAD_PTR_MID: cover property ( @(posedge clk) (head_ptr_value >= 1) && (head_ptr_value <= MAX_HD_PTR-1) );
    end
  endgenerate
  HEAD_PTR_MAX: cover property ( @(posedge clk) head_ptr_value == MAX_HD_PTR );

endmodule

`endif /* HW_COMMON_TEST_COVERAGE_MRRARB_COVERAGE_V */
