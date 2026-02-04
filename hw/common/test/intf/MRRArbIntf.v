//========================================================================
// MRRArbIntf
//========================================================================
// An interface between the DUT and coverage class of our testbench

`ifndef HW_COMMON_TEST_INTF_MRRARBINTF_V
`define HW_COMMON_TEST_INTF_MRRARBINTF_V

interface MRRArbIntf #(
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

`endif /* HW_COMMON_TEST_MRRARBINTF_V */
