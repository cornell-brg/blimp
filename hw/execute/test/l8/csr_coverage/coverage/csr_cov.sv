`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"
`include "intf/CSRIntf.v"
`include "hw/execute/execute_units_l8/CSR.v"
`include "hw/execute/execute_units_l8/CSRFile.v"

import UArch::*;

module tb;
  // Basic clock/reset
  logic clk, rst;
  initial begin clk = 0; forever #1 clk = ~clk; end
  initial begin rst = 1; #5 rst = 0; end

  // Instantiate interfaces and DUT
  D__XIntf  D__X_intf();
  X__WIntf  X__W_intf();
  CSRIntf   CSR_intf();

  CSR dut (
    .clk (clk),
    .rst (rst),
    .D   (D__X_intf),
    .W   (X__W_intf),
    .CSR (CSR_intf)
  );

  CSRFile csr_file (
    .clk (clk),
    .rst (rst),
    .csr (CSR_intf)
  );

  // Transaction/coverage object
  csr_trns tr = new();

  // Simple stimulus: randomize D message, drive into interface, sample from DUT
  typedef struct packed {
    logic [31:0] pc;
    logic [31:0] op1;
    logic [31:0] op2;
    logic  [4:0] waddr;
    rv_uop       uop;
  } d_msg_t;

  d_msg_t msg;

  // Drive X/W ready always 1 for progress
  assign X__W_intf.rdy = 1'b1;

  initial begin
    // Wait out reset
    @(negedge rst);

    repeat (100) begin
      // Randomize a micro-op (constrain to CSR ops)
      logic [31:0] pc_r, op1_r, op2_r;
      logic  [4:0] waddr_r;
      rv_uop       uop_r;

      void'(std::randomize(uop_r) with { uop_r inside {OP_CSRRW, OP_CSRRS, OP_CSRRC}; });
      void'(std::randomize(pc_r));
      void'(std::randomize(op1_r));
      void'(std::randomize(op2_r));
      void'(std::randomize(waddr_r));

      msg.uop   = uop_r;
      msg.pc    = pc_r;
      msg.op1   = op1_r;
      msg.op2   = op2_r;
      msg.waddr = waddr_r;

      // Drive D interface for one beat
      D__X_intf.pc    <= msg.pc;
      D__X_intf.seq_num <= '0;
      D__X_intf.op1   <= msg.op1;
      D__X_intf.op2   <= msg.op2;
      D__X_intf.waddr <= msg.waddr;
      D__X_intf.uop   <= msg.uop;
      D__X_intf.preg  <= '0;
      D__X_intf.ppreg <= '0;
      D__X_intf.val   <= 1'b1;
      @(posedge clk);
      D__X_intf.val   <= 1'b0; // single-cycle send

      // Allow DUT to process and handshake to W
      @(posedge clk);

      // Sample from DUT interfaces into coverage transaction
      tr.csr_val         = CSR_intf.val;
      tr.csr_rdy         = CSR_intf.rdy;
      tr.csr_addr        = CSR_intf.addr;
      tr.csr_wdata       = CSR_intf.wdata;
      tr.csr_cmd         = CSR_intf.cmd;
      tr.csr_rdata       = CSR_intf.rdata;

      tr.w_val           = X__W_intf.val;
      tr.w_rdy           = X__W_intf.rdy;
      tr.waddr           = X__W_intf.waddr;
      tr.wen             = X__W_intf.wen;

      // Mirror op1 from D input to check CSR.wdata connectivity
      tr.op1_mirror      = msg.op1;

      tr.sample_cov();
      tr.display();
    end

    $finish;
  end

endmodule
