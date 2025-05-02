//========================================================================
// Fifo.v
//========================================================================
// A general-purpose FIFO using a pointer-based approach
//
// Currently, we assume that p_depth is a power of 2

`ifndef HW_COMMON_FIFO_V
`define HW_COMMON_FIFO_V

module Fifo
#(
  parameter p_entry_bits = 32,
  parameter p_depth      = 32
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Control/Status Signals
  //----------------------------------------------------------------------

  input  logic push,
  input  logic pop,
  output logic empty,
  output logic full,

  //----------------------------------------------------------------------
  // Data Signals
  //----------------------------------------------------------------------

  input  logic [p_entry_bits-1:0] wdata,
  output logic [p_entry_bits-1:0] rdata
);

  //----------------------------------------------------------------------
  // Create our pointers
  //----------------------------------------------------------------------

  localparam p_addr_bits = $clog2(p_depth);

  logic [p_addr_bits:0] rptr, wptr;

  always @( posedge clk ) begin
    if( rst ) begin
      rptr <= '0;
      wptr <= '0;
    end else begin
      if( push ) wptr <= wptr + {(p_addr_bits + 1){1'b1}};
      if( pop  ) rptr <= rptr + {(p_addr_bits + 1){1'b1}};
    end
  end

  assign empty = ( wptr == rptr );
  generate
    if( p_depth == 1 )
      assign full = ( wptr != rptr );
    else
      assign full  = ( wptr[p_addr_bits-1:0] == rptr[p_addr_bits-1:0] )
                   & ( wptr[p_addr_bits]     != rptr[p_addr_bits]     );
  endgenerate

  //----------------------------------------------------------------------
  // Create our data array
  //----------------------------------------------------------------------

  generate
    if( p_depth == 1 ) begin
      logic [p_entry_bits-1:0] arr;

      always @( posedge clk ) begin
        if( rst ) begin
          arr <= '0;
        end else if( push ) begin
          arr <= wdata;
        end
      end
      assign rdata = arr;

    end else begin
      logic [p_entry_bits-1:0] arr [p_depth-1:0];

      always @( posedge clk ) begin
        if( rst ) begin
          arr <= '{default: '0};
        end else if( push ) begin
          arr[wptr[p_addr_bits-1:0]] <= wdata;
        end
      end
      assign rdata = arr[rptr[p_addr_bits-1:0]];
    end
  endgenerate

endmodule

`endif // HW_COMMON_FIFO_V
