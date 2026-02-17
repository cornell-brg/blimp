//========================================================================
// M2RenameTable.v
//========================================================================
// A pointer-based rename table, along with the accompanying free list. Also
// supports superscalar backend through freeing multiple physical registers
// simultaneously and updating multiple physical registers' pending statuses

`ifndef HW_DECODE_M2RENAMETABLE_V
`define HW_DECODE_M2RENAMETABLE_V

`include "hw/common/PriorityEncoder.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"

module M2RenameTable #(
  parameter p_num_phys_regs    = 36,
  parameter p_phys_addr_bits   = $clog2(p_num_phys_regs),
  parameter p_num_lookup_ports = 2,
  parameter p_num_be_lanes     = 2
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

  input  logic                  [4:0] lookup_new_inst_areg [2],
  input  logic                        lookup_new_inst_en   [2],
  output logic [p_phys_addr_bits-1:0] lookup_new_inst_preg [2],

  input  logic [p_phys_addr_bits-1:0] lookup_iq_preg    [p_num_lookup_ports][2],
  input  logic                        lookup_iq_en      [p_num_lookup_ports][2],
  output logic                        lookup_iq_pending [p_num_lookup_ports][2],

  // ---------------------------------------------------------------------
  // Complete (clear pending)
  // ---------------------------------------------------------------------
  
  CompleteNotif.sub complete [p_num_be_lanes],

  // ---------------------------------------------------------------------
  // Commit (free)
  // ---------------------------------------------------------------------

  CommitNotif.sub commit [p_num_be_lanes]
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

  logic                        complete_val  [p_num_be_lanes];
  logic [p_phys_addr_bits-1:0] complete_preg [p_num_be_lanes];

  logic                        free_val   [p_num_be_lanes];
  logic [p_phys_addr_bits-1:0] free_ppreg [p_num_be_lanes];

  logic got_complete_pend [31:1];
  logic got_free          [p_num_phys_regs-1:1];

  logic unused_lookup_new_inst_en [2];

  always_comb begin
    for( int k = 0; k < 2; k++ ) begin: UNUSED_LOOKUP_NEW_INST_EN
      unused_lookup_new_inst_en[k] = lookup_new_inst_en[k];
    end
  end

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

      // For this areg, did the instruction writing it complete?
      always_comb begin
        got_complete_pend[i] = '0;
        for( int j = 0; j < p_num_be_lanes; j = j + 1 ) begin: COMPLETE_PEND
          if( complete_val[j] & ( complete_preg[j] == rename_table[i].preg ) ) got_complete_pend[i] = 1'b1;
        end
      end
    
      always_comb begin
        rename_table_next[i] = rename_table[i];
        if( got_complete_pend[i] )
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

      // For this ppreg, did the instruction writing it commit?
      always_comb begin
        got_free[i] = '0;
        for( int j = 0; j < p_num_be_lanes; j = j + 1 ) begin: COMMIT_FREE
          if( free_val[j] & ( free_ppreg[j] == i ) ) got_free[i] = 1'b1;
        end
      end
      
      always_comb begin
        free_list_next[i] = free_list[i];

        if( got_free[i] )
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

  logic [p_phys_addr_bits-1:0] preg_alloc_mask [p_num_phys_regs-1:1];

  generate
    for( i = 1; i < p_num_phys_regs; i = i + 1 ) begin: SELECT_PHYS
      assign preg_alloc_mask[i] = ( preg_alloc_sel_out[i] ) ? p_phys_addr_bits'(i)
                                                            : '0;
    end
  endgenerate

  assign alloc_preg  = ( alloc_areg != 0 ) ? preg_alloc_mask.or()
                                           : 0;
  assign alloc_ppreg = ( alloc_areg != 0 ) ? rename_table[alloc_areg].preg
                                           : 0;
  
  // Only allocate when we have an entry to give and that entry is not pending
  assign alloc_rdy = |preg_alloc_sel_in & ( alloc_areg == 0 || !rename_table[alloc_areg].pending );

  // ---------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------

  logic got_complete_lookup [p_num_lookup_ports][2];
  logic unused_iq_lookup_en [p_num_lookup_ports][2];

  always_comb begin
    for( int j = 0; j < p_num_lookup_ports; j++ ) begin: UNUSED_IQ_LOOKUP_EN_OUTER
      for( int k = 0; k < 2; k++ ) begin: UNUSED_IQ_LOOKUP_EN_INNER
        unused_iq_lookup_en[j][k] = lookup_iq_en[j][k];
      end
    end
  end

  always_comb begin
    for( int k = 0; k < p_num_lookup_ports; k++ ) begin
      for( int l = 0; l < 2; l++ ) begin
        got_complete_lookup[k][l] = '0;
      end
    end
    for( int j = 0; j < p_num_be_lanes; j++ ) begin: GOT_COMPLETE_OUTER
      for( int k = 0; k < p_num_lookup_ports; k++ ) begin: GOT_COMPLETE_MIDDLE
        for( int l = 0; l < 2; l++ ) begin: GOT_COMPLETE_INNER
          if( complete_preg[j] == lookup_iq_preg[k][l] ) got_complete_lookup[k][l] = 1'b1;
        end
      end
    end
  end
  
  always_comb begin
    for( int k = 0; k < p_num_lookup_ports; k++ ) begin: LOOKUP_SET_PENDING_OUTER
      for( int l = 0; l < 2; l++ ) begin: LOOKUP_SET_PENDING_INNER
        if( lookup_iq_preg[k][l] == '0 ) begin
          lookup_iq_pending[k][l] = 0;
        end else begin
          if( got_complete_lookup[k][l] )
            lookup_iq_pending[k][l] = 1'b0; // Bypass
          else begin
            lookup_iq_pending[k][l] = '0;
            for ( int m = 1; m < 32; m++ ) begin: LOOKUP_PENDING_SEARCH
              if( lookup_iq_preg[k][l] == rename_table[m].preg ) begin
                lookup_iq_pending[k][l] = rename_table[m].pending;
              end
            end
          end
        end
      end
    end
  end
  
  always_comb begin
    for( int l = 0; l < 2; l++ ) begin: LOOKUP_PREG_FOR_AREG
      if( lookup_new_inst_areg[l] == '0 ) begin
        lookup_new_inst_preg[l] = '0;
      end else begin
        lookup_new_inst_preg[l] = rename_table[lookup_new_inst_areg[l]].preg;
      end
    end
  end

  // ---------------------------------------------------------------------
  // Not pending on complete
  // ---------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin: COMPLETE_BYPASS_OUT
      assign complete_val[i]  = complete[i].val;
      assign complete_preg[i] = complete[i].preg;
    end
  endgenerate

  // ---------------------------------------------------------------------
  // Free on commit
  // ---------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin: COMMIT_FREE_OUT
      assign free_val[i]   = commit[i].val;
      assign free_ppreg[i] = commit[i].ppreg;
    end
  endgenerate

  // ---------------------------------------------------------------------
  // Linetracing
  // ---------------------------------------------------------------------

// `ifndef SYNTHESIS

