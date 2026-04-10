//========================================================================
// X__WDelay.v
//========================================================================
// Simulation-only backpressure injector for the X__W interface.
// Periodically suppresses rdy for 1 cycle every p_bp_interval cycles.
// All other signals pass through transparently.
// p_bp_interval = 0: no backpressure (pure passthrough).

`ifndef HW_UTIL_X__W_DELAY_V
`define HW_UTIL_X__W_DELAY_V

module X__WDelay #(
  parameter p_seq_num_bits   = 5,
  parameter p_phys_addr_bits = 6,
  parameter p_bp_interval    = 0
)(
  input logic clk,
  input logic rst,

  X__WIntf.W_intf up,
  X__WIntf.X_intf dn
);

  generate
  if ( p_bp_interval == 0 ) begin: PASSTHRU

    assign dn.val     = up.val;
    assign dn.pc      = up.pc;
    assign dn.waddr   = up.waddr;
    assign dn.wdata   = up.wdata;
    assign dn.wen     = up.wen;
    assign dn.seq_num = up.seq_num;
    assign dn.preg    = up.preg;
    assign dn.ppreg   = up.ppreg;
    assign up.rdy     = dn.rdy;

  end else begin: BACKPRESSURE

    // Counter for backpressure injection
    // verilator lint_off WIDTHEXPAND
    logic [$clog2(p_bp_interval)-1:0] cnt;

    always @( posedge clk ) begin
      if ( rst )
        cnt <= '0;
      else if ( cnt == p_bp_interval - 1 )
        cnt <= '0;
      else
        cnt <= cnt + 1;
    end

    logic bp_active;
    assign bp_active = (cnt == '0);
    // verilator lint_on WIDTHEXPAND

    // Forward signals pass through; val gated during stall
    assign dn.val     = up.val & ~bp_active;
    assign dn.pc      = up.pc;
    assign dn.waddr   = up.waddr;
    assign dn.wdata   = up.wdata;
    assign dn.wen     = up.wen;
    assign dn.seq_num = up.seq_num;
    assign dn.preg    = up.preg;
    assign dn.ppreg   = up.ppreg;

    // Gate rdy during stall to keep sender/receiver consistent
    assign up.rdy = dn.rdy & ~bp_active;

  end
  endgenerate

endmodule

`endif // HW_UTIL_X__W_DELAY_V
