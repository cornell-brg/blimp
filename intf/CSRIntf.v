//========================================================================
// CSRIntf.v
//========================================================================
// Author: Emily Lan
//========================================================================
// Interface definition between the CSR execute unit and CSR register file
`ifndef CSR_INTF_V
`define CSR_INTF_V


interface CSRIntf;
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Signals
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  logic        val;      
  logic        rdy;     
  logic [11:0] addr;     // CSR address (e.g. 0x300 mstatus, 0x003 fcsr)
  logic [31:0] wdata;    
  logic [31:0] rdata;    
  logic  [2:0] cmd;      // Command: 000=read, 001=write, 010=set, 011=clear

  // verilator lint_off UNUSEDSIGNAL
  // (No additional parameters or sequence numbers yet)
  // verilator lint_on UNUSEDSIGNAL

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Module-facing Ports
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
  // CSR Execute Unit <-> CSR File
  modport X_intf ( // Execute stage side (CSRUnit)
    output val,
    output addr,
    output wdata,
    output cmd,
    input  rdy,
    input  rdata
  );
  modport F_intf ( // CSRFile side 
    input  val,
    input  addr,
    input  wdata,
    input  cmd,
    output rdy,
    output rdata
  );
endinterface
`endif // INTF_CSR_INTF_V