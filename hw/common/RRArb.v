//========================================================================
// RRArb.v
//========================================================================
// A round-robin arbiter implemented with thermo-coded vectors, initially
// preferring the least-significant input
//
// https://www.sciencedirect.com/science/article/pii/S0026269212000948
// (with minor modifications for LSB priority)

`ifndef HW_COMMON_RRARB_V
`define HW_COMMON_RRARB_V

module RRArb #(
  parameter p_width = 2
)(
  input  logic               clk,
  input  logic               rst,
  input  logic               en,

  input  logic [p_width-1:0] req,
  output logic [p_width-1:0] gnt
);

  generate

    //--------------------------------------------------------------------
    // Trivial case
    //--------------------------------------------------------------------

    if( p_width == 1 ) begin
      logic unused_clk, unused_rst, unused_en;
      assign gnt = req;
      assign unused_clk = clk;
      assign unused_rst = rst;
      assign unused_en  = en;
    end else begin

      //------------------------------------------------------------------
      // Use the previous grant to store a high-priority filter
      //------------------------------------------------------------------

      logic [p_width-1:0] thermo_gnt;
      logic [p_width-1:0] req_hph_filter;
      
      always_ff @( posedge clk ) begin
        if( rst )     req_hph_filter <= '0;
        else if( en ) req_hph_filter <= thermo_gnt << 1;
      end

      //------------------------------------------------------------------
      // Thermo-code the high-priority and low-priority portions
      //------------------------------------------------------------------
      
      logic [p_width-1:0] req_hph;
      logic [p_width-1:0] req_lph;
    
      assign req_hph = req_hph_filter & req;
      assign req_lph = req;
    
      logic [p_width-1:0] thermo_req_hph /* verilator split_var */;
      logic [p_width-1:0] thermo_req_lph /* verilator split_var */;
    
      genvar i;
      for( i = 0; i < p_width; i = i + 1 ) begin: detector
        assign thermo_req_hph[i] = |req_hph[i:0];
        assign thermo_req_lph[i] = |req_lph[i:0];
      end
    
      //------------------------------------------------------------------
      // Mux the two to get the thermo-encoded gnt
      //------------------------------------------------------------------
    
      always_comb begin
        if( thermo_req_hph[p_width-1] ) // Any bits are high
          thermo_gnt = thermo_req_hph;
        else
          thermo_gnt = thermo_req_lph;
      end
    
      //------------------------------------------------------------------
      // Edge-detect to get actual grant
      //------------------------------------------------------------------
    
      assign gnt = thermo_gnt & {~thermo_gnt[p_width-2:0], 1'b1};
    end
  endgenerate
endmodule

`endif // HW_COMMON_RRARB_V
