//========================================================================
// MRegfile.v
//========================================================================
// A parametrized register file, with x0 hard-coded to 0. Supports superscalar
// backend through multiple write ports

`ifndef HW_DECODE_MREGFILE_V
`define HW_DECODE_MREGFILE_V

module MRegfile #(
  parameter p_entry_bits   = 32,
  parameter p_num_regs     = 32,
  parameter p_num_be_lanes = 2
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

  input  logic [$clog2(p_num_regs)-1:0] waddr   [p_num_be_lanes],
  input  logic [      p_entry_bits-1:0] wdata   [p_num_be_lanes],
  input  logic                          wen     [p_num_be_lanes]
);

  //----------------------------------------------------------------------
  // Storage Elements
  //----------------------------------------------------------------------

  logic [p_entry_bits-1:0] regs [p_num_regs-1:1];

  //----------------------------------------------------------------------
  // Read Interface
  //----------------------------------------------------------------------

  // we assume that the same waddr will not be written to concurrently on multiple
  // commit interfaces due to robust renaming
  logic [p_entry_bits-1:0] fwd_rdata    [2];
  logic                    fwd_rdata_en [2];
  always_comb begin
    fwd_rdata[0]    = '0;
    fwd_rdata[1]    = '0;
    fwd_rdata_en[0] = '0;
    fwd_rdata_en[1] = '0;
    for( int i = 0; i < p_num_be_lanes; i++ ) begin
      if( wen[i] & (raddr[0] == waddr[i]) ) begin
        fwd_rdata[0]    = wdata[i];
        fwd_rdata_en[0] = 1'b1;
      end
      if( wen[i] & (raddr[1] == waddr[i]) ) begin
        fwd_rdata[1]    = wdata[i];
        fwd_rdata_en[1] = 1'b1;
      end
    end
  end

  always_comb begin
    if( raddr[0] == '0 )
      rdata[0] = '0;
    else if( fwd_rdata_en[0] )
      rdata[0] = fwd_rdata[0];
    else
      rdata[0] = regs[raddr[0]];
    
    if( raddr[1] == '0 )
      rdata[1] = '0;
    else if( fwd_rdata_en[1] )
      rdata[1] = fwd_rdata[1];
    else
      rdata[1] = regs[raddr[1]];
  end

  //----------------------------------------------------------------------
  // Write interface
  //----------------------------------------------------------------------

  always_ff @( posedge clk ) begin
    if ( rst )
      regs <= '{default: '0};
    else begin
      for( int i = 0; i < p_num_be_lanes; i++ )
        if( wen[i] & ( waddr[i] != '0 ) ) regs[waddr[i]] <= wdata[i];
    end
  end
endmodule

`endif // HW_DECODE_MREGFILE_V
