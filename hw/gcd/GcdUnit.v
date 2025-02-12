//========================================================================
// GCD Unit RTL Implementation
//========================================================================

`ifndef HW_GCD_GCD_UNIT_V
`define HW_GCD_GCD_UNIT_V

`include "intf/StreamIntf.v"

//========================================================================
// GCD Unit Datapath
//========================================================================

module hw_gcd_GcdUnitDpath
(
  input  logic        clk,
  input  logic        rst,

  // Data signals

  input  logic [31:0] istream_msg,
  output logic [15:0] ostream_msg,

  // Control signals

  input  logic        a_reg_en,   // Enable for A register
  input  logic        b_reg_en,   // Enable for B register
  input  logic [1:0]  a_mux_sel,  // Sel for mux in front of A reg
  input  logic        b_mux_sel,  // sel for mux in front of B reg

  // Status signals

  output logic        is_b_zero,  // Output of zero comparator
  output logic        is_a_lt_b   // Output of less-than comparator
);

  localparam c_nbits = 16;

  // Split out the a and b operands

  logic [c_nbits-1:0] istream_msg_a;
  assign istream_msg_a = istream_msg[31:16];

  logic [c_nbits-1:0] istream_msg_b;
  assign istream_msg_b = istream_msg[15:0];

  // A Mux

  logic [c_nbits-1:0] b_reg_out;
  logic [c_nbits-1:0] sub_out;
  logic [c_nbits-1:0] a_mux_out;

  always_comb begin
    case(a_mux_sel)
      2'd0:    a_mux_out = istream_msg_a;
      2'd1:    a_mux_out = b_reg_out;
      2'd2:    a_mux_out = sub_out;
      default: a_mux_out = 'x;
    endcase
  end

  // A register

  logic [c_nbits-1:0] a_reg_out;

  always_ff @( posedge clk ) begin
    if( rst )
      a_reg_out <= '0;
    else if( a_reg_en )
      a_reg_out <= a_mux_out;
  end

  // B Mux

  logic [c_nbits-1:0] b_mux_out;

  always_comb begin
    case( b_mux_sel )
      1'b0:    b_mux_out = istream_msg_b;
      1'b1:    b_mux_out = a_reg_out;
      default: b_mux_out = 'x;
    endcase
  end

  // B register

  always_ff @( posedge clk ) begin
    if( rst )
      b_reg_out <= '0;
    else if( b_reg_en )
      b_reg_out <= b_mux_out;
  end

  // Less-than comparator

  assign is_a_lt_b = ( a_reg_out < b_reg_out );

  // Zero comparator

  assign is_b_zero = ( b_reg_out == '0 );

  // Subtractor

  assign sub_out = ( a_reg_out - b_reg_out );

  // Connect to output port

  assign ostream_msg = sub_out;

endmodule

//========================================================================
// GCD Unit Control
//========================================================================

module hw_gcd_GcdUnitCtrl
(
  input  logic        clk,
  input  logic        rst,

  // Dataflow signals

  input  logic        istream_val,
  output logic        istream_rdy,
  output logic        ostream_val,
  input  logic        ostream_rdy,

  // Control signals

  output logic        a_reg_en,   // Enable for A register
  output logic        b_reg_en,   // Enable for B register
  output logic [1:0]  a_mux_sel,  // Sel for mux in front of A reg
  output logic        b_mux_sel,  // sel for mux in front of B reg

  // Data signals

  input  logic        is_b_zero,  // Output of zero comparator
  input  logic        is_a_lt_b   // Output of less-than comparator
);

  //----------------------------------------------------------------------
  // State Definitions
  //----------------------------------------------------------------------

  localparam STATE_IDLE = 2'd0;
  localparam STATE_CALC = 2'd1;
  localparam STATE_DONE = 2'd2;

  //----------------------------------------------------------------------
  // State
  //----------------------------------------------------------------------

  logic [1:0] state_reg;
  logic [1:0] state_next;

  always_ff @( posedge clk ) begin
    if ( rst ) begin
      state_reg <= STATE_IDLE;
    end
    else begin
      state_reg <= state_next;
    end
  end

  //----------------------------------------------------------------------
  // State Transitions
  //----------------------------------------------------------------------

  logic req_go;
  logic resp_go;
  logic is_calc_done;

  assign req_go       = istream_val && istream_rdy;
  assign resp_go      = ostream_val && ostream_rdy;
  assign is_calc_done = !is_a_lt_b && is_b_zero;

  always_comb begin

    state_next = state_reg;

    case ( state_reg )

      STATE_IDLE: if ( req_go    )    state_next = STATE_CALC;
      STATE_CALC: if ( is_calc_done ) state_next = STATE_DONE;
      STATE_DONE: if ( resp_go   )    state_next = STATE_IDLE;
      default:    state_next = 'x;

    endcase

  end

  //----------------------------------------------------------------------
  // State Outputs
  //----------------------------------------------------------------------

  localparam a_x   = 2'dx;
  localparam a_ld  = 2'd0;
  localparam a_b   = 2'd1;
  localparam a_sub = 2'd2;

  localparam b_x   = 1'dx;
  localparam b_ld  = 1'd0;
  localparam b_a   = 1'd1;

  function void cs
  (
    input logic       cs_istream_rdy,
    input logic       cs_ostream_val,
    input logic [1:0] cs_a_mux_sel,
    input logic       cs_a_reg_en,
    input logic       cs_b_mux_sel,
    input logic       cs_b_reg_en
  );
  begin
    istream_rdy = cs_istream_rdy;
    ostream_val = cs_ostream_val;
    a_reg_en    = cs_a_reg_en;
    b_reg_en    = cs_b_reg_en;
    a_mux_sel   = cs_a_mux_sel;
    b_mux_sel   = cs_b_mux_sel;
  end
  endfunction

  // Labels for Mealy transistions

  logic do_swap;
  logic do_sub;

  assign do_swap = is_a_lt_b;
  assign do_sub  = !is_b_zero;

  // Set outputs using a control signal "table"

  always_comb begin

    cs( 0, 0, a_x, 0, b_x, 0 );
    case ( state_reg )
      //                             istream ostream a mux  a  b mux b
      //                             rdy  val  sel    en sel   en
      STATE_IDLE:                cs( 1,   0,   a_ld,  1, b_ld, 1 );
      STATE_CALC: if ( do_swap ) cs( 0,   0,   a_b,   1, b_a,  1 );
             else if ( do_sub  ) cs( 0,   0,   a_sub, 1, b_x,  0 );
      STATE_DONE:                cs( 0,   1,   a_x,   0, b_x,  0 );
      default                    cs('x,  'x,   a_x,  'x, b_x, 'x );

    endcase

  end

endmodule

//========================================================================
// GCD Unit
//========================================================================

module hw_gcd_GcdUnit
(
  input  logic        clk,
  input  logic        rst,

  StreamIntf.istream istream,
  StreamIntf.ostream ostream
);

  //----------------------------------------------------------------------
  // Connect Control Unit and Datapath
  //----------------------------------------------------------------------

  // Control signals

  logic        a_reg_en;
  logic        b_reg_en;
  logic [1:0]  a_mux_sel;
  logic        b_mux_sel;

  // Data signals

  logic        is_b_zero;
  logic        is_a_lt_b;

  // Control unit

  hw_gcd_GcdUnitCtrl ctrl
  (
    .istream_val (istream.val),
    .istream_rdy (istream.rdy),
    .ostream_val (ostream.val),
    .ostream_rdy (ostream.rdy),
    .*
  );

  // Datapath

  hw_gcd_GcdUnitDpath dpath
  (
    .istream_msg (istream.msg),
    .ostream_msg (ostream.msg),
    .*
  );

  //----------------------------------------------------------------------
  // Line Tracing
  //----------------------------------------------------------------------

  `ifndef SYNTHESIS

  function string trace();
    trace = "";

    trace = {trace, $sformatf( "%x", dpath.a_reg_out )};
    trace = {trace, " "};
    trace = {trace, $sformatf( "%x", dpath.b_reg_out )};
    trace = {trace, " "};

    case ( ctrl.state_reg )
      ctrl.STATE_IDLE:
        trace = {trace, "I "};

      ctrl.STATE_CALC:
      begin
        if ( ctrl.do_swap )
          trace = {trace, "Cs"};
        else if ( ctrl.do_sub )
          trace = {trace, "C-"};
        else
          trace = {trace, "C "};
      end

      ctrl.STATE_DONE:
        trace = {trace, "Ds"};

      default:
        trace = {trace, "? "};
    endcase
  endfunction

  `endif /* SYNTHESIS */

endmodule

`endif /* HW_GCD_GCD_UNIT_V */

