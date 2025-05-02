//========================================================================
// LoadStoreUnitL3.v
//========================================================================
// An execute unit for performing memory operations

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L3_LOADSTOREUNITL3_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L3_LOADSTOREUNITL3_V

`include "defs/UArch.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"
`include "intf/MemIntf.v"

import UArch::*;

module LoadStoreUnitL3 #(
  parameter p_opaq_bits = 8
)(
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
  // Memory Interface
  //----------------------------------------------------------------------

  MemIntf.client  mem
);

  localparam p_seq_num_bits   = D.p_seq_num_bits;
  localparam p_phys_addr_bits = D.p_phys_addr_bits;
  
  //----------------------------------------------------------------------
  // Types
  //----------------------------------------------------------------------

  typedef struct packed {
    logic                        val;
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                 [31:0] op1;
    logic                 [31:0] op2;
    logic                  [4:0] waddr;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
    logic                 [31:0] mem_data;
    rv_uop                       uop;
  } D_input;

  typedef struct packed {
    logic                        val;
    logic                 [31:0] pc;
    logic   [p_seq_num_bits-1:0] seq_num;
    logic                  [4:0] waddr;
    logic [p_phys_addr_bits-1:0] preg;
    logic [p_phys_addr_bits-1:0] ppreg;
    logic                        wen;
  } stage2_msg;
  
  //----------------------------------------------------------------------
  // Stage 1: Request
  //----------------------------------------------------------------------

  D_input D_reg;
  D_input D_reg_next;
  logic   D_xfer;

  logic      stage2_val;
  logic      stage2_rdy;
  logic      stage2_xfer;
  stage2_msg stage2_reg;
  stage2_msg stage2_reg_next;

  logic W_xfer;

  // verilator lint_off ENUMVALUE

  always_ff @( posedge clk ) begin
    if ( rst )
      D_reg <= '{ 
        val:      1'b0, 
        pc:       'x,
        seq_num:  'x,
        op1:      'x, 
        op2:      'x,
        waddr:    'x,
        preg:     'x,
        ppreg:    'x,
        mem_data: 'x,
        uop:      'x
      };
    else
      D_reg <= D_reg_next;
  end

  always_comb begin
    D_xfer      = D.val      & D.rdy;
    stage2_xfer = stage2_val & stage2_rdy;

    if ( D_xfer )
      D_reg_next = '{ 
        val:      1'b1, 
        pc:       D.pc,
        seq_num:  D.seq_num,
        op1:      D.op1, 
        op2:      D.op2,
        waddr:    D.waddr,
        preg:     D.preg,
        ppreg:    D.ppreg,
        mem_data: D.op3.mem_data,
        uop:      D.uop
      };
    else if ( stage2_xfer )
      D_reg_next = '{ 
        val:      1'b0, 
        pc:       'x,
        seq_num:  'x,
        op1:      'x, 
        op2:      'x,
        waddr:    'x,
        preg:     'x,
        ppreg:    'x,
        mem_data: 'x,
        uop:      'x
      };
    else
      D_reg_next = D_reg;
  end

  // verilator lint_on ENUMVALUE

  //----------------------------------------------------------------------
  // Memory Operations
  //----------------------------------------------------------------------
  
  logic [31:0] op1, op2;
  assign op1 = D_reg.op1;
  assign op2 = D_reg.op2;

  logic [31:0] addr;
  assign addr = op1 + op2;

  rv_uop uop;
  assign uop = D_reg.uop;

  always_comb begin
    case( uop )
      OP_LW:   mem.req_msg.op = MEM_MSG_READ;
      OP_SW:   mem.req_msg.op = MEM_MSG_WRITE;
      default: mem.req_msg.op = MEM_MSG_READ;
    endcase
  end

  assign mem.req_msg.opaque = '0;
  assign mem.req_msg.strb   = '1;
  assign mem.req_msg.addr   = addr;
  assign mem.req_msg.data   = D_reg.mem_data;
  assign mem.req_val        = D_reg.val & stage2_rdy;

  stage2_msg stage1_output;

  assign stage1_output.val     = D_reg.val;
  assign stage1_output.pc      = D_reg.pc;
  assign stage1_output.seq_num = D_reg.seq_num;
  assign stage1_output.waddr   = D_reg.waddr;
  assign stage1_output.wen     = ( uop == OP_LW );
  assign stage1_output.preg    = D_reg.preg;
  assign stage1_output.ppreg   = D_reg.ppreg;

  assign stage2_val = D_reg.val & mem.req_rdy;
  assign D.rdy      = (stage2_rdy & mem.req_rdy) | (!D_reg.val);

  //----------------------------------------------------------------------
  // Stage 2: Response
  //----------------------------------------------------------------------

  always_ff @( posedge clk ) begin
    if ( rst )
      stage2_reg <= '{ 
        val:     1'b0, 
        pc:      'x,
        seq_num: 'x,
        waddr:   'x,
        preg:    'x,
        ppreg:   'x,
        wen:     'x
      };
    else
      stage2_reg <= stage2_reg_next;
  end

  always_comb begin
    W_xfer = W.val & W.rdy;

    if ( stage2_xfer )
      stage2_reg_next = stage1_output;
    else if ( W_xfer )
      stage2_reg_next = '{ 
        val:     1'b0, 
        pc:      'x,
        seq_num: 'x,
        waddr:   'x,
        preg:    'x,
        ppreg:   'x,
        wen:     'x
      };
    else
      stage2_reg_next = stage2_reg;
  end

  //----------------------------------------------------------------------
  // Memory Operations
  //----------------------------------------------------------------------

  t_op                    unused_resp_op;
  logic [p_opaq_bits-1:0] unused_resp_opaque;
  logic            [31:0] unused_resp_addr;
  logic             [3:0] unused_resp_strb;

  assign unused_resp_op     = mem.resp_msg.op;
  assign unused_resp_opaque = mem.resp_msg.opaque;
  assign unused_resp_addr   = mem.resp_msg.addr;
  assign unused_resp_strb   = mem.resp_msg.strb;
  assign W.wdata            = mem.resp_msg.data;

  assign W.pc               = stage2_reg.pc;
  assign W.waddr            = stage2_reg.waddr;
  assign W.seq_num          = stage2_reg.seq_num;
  assign W.wen              = stage2_reg.wen;
  assign W.preg             = stage2_reg.preg;
  assign W.ppreg            = stage2_reg.ppreg;

  assign mem.resp_rdy = stage2_reg.val & W.rdy;
  assign W.val        = stage2_reg.val & mem.resp_val;
  assign stage2_rdy   = (W.rdy & mem.resp_val) | !stage2_reg.val;

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return (val / 4) + ((val % 4) > 0 ? 1 : 0);
  endfunction

  int req_len;
  assign req_len = 11                         + 1 + // uop
                   ceil_div_4(p_seq_num_bits) + 1 + // seq_num
                   8                          + 1 + // addr
                   8;                               // data

  int resp_len;
  assign resp_len = 11                         + 1 + // uop
                    ceil_div_4(p_seq_num_bits) + 1 + // seq_num
                    8                          + 1 + // addr
                    8;                               // data
                    

  function string trace( int trace_level );
    if( stage2_val & stage2_rdy ) begin
      if( trace_level > 0 )
        trace = $sformatf("%11s:%h:%h:%h", uop.name(), 
                          D_reg.seq_num, addr, D_reg.mem_data );
      else
        trace = $sformatf("%h", D_reg.seq_num);
    end else begin
      if( trace_level > 0 )
        trace = {req_len{" "}};
      else
        trace = {(ceil_div_4(p_seq_num_bits)){" "}};
    end

    trace = {trace, " > "};

    if( W.val & W.rdy ) begin
      if( trace_level > 0 )
        trace = {trace, $sformatf("%11s:%h:%h:%h",
                        (stage2_reg.wen ? "OP_LW" : "OP_SW"),
                        stage2_reg.seq_num, mem.resp_msg.addr, W.wdata )};
      else
        trace = {trace, $sformatf("%h", stage2_reg.seq_num)};
    end else begin
      if( trace_level > 0 )
        trace = {trace, {resp_len{" "}}};
      else
        trace = {trace, {(ceil_div_4(p_seq_num_bits)){" "}}};
    end
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L3_LOADSTOREUNITL3_V
