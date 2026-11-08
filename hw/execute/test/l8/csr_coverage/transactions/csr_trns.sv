class csr_trns;
  // CSR interface signals as seen at execute unit boundary
  // Aligns with `CSRIntf.X_intf` fields driven by `CSR.v`
  rand bit              csr_val;
  bit                   csr_rdy;      // typically always 1 in CSRFile
  rand bit [11:0]       csr_addr;     // CSR address (imm[11:0])
  rand bit [31:0]       csr_wdata;    // rs1 value
  rand bit [2:0]        csr_cmd;      // 0: read, 1: CSRRW, 2: CSRRS, 3: CSRRC
  bit       [31:0]      csr_rdata;    // returned old CSR value

  // X->W handshake (to correlate with sampling moments)
  bit                   w_val;
  bit                   w_rdy;
  rand bit [4:0]        waddr;        // destination GPR index
  bit                   wen;          // writeback enable

  // Derived flags/patterns for targeted bins
  bit waddr_is_x0;
  bit wdata_all_zero;
  bit wdata_all_one;
  bit rdata_all_zero;
  bit rdata_all_one;
  // Derived consistency flags
  bit csr_val_consistent; // csr_val == (w_val && w_rdy)
  // Sentinel for CSR.wdata connectivity to D_reg.op1
  rand bit [31:0] op1_mirror;        // mirror of D.op1 from testbench
  bit csr_wdata_consistent;          // csr_wdata == op1_mirror

  // Functional coverage for CSR behavior (manual sampling via sample_cov())
  covergroup CSRCovGrp;
    // Handshake gating
    coverpoint csr_val {
      bins inactive = {0};
      bins active   = {1};
    }
    coverpoint csr_rdy {
      bins not_ready = {0};
      bins ready     = {1};
    }
    x_handshake: cross csr_val, csr_rdy;

    // Command semantics
    coverpoint csr_cmd {
      bins read   = {3'b000};
      bins csrrw  = {3'b001};
      bins csrrs  = {3'b010};
      bins csrrc  = {3'b011};
      bins others = default;
    }

    // Addresses of interest (per CSRFile.v: 0x001, 0x002, 0x003)
    coverpoint csr_addr {
      bins fflags = {12'h001};
      bins frm    = {12'h002};
      bins fcsr   = {12'h003};
      bins other  = default;
    }

    // Data patterns (lightweight extremes + default)
    coverpoint wdata_all_zero {
      bins yes = {1};
      bins no  = {0};
    }
    coverpoint wdata_all_one {
      bins yes = {1};
      bins no  = {0};
    }
    coverpoint rdata_all_zero {
      bins yes = {1};
      bins no  = {0};
    }
    coverpoint rdata_all_one {
      bins yes = {1};
      bins no  = {0};
    }

    // Writeback gating (x0 suppression)
    coverpoint waddr_is_x0 {
      bins x0  = {1};
      bins nx0 = {0};
    }
    coverpoint wen {
      bins no_write = {0};
      bins write    = {1};
    }
    x_waddr_wen: cross waddr_is_x0, wen;

    // Key behavioral crosses
    x_cmd_addr:  cross csr_cmd, csr_addr;
    x_cmd_x0:    cross csr_cmd, waddr_is_x0;

    // Connectivity sentinel for CSR.wdata wiring
    coverpoint csr_wdata_consistent {
      bins connected_behavior = {1};
      illegal_bins inconsistent_or_stub = {0};
    }
  endgroup

  function new();
    CSRCovGrp = new();
  endfunction

  // Compute derived flags and sample coverage on demand
  function void sample_cov();
    waddr_is_x0   = (waddr == 5'd0);
    wdata_all_zero= (csr_wdata == 32'h0000_0000);
    wdata_all_one = (csr_wdata == 32'hFFFF_FFFF);
    rdata_all_zero= (csr_rdata == 32'h0000_0000);
    rdata_all_one = (csr_rdata == 32'hFFFF_FFFF);
    csr_val_consistent   = (csr_val == (w_val & w_rdy));
    csr_wdata_consistent = (csr_wdata == op1_mirror);

    CSRCovGrp.sample();
  endfunction

  // Helper for debug printing
  function void display();
    $display("csr_trns: val=%0b rdy=%0b cmd=%0b addr=0x%03h",
             csr_val, csr_rdy, csr_cmd, csr_addr);
    $display("          wdata=0x%08h rdata=0x%08h waddr=%0d wen=%0b",
             csr_wdata, csr_rdata, waddr, wen);
  endfunction
endclass