//   string test_trace;
//   int    alloc_len;
//   int    lookup_len;
//   int    complete_len;
//   int    free_len;

//   initial begin
//     test_trace = $sformatf("%x > %x (%x)", alloc_areg, alloc_preg, alloc_ppreg);
//     alloc_len  = test_trace.len();

//     test_trace = $sformatf("%x > %x", lookup_areg[0][0], lookup_preg[0][0]);
//     lookup_len = test_trace.len();

//     test_trace   = $sformatf("%x", complete_preg);
//     complete_len = test_trace.len();

//     test_trace = $sformatf("%x", free_ppreg);
//     free_len   = test_trace.len();
//   end

//   function string trace( int trace_level );
//     trace = "[";
//     if( alloc_en & alloc_rdy ) begin
//       if( trace_level > 0 )
//         trace = {trace, $sformatf("%x > %x (%x)", alloc_areg, alloc_preg, alloc_ppreg)};
//       else
//         trace = {trace, $sformatf("%x", alloc_areg)};
//     end
//     else begin
//       if( trace_level > 0 )
//         trace = {trace, {(alloc_len){" "}}};
//       else
//         trace = {trace, {(2){" "}}};
//     end

//     trace = {trace, "] ["};
    
//     for( int j = 0; j < p_num_lookup_ports; j++ ) begin
//       for( int k = 0; k < 2; k++ ) begin
//         if( j != 0 || k != 0 )
//           trace = {trace, ", "};
//         if( lookup_en[j][k] ) begin
//           if( trace_level > 0 )
//             trace = {trace, $sformatf("%x > %x", lookup_areg[j][k], lookup_preg[j][k])};
//           else
//             trace = {trace, $sformatf("%x", lookup_areg[j][k])};
//         end
//         else begin
//           if( trace_level > 0 )
//             trace = {trace, {(lookup_len){" "}}};
//           else
//             trace = {trace, {(2){" "}}};
//         end
//       end
//     end

//     trace = {trace, "] ["};

//     for( int i = 0; i < p_num_be_lanes; i++ ) begin
//       if( complete_val[i] )
//         trace = {trace, $sformatf("%x ", complete_preg[i])};
//       else
//         trace = {trace, {(complete_len){" "}}};
//     end

//     for( int i = 0; i < p_num_be_lanes; i++ ) begin
//       if( free_val[i] )
//         trace = {trace, $sformatf("%x ", free_ppreg[i])};
//       else
//         trace = {trace, {(free_len){" "}}};
//     end

//     trace = {trace, "]"};
//   endfunction
// `endif

endmodule

`endif // HW_DECODE_M2RENAMETABLE_V
