//========================================================================
// M2Regfile.v
//========================================================================
// A parametrized register file, with x0 hard-coded to 0. Supports superscalar
// backend through multiple write ports

`ifndef HW_DECODE_M2REGFILE_V
`define HW_DECODE_M2REGFILE_V

module M2Regfile #(
  parameter p_entry_bits       = 32,
  parameter p_num_regs         = 32,
  parameter p_num_lookup_ports = 2,
  parameter p_num_be_lanes     = 2
) (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Read Interface
  //----------------------------------------------------------------------

  input  logic [$clog2(p_num_regs)-1:0] raddr   [p_num_lookup_ports][2],
  output logic [      p_entry_bits-1:0] rdata   [p_num_lookup_ports][2],

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

  // we assume that the same waddr will not be written to concurrently on
  // multiple commit interfaces due to robust renaming
  logic [p_entry_bits-1:0] fwd_rdata    [p_num_lookup_ports][2];
  logic                    fwd_rdata_en [p_num_lookup_ports][2];
  always_comb begin
    for( int j = 0; j < p_num_lookup_ports; j++ ) begin: FWD_RDATA_OUTER
      for( int k = 0; k < 2; k++ ) begin: FWD_RDATA_INNER
        fwd_rdata[j][k]    = '0;
        fwd_rdata_en[j][k] = '0;
      end
    end
    for( int i = 0; i < p_num_be_lanes; i++ ) begin
      for( int j = 0; j < p_num_lookup_ports; j++ ) begin
        for( int k = 0; k < 2; k++ ) begin
          if( wen[i] & (raddr[j][k] == waddr[i]) ) begin
            fwd_rdata[j][k]    = wdata[i];
            fwd_rdata_en[j][k] = 1'b1;
          end
        end
      end
    end
  end

  always_comb begin
    for( int j = 0; j < p_num_lookup_ports; j++ ) begin: RDATA_OUTER
      for( int k = 0; k < 2; k++ ) begin: RDATA_INNER
        if( raddr[j][k] == '0 )
          rdata[j][k] = '0;
        else if( fwd_rdata_en[j][k] )
          rdata[j][k] = fwd_rdata[j][k];
        else
          rdata[j][k] = regs[raddr[j][k]];
      end
    end
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

`endif // HW_DECODE_M2REGFILE_V
