//========================================================================
// MRRArb.v
//========================================================================
// An m-select round-robin arbiter initially preferring the least-significant
// input
//
// https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=6673286
// with modifications for variable m-select

`ifndef HW_COMMON_MRRARB_V
`define HW_COMMON_MRRARB_V

module FirstMNonzero #(
  parameter p_width = 4,
  parameter p_max_m = 3
)(
  input  logic [p_width-1:0] in  [p_width],
  output logic [p_width-1:0] out [p_max_m]
);

  int i, k;

  always_comb begin
    for ( i = 0; i < p_max_m; i++) begin
      out[i] = '0;
    end

    k = 0;
    for ( i = 0; i < p_width; i++) begin
      if ((in[i] != '0) && (k < p_max_m)) begin
        out[k] = in[i];
        k++;
      end
    end
  end

endmodule

module MPEth #(
  parameter p_width = 4,
  parameter p_max_m = 4
)(
  input  logic [$clog2(p_max_m):0] m,
  input  logic [p_width-1:0]       req,
  output logic [p_width-1:0]       gnt_th [p_max_m]
);

  logic [$clog2(p_max_m):0] sat_sum     [p_width];
  logic [p_width-1:0]       gnt_th_full [p_width];
  int i;

  always_comb begin

    // Initialize saturated sums
    for( i = 0; i < p_width; i = i + 1 ) begin
      sat_sum[i] = '0;
    end

    // Compute saturated sums
    for( i = 0; i < p_width; i = i + 1 ) begin
      if ( m == 0 ) begin
        sat_sum[i] = '0;
      end else if ( i == 0 ) begin
        sat_sum[i] = ($clog2(p_max_m)+1)'(req[0]);
      end else begin
        sat_sum[i] = sat_sum[i-1] == m ? m : 
          sat_sum[i-1] + ($clog2(p_max_m)+1)'(req[i]);
      end

      // Edge-detect each saturated sum to generate thermo-coded grants
      if ( i == 0 )
        gnt_th_full[i] = ( sat_sum[i] != 0 ) ? {p_width{1'b1}} : '0;
      else begin
        if (sat_sum[i] != sat_sum[i-1])
          gnt_th_full[i] = {p_width{1'b1}} << i;
        else
          gnt_th_full[i] = '0;
      end
    end
  end

  FirstMNonzero #(
    .p_width   ( p_width ),
    .p_max_m   ( p_max_m )
  ) FirstMNonzero_inst (
    .in  ( gnt_th_full ),
    .out ( gnt_th )
  );

endmodule

module merge_mux_stack #(
  parameter int p_width = 8,
  parameter int p_max_m = 4
)(
  input  logic [$clog2(p_max_m):0] m,
  input  logic [p_width-1:0] gnt_p [p_max_m],   // gnt1'..gntM'  (thermo from LSB)
  input  logic [p_width-1:0] gnt_d [p_max_m],   // gnt1''..gntM'' (thermo from LSB)
  output logic [p_width-1:0] gnt   [p_max_m]    // gnt1..gntM
);

  int i, j, k;

  always_comb begin
    for (i = 0; i < p_max_m; i++) begin
      k = 0;
      if (i >= m) gnt[i] = '0;

      // prime is valid -> take it
      else if (gnt_p[i] != '0)
        gnt[i] = gnt_p[i];

      // prime invalid -> take shifted element from double-prime list
      else begin
        for (j = 0; j < i; j++)
          k += int'(gnt_p[j] != '0);
        gnt[i] = gnt_d[i-k];
      end
    end
  end

endmodule

module headptr_update_mux #(
  parameter int p_width = 8,
  parameter int p_max_m = 4
)(
  input  logic [$clog2(p_max_m):0]  m,
  input  logic [p_width-1:0]        headPtr_cur,
  input  logic [p_width-1:0]        gnt          [p_max_m],
  input  logic [p_width-1:0]        gnt_d        [p_max_m],
  output logic [p_width-1:0]        headPtr_next
);

  int i, sel;

  always_comb begin

    // Find highest existing grant according to gnt_d (within [0..m-1])
    sel = -1;
    for ( i = p_max_m-1; i >= 0; i--) begin
      if ((i < m) && (gnt_d[i] != '0) && (sel < 0))
        sel = i;
    end

    // Thermometer-preserving "rotate-left-by-1" on LSB-thermo
    if( sel != -1 ) begin
      if (gnt[sel] == {1'b1, {(p_width-1){1'b0}}})
        headPtr_next = {p_width{1'b1}};
      else
        headPtr_next = gnt[sel] << 1;
    end else
      headPtr_next = headPtr_cur;
  end

endmodule

module MRRArb #(
  parameter p_width = 4,
  parameter p_max_m = 4
)(
  input  logic                     clk,
  input  logic                     rst,
  input  logic                     en,
  input  logic [$clog2(p_max_m):0] m,
  input  logic [p_width-1:0]       req,
  output logic [p_width-1:0]       gnt
);

  //--------------------------------------------------------------------
  // Head pointer reg
  //--------------------------------------------------------------------
  logic [p_width-1:0] head_ptr;
  logic [p_width-1:0] next_head_ptr;

  always_ff @( posedge clk ) begin
    if( rst )    head_ptr <= {p_width{1'b1}};
    else if (en) head_ptr <= next_head_ptr;
  end

  //--------------------------------------------------------------------
  // Priority encoders
  //--------------------------------------------------------------------

  logic [p_width-1:0] gnt_th_p_1 [p_max_m];
  logic [p_width-1:0] gnt_th_p_2 [p_max_m];

  MPEth #(
    .p_width ( p_width ),
    .p_max_m ( p_max_m )
  ) mp_eth1 (
    .m      ( m ),
    .req    ( req & head_ptr ),
    .gnt_th ( gnt_th_p_1 )
  );

  MPEth #(
    .p_width ( p_width ),
    .p_max_m ( p_max_m )
  ) mp_eth2 (
    .m      ( m ),
    .req    ( req ),
    .gnt_th ( gnt_th_p_2 )
  );

  //--------------------------------------------------------------------
  // Priority encoder selector
  //--------------------------------------------------------------------

  logic [p_width-1:0] gnt_th [p_max_m];

  merge_mux_stack #(
    .p_width ( p_width ),
    .p_max_m ( p_max_m )
  ) merge_mux_stack_inst (
    .m     ( m ),
    .gnt_p ( gnt_th_p_1 ),
    .gnt_d ( gnt_th_p_2 ),
    .gnt   ( gnt_th )
  );

  //--------------------------------------------------------------------
  // Head pointer update
  //--------------------------------------------------------------------

  headptr_update_mux #(
    .p_width ( p_width ),
    .p_max_m ( p_max_m )
  ) headptr_update_mux_inst (
    .m            ( m ),
    .headPtr_cur  ( head_ptr ),
    .gnt          ( gnt_th ),
    .gnt_d        ( gnt_th_p_2 ),
    .headPtr_next ( next_head_ptr )
  );

  //--------------------------------------------------------------------
  // Edge-detect and get final grant vector
  //--------------------------------------------------------------------
  logic [p_width-1:0] gnt_ed [p_max_m];

  always_comb begin
    for (int i = 0; i < p_max_m; i++) begin
      if (i >= m)
        gnt_ed[i] = '0;
      else
        gnt_ed[i] = gnt_th[i] & ~( gnt_th[i] << 1 );
    end
    if (en) gnt = gnt_ed.or();
    else    gnt = '0;
  end

endmodule

`endif // HW_COMMON_MRRARB_V
