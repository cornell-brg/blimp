//========================================================================
// CSR.v
//========================================================================
// Execute unit for CSR instructions (CSRRW, CSRRS, CSRRC, etc.)
// Uses CSRIntf for communication with CSRFile
//
// Author: Emily Lan
// Last updated: 11/04/25
//========================================================================

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L1_CSR_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L1_CSR_V

`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"
`include "intf/CSRIntf.v"

import UArch::*;

module CSR (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // D <-> X Interface
  //----------------------------------------------------------------------

  D__XIntf.X_intf D,

  //----------------------------------------------------------------------
  // X <-> W Interface
  //----------------------------------------------------------------------

  X__WIntf.X_intf W,

  //----------------------------------------------------------------------
  // CSR Interface
  //----------------------------------------------------------------------

  CSRIntf.X_intf CSR
);

  localparam p_seq_num_bits   = D.p_seq_num_bits;
  localparam p_phys_addr_bits = D.p_phys_addr_bits;

//----------------------------------------------------------------------
// Register inputs
//----------------------------------------------------------------------

typedef struct packed {
    logic                        val;
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                 [31:0] op1;    // Source register value (rs1)
    logic                 [31:0] op2;    // CSR immediate (imm[11:0])
    logic                  [4:0] waddr;  // Destination register address
    rv_uop                       uop;    
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
} D_input;

  D_input D_reg, D_reg_next;
  logic   D_xfer, W_xfer;

  // verilator lint_off ENUMVALUE

  always_ff @(posedge clk) begin
    if (rst)
      D_reg <= '0;
    else
      D_reg <= D_reg_next;
  end

  always_comb begin
    D_xfer = D.val & D.rdy;
    W_xfer = W.val & W.rdy;

    if (D_xfer)
      D_reg_next = '{
        val:     1'b1,
        pc:      D.pc,
        seq_num: D.seq_num,
        op1:     D.op1,
        op2:     D.op2,
        waddr:   D.waddr,
        uop:     D.uop,
        preg:    D.preg,
        ppreg:   D.ppreg
      };
    else if (W_xfer)
      D_reg_next = '0;
    else
      D_reg_next = D_reg;
  end
  
  // verilator lint_on ENUMVALUE

//----------------------------------------------------------------------
// CSR Operation Decode
//----------------------------------------------------------------------

  logic [2:0] csr_cmd;
  always_comb begin
    unique case (D_reg.uop)
      OP_CSRRW: csr_cmd = 3'b001; 
      OP_CSRRS: csr_cmd = 3'b010; 
      OP_CSRRC: csr_cmd = 3'b011; 
      default:  csr_cmd = 3'b000; // read
    endcase
  end

//----------------------------------------------------------------------
// CSR Request to CSR File
//----------------------------------------------------------------------


  assign CSR.val   = D_reg.val && W.rdy;
  assign CSR.addr  = D_reg.op2[11:0]; // CSR address
  assign CSR.wdata = D_reg.op1;       // Source register data
  assign CSR.cmd   = csr_cmd;

//----------------------------------------------------------------------
// Assign Remaining Signals
//----------------------------------------------------------------------

  assign W.wdata = CSR.rdata; // Read data from CSR file (previous value in reg)

  assign W.wen   = D_reg.val & (D_reg.waddr != 5'd0);

  assign W.pc      = D_reg.pc;
  assign W.seq_num = D_reg.seq_num;
  assign W.waddr   = D_reg.waddr;
  assign W.preg    = D_reg.preg;
  assign W.ppreg   = D_reg.ppreg;

//----------------------------------------------------------------------
// Handshake Logic
//----------------------------------------------------------------------

  assign D.rdy = (!D_reg.val) | W.rdy;
  assign W.val = D_reg.val;
//----------------------------------------------------------------------
// Linetracing
//----------------------------------------------------------------------

`ifndef SYNTHESIS
  function string trace (int trace_level);
    if (W.val & W.rdy)
      trace = $sformatf("%h: %8s CSR[%03h]=%h -> %h",
                        W.seq_num,
                        D_reg.uop.name(),
                        CSR.addr,
                        CSR.wdata,
                        CSR.rdata);
    else
      trace = " ";
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L1_CSR_V
