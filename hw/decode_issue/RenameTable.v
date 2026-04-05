//========================================================================
// RenameTable.v
//========================================================================
// A pointer-based rename table, along with the accompanying free list

`ifndef HW_DECODE_RENAMETABLE_V
`define HW_DECODE_RENAMETABLE_V

`include "hw/common/PriorityEncoder.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"

module RenameTable #(
  parameter p_num_phys_regs  = 36,

  parameter p_phys_addr_bits = $clog2(p_num_phys_regs)
) (
  input  logic clk,
  input  logic rst,

  // ---------------------------------------------------------------------
  // Allocation
  // ---------------------------------------------------------------------

  input  logic                  [4:0] alloc_areg,
  output logic [p_phys_addr_bits-1:0] alloc_preg,
  output logic [p_phys_addr_bits-1:0] alloc_ppreg,
  input  logic                        alloc_en,
  output logic                        alloc_rdy,

  // ---------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------

  input  logic                  [4:0] lookup_areg    [2],
  output logic [p_phys_addr_bits-1:0] lookup_preg    [2],
  output logic                        lookup_pending [2],
  input  logic                        lookup_en      [2],

  // ---------------------------------------------------------------------
  // Complete (clear pending)
  // ---------------------------------------------------------------------
  
  CompleteNotif.sub complete,

  // ---------------------------------------------------------------------
  // Commit (free)
  // ---------------------------------------------------------------------

  CommitNotif.sub commit
);

  // ---------------------------------------------------------------------
  // Data Structures
  // ---------------------------------------------------------------------

  typedef struct packed {
    logic                        pending;
    logic [p_phys_addr_bits-1:0] preg;
  } rt_entry_t;

  rt_entry_t rename_table      [31:1]; // No x0
  rt_entry_t rename_table_next [31:1];
  logic      free_list         [p_num_phys_regs-1:1];
  logic      free_list_next    [p_num_phys_regs-1:1];

  // ---------------------------------------------------------------------
  // Update Logic
  // ---------------------------------------------------------------------

  logic alloc_xfer;

  logic                        complete_val;
  logic [p_phys_addr_bits-1:0] complete_preg;

  logic                        free_val;
  logic [p_phys_addr_bits-1:0] free_ppreg;

  genvar i;
  generate
    for( i = 1; i < 32; i = i + 1 ) begin: RENAME_UPDATE
      always_ff @( posedge clk ) begin
        if( rst ) begin
          rename_table[i] <= '{pending: 1'b0, preg: p_phys_addr_bits'(i)};
        end else begin
          rename_table[i] <= rename_table_next[i];
        end
      end
      
      always_comb begin
        rename_table_next[i] = rename_table[i];
        if( complete_val & ( complete_preg == rename_table[i].preg ) )
          rename_table_next[i].pending = 1'b0;
        if( alloc_xfer & ( alloc_areg == i )) begin
          rename_table_next[i].pending = 1'b1;
          rename_table_next[i].preg    = alloc_preg;
        end
      end
    end
  endgenerate

  generate
    for( i = 1; i < p_num_phys_regs; i = i + 1 ) begin: FREE_UPDATE
      always_ff @( posedge clk ) begin
        if( rst ) begin
          if( i < 32 )
            free_list[i] <= 1'b0;
          else
            free_list[i] <= 1'b1;
        end else begin
          free_list[i] <= free_list_next[i];
        end
      end

      always_comb begin
        free_list_next[i] = free_list[i];

        if( free_val & ( free_ppreg == i ) )
          free_list_next[i] = 1'b1;
        if( alloc_xfer & ( alloc_preg == i ) )
          free_list_next[i] = 1'b0;
      end
    end
  endgenerate

  // ---------------------------------------------------------------------
  // Allocation
  // ---------------------------------------------------------------------

  assign alloc_xfer = alloc_en & alloc_rdy;

  // Use priority encoder to get first free physical address
  logic [p_num_phys_regs-1:1] preg_alloc_sel_in, preg_alloc_sel_out;

  generate
    for( i = 1; i < p_num_phys_regs; i = i + 1 ) begin: PACK_FREE
      assign preg_alloc_sel_in[i] = free_list[i];
    end
  endgenerate

  PriorityEncoder #( 
    .p_width (p_num_phys_regs - 1)
  ) preg_sel (
    .in  (preg_alloc_sel_in),
    .out (preg_alloc_sel_out)
  );

  logic [p_phys_addr_bits-1:0] alloc_preg_sel;

  always_comb begin
    alloc_preg_sel = '0;
    for( int j = 1; j < p_num_phys_regs; j++ )
      if( preg_alloc_sel_out[j] )
        alloc_preg_sel = p_phys_addr_bits'(j);
  end

  assign alloc_preg  = ( alloc_areg != 0 ) ? alloc_preg_sel
                                           : 0;
  assign alloc_ppreg = ( alloc_areg != 0 ) ? rename_table[alloc_areg].preg
                                           : 0;
  
  // Only allocate when we have an entry to give
  assign alloc_rdy = |preg_alloc_sel_in;

  // ---------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------

  logic unused_lookup_en [2];
  assign unused_lookup_en[0] = lookup_en[0];
  assign unused_lookup_en[1] = lookup_en[1];

  always_comb begin
    if( lookup_areg[0] == '0 ) begin
      lookup_preg[0]    = '0;
      lookup_pending[0] = 0;
    end else begin
      lookup_preg[0]    = rename_table[lookup_areg[0]].preg;
      if( complete_preg == lookup_preg[0] )
        lookup_pending[0] = 1'b0; // Bypass
      else
        lookup_pending[0] = rename_table[lookup_areg[0]].pending;
    end

    if( lookup_areg[1] == '0 ) begin
      lookup_preg[1]    = '0;
      lookup_pending[1] = 0;
    end else begin
      lookup_preg[1]    = rename_table[lookup_areg[1]].preg;
      if( complete_preg == lookup_preg[1] )
        lookup_pending[1] = 1'b0; // Bypass
      else
        lookup_pending[1] = rename_table[lookup_areg[1]].pending;
    end
  end

  // ---------------------------------------------------------------------
  // Not pending on complete
  // ---------------------------------------------------------------------

  assign complete_val  = complete.val;
  assign complete_preg = complete.preg;

  // ---------------------------------------------------------------------
  // Free on commit
  // ---------------------------------------------------------------------

  assign free_val   = commit.val;
  assign free_ppreg = commit.ppreg;

  // ---------------------------------------------------------------------
  // Linetracing
  // ---------------------------------------------------------------------

`ifndef SYNTHESIS

  string test_trace;
  int    alloc_len;
  int    lookup_len;
  int    complete_len;
  int    free_len;

  initial begin
    test_trace = $sformatf("%x > %x (%x)", alloc_areg, alloc_preg, alloc_ppreg);
    alloc_len  = test_trace.len();

    test_trace = $sformatf("%x > %x", lookup_areg[0], lookup_preg[0]);
    lookup_len = test_trace.len();

    test_trace   = $sformatf("%x", complete_preg);
    complete_len = test_trace.len();

    test_trace = $sformatf("%x", free_ppreg);
    free_len   = test_trace.len();
  end

  function string trace( int trace_level );
    trace = "[";
    if( alloc_en & alloc_rdy ) begin
      if( trace_level > 0 )
        trace = {trace, $sformatf("%x > %x (%x)", alloc_areg, alloc_preg, alloc_ppreg)};
      else
        trace = {trace, $sformatf("%x", alloc_areg)};
    end
    else begin
      if( trace_level > 0 )
        trace = {trace, {(alloc_len){" "}}};
      else
        trace = {trace, {(2){" "}}};
    end

    trace = {trace, "] ["};

    if( lookup_en[0] ) begin
      if( trace_level > 0 )
        trace = {trace, $sformatf("%x > %x", lookup_areg[0], lookup_preg[0])};
      else
        trace = {trace, $sformatf("%x", lookup_areg[0])};
    end
    else begin
      if( trace_level > 0 )
        trace = {trace, {(lookup_len){" "}}};
      else
        trace = {trace, {(2){" "}}};
    end
    trace = {trace, ", "};
    if( lookup_en[1] ) begin
      if( trace_level > 0 )
        trace = {trace, $sformatf("%x > %x", lookup_areg[1], lookup_preg[1])};
      else
        trace = {trace, $sformatf("%x", lookup_areg[1])};
    end
    else begin
      if( trace_level > 0 )
        trace = {trace, {(lookup_len){" "}}};
      else
        trace = {trace, {(2){" "}}};
    end

    trace = {trace, "] ["};

    if( complete_val )
      trace = {trace, $sformatf("%x", complete_preg)};
    else
      trace = {trace, {(complete_len){" "}}};

    trace = {trace, " "};

    if( free_val )
      trace = {trace, $sformatf("%x", free_ppreg)};
    else
      trace = {trace, {(free_len){" "}}};

    trace = {trace, "]"};
  endfunction
`endif

endmodule

`endif // HW_DECODE_RENAMETABLE_V
