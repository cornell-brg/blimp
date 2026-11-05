//========================================================================
// RegfileFPU.v
//========================================================================
// Author: Sumaia Jewena
//========================================================================

`ifndef HW_DECODE_REGFILEFPU_V
`define HW_DECODE_REGFILEFPU_V

module RegfileFPU #(
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

  logic [p_entry_bits-1:0] regs [p_num_regs-1:0];

  //----------------------------------------------------------------------
  // Read Interface
  //----------------------------------------------------------------------

  // Check forwarding

  logic forward_write [2]; 
  always_comb begin
    // Port 0 Check
    forward_write[0] = wen & ( raddr[0] == waddr );
    // Port 1 Check
    forward_write[1] = wen & ( raddr[1] == waddr );
  end

  always_comb begin
    if( forward_write[0] )
      rdata[0] = wdata;
    else
      rdata[0] = regs[raddr[0]];
    if( forward_write[1] )
      rdata[1] = wdata;
    else
      rdata[1] = regs[raddr[1]];
  end

  //----------------------------------------------------------------------
  // Write interface
  //----------------------------------------------------------------------

// Write logic-- It is the only part of the chip that has "memory" (state) 
// It updates the stored values inside the flip-flops on the 
// rising edge of the clock.

  integer i;
  always_ff @( posedge clk ) begin
    if ( rst ) begin
      for ( i = 0; i < p_num_regs; i = i + 1 )
        regs[i] <= '0;
    end
    else if ( wen ) 
      regs[waddr] <= wdata;
  end
endmodule

`endif // HW_DECODE_REGFILEFPU_V
