//========================================================================
// LoadStoreUnitL7.v
//========================================================================
// An execute unit for performing memory operations (int and fp)

`ifndef HW_EXECUTE_EXECUTE_VARIANTS_L7_LOADSTOREUNITL7_V
`define HW_EXECUTE_EXECUTE_VARIANTS_L7_LOADSTOREUNITL7_V

`include "defs/UArch.v"
`include "hw/common/Fifo.v"
`include "intf/D__XIntf.v"
`include "intf/X__WIntf.v"
`include "intf/MemIntf.v"

import UArch::*;

module LoadStoreUnitL7 #(
  parameter p_opaq_bits     = 8,
  parameter p_num_in_flight = 8
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

  MemIntf.client mem
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
    rv_uop                       uop;
    logic                  [1:0] offset;
  } stage2_msg;

  //----------------------------------------------------------------------
  // Stage 1: Request
  //----------------------------------------------------------------------

  D_input D_reg;
  D_input D_reg_next;
  logic   D_xfer;

  logic      stage2_val;
  logic      stage2_rdy;
  stage2_msg stage2_reg;
  stage2_msg stage2_reg_next;
  logic      stage2_push, stage2_pop, stage2_empty, stage2_full;

  logic W_xfer;

  // verilator lint_off ENUMVALUE

  always_ff @( posedge clk ) begin
    if ( rst )
<<<<<<< HEAD
      D_reg <= '{ 
        val:      1'b0, 
        pc:       '0,
        seq_num:  '0,
        op1:      '0, 
        op2:      '0,
        waddr:    '0,
        preg:     '0,
        ppreg:    '0,
        mem_data: '0,
        uop:      rv_uop'('0)
=======
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
>>>>>>> origin/blimp-v9-infra/rtl
      };
    else
      D_reg <= D_reg_next;
  end

  always_comb begin
    D_xfer = D.val & D.rdy;

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
    else if ( stage2_push )
<<<<<<< HEAD
      D_reg_next = '{ 
        val:      1'b0, 
        pc:       '0,
        seq_num:  '0,
        op1:      '0, 
        op2:      '0,
        waddr:    '0,
        preg:     '0,
        ppreg:    '0,
        mem_data: '0,
        uop:      rv_uop'('0)
=======
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
>>>>>>> origin/blimp-v9-infra/rtl
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
    case ( uop )
      OP_LB,
      OP_LH,
      OP_LW,
      OP_LBU,
      OP_LHU,
      OP_FLW:  mem.req_msg.op = MEM_MSG_READ;

      OP_SB,
      OP_SH,
      OP_SW,
      OP_FSW:  mem.req_msg.op = MEM_MSG_WRITE;

      default: mem.req_msg.op = MEM_MSG_READ;
    endcase
  end

  logic [3:0] base_strb;

  always_comb begin
    case ( uop )
      OP_LB,
      OP_LBU,
      OP_SB:   base_strb = 4'b0001;

      OP_LH,
      OP_LHU,
      OP_SH:   base_strb = 4'b0011;

      OP_LW,
      OP_SW,
      OP_FLW,
      OP_FSW:  base_strb = 4'b1111;

      default: base_strb = 'x;
    endcase
  end

  // Decompose address

  logic [31:0] aligned_addr;
  logic  [1:0] stage1_addr_offset;

  assign aligned_addr       = { addr[31:2], 2'b00 };
  assign stage1_addr_offset = addr[1:0];

  assign mem.req_msg.opaque = '0;
  assign mem.req_msg.strb   = base_strb << stage1_addr_offset;
  assign mem.req_msg.addr   = aligned_addr;
  assign mem.req_val        = D_reg.val & stage2_rdy;

  always_comb begin
    case ( stage1_addr_offset )
      2'd0: mem.req_msg.data = D_reg.mem_data;
      2'd1: mem.req_msg.data = D_reg.mem_data << 8;
      2'd2: mem.req_msg.data = D_reg.mem_data << 16;
      2'd3: mem.req_msg.data = D_reg.mem_data << 24;
    endcase
  end

  stage2_msg stage1_output;

  assign stage1_output.val     = D_reg.val;
  assign stage1_output.pc      = D_reg.pc;
  assign stage1_output.seq_num = D_reg.seq_num;
  assign stage1_output.waddr   = D_reg.waddr;
  assign stage1_output.uop     = uop;
  assign stage1_output.offset  = stage1_addr_offset;
  assign stage1_output.preg    = D_reg.preg;
  assign stage1_output.ppreg   = D_reg.ppreg;

  assign stage2_val  = D_reg.val & mem.req_rdy;
  assign D.rdy       = ( stage2_rdy & mem.req_rdy ) | ( !D_reg.val );
  assign stage2_rdy  = !stage2_full;
  assign stage2_push = stage2_val;

  stage2_msg stage2_input;

  Fifo #(
    .p_entry_bits ( $bits(stage2_msg) ),
    .p_depth      ( p_num_in_flight )
  ) stage2_fifo (
    .clk   ( clk         ),
    .rst   ( rst         ),
    .push  ( stage2_push ),
    .pop   ( stage2_pop  ),
    .empty ( stage2_empty ),
    .full  ( stage2_full ),
    .wdata ( stage1_output ),
    .rdata ( stage2_input  )
  );

  //----------------------------------------------------------------------
  // Stage 2: Response
  //----------------------------------------------------------------------

  // verilator lint_off ENUMVALUE
  always_ff @( posedge clk ) begin
    if ( rst )
<<<<<<< HEAD
      stage2_reg <= '{ 
        val:     1'b0, 
        pc:      '0,
        seq_num: '0,
        waddr:   '0,
        preg:    '0,
        ppreg:   '0,
        uop:     rv_uop'('0),
        offset:  '0
=======
      stage2_reg <= '{
        val:     1'b0,
        pc:      'x,
        seq_num: 'x,
        waddr:   'x,
        preg:    'x,
        ppreg:   'x,
        uop:     'x,
        offset:  'x
>>>>>>> origin/blimp-v9-infra/rtl
      };
    else
      stage2_reg <= stage2_reg_next;
  end

  always_comb begin
    W_xfer = W.val & W.rdy;

    if ( stage2_pop )
      stage2_reg_next = stage2_input;
    else if ( W_xfer )
<<<<<<< HEAD
      stage2_reg_next = '{ 
        val:     1'b0, 
        pc:      '0,
        seq_num: '0,
        waddr:   '0,
        preg:    '0,
        ppreg:   '0,
        uop:     rv_uop'('0),
        offset:  '0
=======
      stage2_reg_next = '{
        val:     1'b0,
        pc:      'x,
        seq_num: 'x,
        waddr:   'x,
        preg:    'x,
        ppreg:   'x,
        uop:     'x,
        offset:  'x
>>>>>>> origin/blimp-v9-infra/rtl
      };
    else
      stage2_reg_next = stage2_reg;
  end
  // verilator lint_on ENUMVALUE

  //----------------------------------------------------------------------
  // Determine correct data
  //----------------------------------------------------------------------

  logic [31:0] base_data, load_data;

  always_comb begin
    case ( stage2_reg.offset )
      2'd0: base_data = mem.resp_msg.data;
      2'd1: base_data = mem.resp_msg.data >> 8;
      2'd2: base_data = mem.resp_msg.data >> 16;
      2'd3: base_data = mem.resp_msg.data >> 24;
    endcase
  end

  always_comb begin
<<<<<<< HEAD
    case( stage2_reg.uop )
      OP_LB:   sext_data = { {24{base_data[7] }}, base_data[7:0]  };
      OP_LH:   sext_data = { {16{base_data[15]}}, base_data[15:0] };
      OP_LW:   sext_data = base_data;
      OP_LBU:  sext_data = { 24'b0, base_data[7:0]  };
      OP_LHU:  sext_data = { 16'b0, base_data[15:0] };
      OP_SB:   sext_data = '0;
      OP_SH:   sext_data = '0;
      OP_SW:   sext_data = '0;
      default: sext_data = '0;
=======
    case ( stage2_reg.uop )
      OP_LB:   load_data = { {24{base_data[7]}},  base_data[7:0]   };
      OP_LH:   load_data = { {16{base_data[15]}}, base_data[15:0]  };
      OP_LW:   load_data = base_data;
      OP_LBU:  load_data = { 24'b0, base_data[7:0]  };
      OP_LHU:  load_data = { 16'b0, base_data[15:0] };
      OP_FLW:  load_data = base_data;

      OP_SB,
      OP_SH,
      OP_SW,
      OP_FSW:  load_data = 'x;

      default: load_data = 'x;
>>>>>>> origin/blimp-v9-infra/rtl
    endcase
  end

  //----------------------------------------------------------------------
  // Writeback / response handling
  //----------------------------------------------------------------------

  t_op                    unused_resp_op;
  logic [p_opaq_bits-1:0] unused_resp_opaque;
  logic            [31:0] unused_resp_addr;
  logic             [3:0] unused_resp_strb;

  assign unused_resp_op     = mem.resp_msg.op;
  assign unused_resp_opaque = mem.resp_msg.opaque;
  assign unused_resp_addr   = mem.resp_msg.addr;
  assign unused_resp_strb   = mem.resp_msg.strb;

  assign W.wdata   = load_data;
  assign W.pc      = stage2_reg.pc;
  assign W.waddr   = stage2_reg.waddr;
  assign W.seq_num = stage2_reg.seq_num;
  assign W.preg    = stage2_reg.preg;
  assign W.ppreg   = stage2_reg.ppreg;

  // FLW writes into the FP domain; integer loads write into INT.
  assign W.is_fp = ( stage2_reg.uop == OP_FLW );

  always_comb begin
    case ( stage2_reg.uop )
      OP_LB,
      OP_LH,
      OP_LW,
      OP_LBU,
      OP_LHU,
      OP_FLW:  W.wen = 1'b1;

      OP_SB,
      OP_SH,
      OP_SW,
      OP_FSW:  W.wen = 1'b0;

      default: W.wen = 1'bx;
    endcase
  end

  assign mem.resp_rdy = stage2_reg.val & W.rdy;
  assign W.val        = stage2_reg.val & mem.resp_val;
  assign stage2_pop   = ( ( W.rdy & mem.resp_val ) | !stage2_reg.val ) & !stage2_empty;

  //----------------------------------------------------------------------
  // Linetracing
  //----------------------------------------------------------------------

`ifndef SYNTHESIS
  function int ceil_div_4( int val );
    return ( val / 4 ) + ( ( val % 4 ) > 0 ? 1 : 0 );
  endfunction

  int req_len;
  assign req_len = 11                         + 1 +
                   ceil_div_4(p_seq_num_bits) + 1 +
                   8                          + 1 +
                   8;

  int resp_len;
  assign resp_len = 11                         + 1 +
                    ceil_div_4(p_seq_num_bits) + 1 +
                    8                          + 1 +
                    8;

  function string trace( int trace_level );
    if ( stage2_val & stage2_rdy ) begin
      if ( trace_level > 0 )
        trace = $sformatf( "%11s:%h:%h:%h",
                           uop.name(),
                           D_reg.seq_num,
                           addr,
                           D_reg.mem_data );
      else
        trace = $sformatf( "%h", D_reg.seq_num );
    end
    else begin
      if ( trace_level > 0 )
        trace = { req_len{" "} };
      else
        trace = { (ceil_div_4(p_seq_num_bits)){" "} };
    end

    trace = { trace, " > " };

    if ( W.val & W.rdy ) begin
      if ( trace_level > 0 )
        trace = { trace,
                  $sformatf( "%11s:%h:%h:%h",
                             stage2_reg.uop.name(),
                             stage2_reg.seq_num,
                             mem.resp_msg.addr,
                             W.wdata ) };
      else
        trace = { trace, $sformatf( "%h", stage2_reg.seq_num ) };
    end
    else begin
      if ( trace_level > 0 )
        trace = { trace, { resp_len{" "} } };
      else
        trace = { trace, { (ceil_div_4(p_seq_num_bits)){" "} } };
    end
  endfunction
`endif

endmodule

`endif // HW_EXECUTE_EXECUTE_VARIANTS_L7_LOADSTOREUNITL7_V
