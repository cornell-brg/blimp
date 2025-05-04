//========================================================================
// Regfile.v
//========================================================================
// A parametrized register file, with x0 hard-coded to 0

`ifndef HW_DECODE_REGFILE_V
`define HW_DECODE_REGFILE_V

module Regfile #(
  parameter p_entry_bits = 32,
  parameter p_num_regs   = 32
) (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Read Interface
  //----------------------------------------------------------------------

  input  logic [$clog2(p_num_regs)-1:0] raddr   [2],
  output logic [      p_entry_bits-1:0] rdata   [2],

  //----------------------------------------------------------------------
  // Write Interface
  //----------------------------------------------------------------------

  input  logic [$clog2(p_num_regs)-1:0] waddr,
  input  logic [      p_entry_bits-1:0] wdata,
  input  logic                          wen
);

  //----------------------------------------------------------------------
  // Storage Elements
  //----------------------------------------------------------------------

  logic [p_entry_bits-1:0] regs [p_num_regs-1:1];

  //----------------------------------------------------------------------
  // Read Interface
  //----------------------------------------------------------------------

  logic forward_write [2];
  always_comb begin
    forward_write[0] = wen & ( raddr[0] == waddr );
    forward_write[1] = wen & ( raddr[1] == waddr );
  end

  always_comb begin
    if( raddr[0] == '0 )
      rdata[0] = '0;
    else if( forward_write[0] )
      rdata[0] = wdata;
    else
      rdata[0] = regs[raddr[0]];
    
    if( raddr[1] == '0 )
      rdata[1] = '0;
    else if( forward_write[1] )
      rdata[1] = wdata;
    else
      rdata[1] = regs[raddr[1]];
  end

  //----------------------------------------------------------------------
  // Write interface
  //----------------------------------------------------------------------

  always_ff @( posedge clk ) begin
    if ( rst )
      regs <= '{default: '0};
    else if ( wen & ( waddr != '0 ))
      regs[waddr] <= wdata;
  end
endmodule

`endif // HW_DECODE_REGFILE_V
