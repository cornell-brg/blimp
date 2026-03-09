//========================================================================
// FifoBypass.v
//========================================================================
// A general-purpose FIFO with bypass support. When the queue is empty
// and both push and pop occur simultaneously, the pushed data bypasses
// the queue and appears directly on rdata without being stored.
//
// Currently, we assume that p_depth is a power of 2

`ifndef HW_COMMON_FIFO_BYPASS_V
`define HW_COMMON_FIFO_BYPASS_V

module FifoBypass
#(
  parameter p_entry_bits = 32,
  parameter p_depth      = 32,
  parameter p_bypass     = 1
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Control/Status Signals
  //----------------------------------------------------------------------

  input  logic clear,  // Synchronous clear: empties FIFO, allows same-cycle push
  input  logic push,
  input  logic pop,
  output logic empty,
  output logic full,
  output logic bypassing,

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

  // Raw pointer-based empty (no bypass consideration) used internally
  // to drive bypass logic without combinational loops.
  logic ptr_empty;
  assign ptr_empty = ( wptr == rptr );

  // Bypass mux: show wdata on rdata when empty and pushing, independent
  // of pop to avoid combinational loops (pop may depend on rdata).
  // Note: clear does not affect bypass_mux to avoid combinational loops.
  // verilator lint_off UNOPTFLAT
  logic bypass_mux;
  // verilator lint_on UNOPTFLAT
  assign bypass_mux = p_bypass[0] & ptr_empty & push & ~rst;

  // Bypass enqueue suppression: when empty, pushing, and popping
  // simultaneously, don't actually store — data flows straight through.
  logic bypass_ctrl;
  assign bypass_ctrl = bypass_mux & pop;

  logic do_push, do_pop;
  assign do_push = push & ~bypass_ctrl;
  assign do_pop  = pop  & ~bypass_ctrl;

  always @( posedge clk ) begin
    if( rst ) begin
      rptr <= '0;
      wptr <= '0;
    end else if( clear ) begin
      rptr <= '0;
      wptr <= '0;
    end else begin
      if( do_push ) wptr <= wptr + {(p_addr_bits + 1){1'b1}};
      if( do_pop  ) rptr <= rptr + {(p_addr_bits + 1){1'b1}};
    end
  end

  assign empty     = ptr_empty;
  assign bypassing = bypass_mux;

  generate
    if( p_depth == 1 ) begin : gen_full_depth_1
      assign full = ( wptr != rptr );
    end else begin : gen_full_depth_gt_1
      assign full  = ( wptr[p_addr_bits-1:0] == rptr[p_addr_bits-1:0] )
                   & ( wptr[p_addr_bits]     != rptr[p_addr_bits]     );
    end
  endgenerate

  //----------------------------------------------------------------------
  // Create our data array
  //----------------------------------------------------------------------

  logic [p_entry_bits-1:0] arr_rdata;

  generate
    if( p_depth == 1 ) begin : gen_depth_1
      logic [p_entry_bits-1:0] arr;

      always @( posedge clk ) begin
        if( rst ) begin
          arr <= '0;
        end else if( do_push ) begin
          arr <= wdata;
        end
      end
      assign arr_rdata = arr;

    end else begin : gen_depth_gt_1
      logic [p_entry_bits-1:0] arr [p_depth-1:0];

      always @( posedge clk ) begin
        if( rst ) begin
          arr <= '{default: '0};
        end else if( do_push & ~clear ) begin
          arr[wptr[p_addr_bits-1:0]] <= wdata;
        end
      end
      assign arr_rdata = arr[rptr[p_addr_bits-1:0]];
    end
  endgenerate

  // Mux between bypass path and array read
  assign rdata = bypass_mux ? wdata : arr_rdata;

endmodule

`endif // HW_COMMON_FIFO_BYPASS_V