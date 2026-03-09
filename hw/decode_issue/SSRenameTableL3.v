//========================================================================
// SSRenameTableL3.v
//========================================================================
// A pointer-based rename table, along with the accompanying free list. Also
// supports superscalar backend through freeing multiple physical registers
// simultaneously and updating multiple physical registers' pending statuses

`ifndef HW_DECODE_SSRENAMETABLEL3_V
`define HW_DECODE_SSRENAMETABLEL3_V

`include "hw/common/PriorityEncoder.v"
`include "intf/CompleteNotif.v"
`include "intf/CommitNotif.v"

module SSRenameTableL3 #(
  parameter p_num_phys_regs    = 36,
  parameter p_phys_addr_bits   = $clog2(p_num_phys_regs),
  parameter p_num_lookup_ports = 2,
  parameter p_num_fe_lanes     = 2,
  parameter p_num_be_lanes     = 2
) (
  input  logic clk,
  input  logic rst,

  // ---------------------------------------------------------------------
  // Allocation
  // ---------------------------------------------------------------------

  // Allocation must be successful on all lanes with alloc_try set in order
  // to continue
  input  logic                  [4:0] alloc_areg  [p_num_fe_lanes],
  /* verilator lint_off UNOPTFLAT */
  output logic [p_phys_addr_bits-1:0] alloc_preg  [p_num_fe_lanes],
  /* verilator lint_on UNOPTFLAT */
  output logic [p_phys_addr_bits-1:0] alloc_ppreg [p_num_fe_lanes],
  input  logic                        alloc_try   [p_num_fe_lanes],
  input  logic                        alloc_val   [p_num_fe_lanes],
  output logic                        alloc_rdy   [p_num_fe_lanes],

  // ---------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------

  input  logic                  [4:0] lookup_new_inst_areg [p_num_fe_lanes][2],
  input  logic                        lookup_new_inst_en   [p_num_fe_lanes][2],
  output logic [p_phys_addr_bits-1:0] lookup_new_inst_preg [p_num_fe_lanes][2],

  input  logic [p_phys_addr_bits-1:0] lookup_preg    [p_num_lookup_ports][2],
  input  logic                        lookup_preg_en [p_num_lookup_ports][2],
  output logic                        lookup_pending [p_num_lookup_ports][2],

  // ---------------------------------------------------------------------
  // Complete (clear pending)
  // ---------------------------------------------------------------------
  
  CompleteNotif.sub complete [p_num_be_lanes],

  // ---------------------------------------------------------------------
  // Commit (free)
  // ---------------------------------------------------------------------

  CommitNotif.sub commit [p_num_be_lanes]
);
  localparam p_num_fe_lanes_idx_bits = p_num_fe_lanes > 1 ? 
                                       $clog2(p_num_fe_lanes) : 1;

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

  logic alloc_xfer [p_num_fe_lanes];

  logic                        complete_val  [p_num_be_lanes];
  logic [p_phys_addr_bits-1:0] complete_preg [p_num_be_lanes];

  logic                        free_val   [p_num_be_lanes];
  logic [p_phys_addr_bits-1:0] free_ppreg [p_num_be_lanes];

  logic got_complete_pend [31:1];
  logic got_free          [p_num_phys_regs-1:1];

  logic unused_lookup_new_inst_en [p_num_fe_lanes][2];

  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin: UNUSED_LOOKUP_NEW_INST_EN
      for( int l = 0; l < 2; l++ ) begin
        unused_lookup_new_inst_en[k][l] = lookup_new_inst_en[k][l];
      end
    end
  end

  genvar i;
  generate
    for( i = 1; i < 32; i = i + 1 ) begin: RENAME_UPDATE
      logic                               do_rename_reg;
      logic [p_num_fe_lanes_idx_bits-1:0] do_rename_lane;

      always_ff @( posedge clk ) begin
        if( rst ) begin
          rename_table[i] <= '{pending: 1'b0, preg: p_phys_addr_bits'(i)};
        end else if( got_complete_pend[i] || 
          (do_rename_reg && alloc_val[do_rename_lane]) ) begin
          rename_table[i] <= rename_table_next[i];
        end
      end

      // Check if this areg (i) just completed - check all complete ports
      always_comb begin
        got_complete_pend[i] = '0;
        for( int j = 0; j < p_num_be_lanes; j++ ) begin: COMPLETE_PEND
          if( complete_val[j] & ( complete_preg[j] == rename_table[i].preg ) ) 
            got_complete_pend[i] = 1'b1;
        end
      end
    
      always_comb begin
        rename_table_next[i] = rename_table[i];

        // The preg for this areg (i) just completed, so no longer pending
        if( got_complete_pend[i] )
          rename_table_next[i].pending = 1'b0;

        // We just allocated this areg (i), so update preg and set pending
        do_rename_reg  = 1'b0;
        do_rename_lane = '0;
        for( int j = 0; j < p_num_fe_lanes; j++ ) begin: ALLOC_UPDATE
          if( alloc_xfer[j] & ( alloc_areg[j] == i )) begin
            rename_table_next[i].pending = 1'b1;
            rename_table_next[i].preg    = alloc_preg[j];
            do_rename_reg = 1'b1;
            do_rename_lane = p_num_fe_lanes_idx_bits'(j);
          end
        end
      end
    end
  endgenerate

  generate
    for( i = 1; i < p_num_phys_regs; i++ ) begin: FREE_UPDATE
      logic                               do_free_reg;
      logic [p_num_fe_lanes_idx_bits-1:0] do_free_lane;

      always_ff @( posedge clk ) begin
        if( rst ) begin
          if( i < 32 )
            free_list[i] <= 1'b0;
          else
            free_list[i] <= 1'b1;
        end else if( got_free[i] || 
          (do_free_reg && alloc_val[do_free_lane]) ) begin
          free_list[i] <= free_list_next[i];
        end
      end

      // Check if this ppreg (i) just committed - check all commit ports
      always_comb begin
        got_free[i] = '0;
        for( int j = 0; j < p_num_be_lanes; j++ ) begin: COMMIT_FREE
          if( free_val[j] & ( free_ppreg[j] == i ) ) got_free[i] = 1'b1;
        end
      end
      
      always_comb begin
        free_list_next[i] = free_list[i];

        // The ppreg (i) just got freed, so add it to the free list
        if( got_free[i] )
          free_list_next[i] = 1'b1;

        // The preg (i) that was just allocated on some lane is no longer free,
        // so remove it from the free list
        do_free_reg  = 1'b0;
        do_free_lane = '0;
        for( int j = 0; j < p_num_fe_lanes; j++ ) begin: ALLOC_FREE
          if( alloc_xfer[j] & ( alloc_preg[j] == i ) ) begin
            free_list_next[i] = 1'b0;
            do_free_reg = 1'b1;
            do_free_lane = p_num_fe_lanes_idx_bits'(j);
          end
        end
      end
    end
  endgenerate

  // ---------------------------------------------------------------------
  // Allocation
  // ---------------------------------------------------------------------

  genvar j;
  generate
    for( i = 0; i < p_num_fe_lanes; i++ ) begin: ALLOC_LANES
      assign alloc_xfer[i] = alloc_val[i] & alloc_rdy[i];

      // Use priority encoder to get first free physical address from freelist
      logic [p_num_phys_regs-1:1] preg_alloc_sel_in, preg_alloc_sel_out;

      for( j = 1; j < p_num_phys_regs; j++ ) begin: PACK_FREE

        // check previous lanes for conflicts on this preg before selecting it
        // for this lane
        always_comb begin
          preg_alloc_sel_in[j] = free_list[j] | got_free[j];
          for( int k = 0; k < i; k++ ) begin: ALLOC_CONFLICT

            // if allocating preg j on a previous lane, can't select it for this
            // lane
            if( alloc_areg[k] != 0 && alloc_preg[k] == j && alloc_try[k] )
              preg_alloc_sel_in[j] = 1'b0;
          end
        end
      end

      PriorityEncoder #( 
        .p_width (p_num_phys_regs - 1)
      ) preg_sel (
        .in  (preg_alloc_sel_in),
        .out (preg_alloc_sel_out)
      );

      logic [p_phys_addr_bits-1:0] preg_alloc_mask [p_num_phys_regs-1:1];

      for( j = 1; j < p_num_phys_regs; j++ ) begin: SELECT_PHYS
        assign preg_alloc_mask[j] = 
          ( preg_alloc_sel_out[j] ) ? p_phys_addr_bits'(j) : '0;
      end

      // Allocated preg for this lane is output from priority encoder
      logic [p_phys_addr_bits-1:0] alloc_preg_or;
      always_comb begin
        alloc_preg_or = '0;
        for (int k = 1; k < p_num_phys_regs; k++)
          alloc_preg_or = alloc_preg_or | preg_alloc_mask[k];
      end
      assign alloc_preg[i] = ( alloc_areg[i] != 0 ) ? alloc_preg_or : '0;

      // Allocated ppreg for this lane is the previous preg for this areg
      assign alloc_ppreg[i] = ( alloc_areg[i] != 0 ) ? 
        rename_table[alloc_areg[i]].preg : 0;
      
      // Only allocate on this lane when we have an entry to give and that entry
      // is not pending, if multiple lanes are allocating the same areg then
      // choose oldest one
      logic is_dup_areg;
      always_comb begin
        is_dup_areg = 1'b0;
        for( int k = 0; k < i; k++ ) begin: DUP_AREG
          if( ( alloc_areg[k] != 0 ) & ( alloc_areg[k] == alloc_areg[i] ) && 
            alloc_try[k] )
            is_dup_areg = 1'b1;
        end
      end

      assign alloc_rdy[i] = |preg_alloc_sel_in & (
        alloc_areg[i] == 0 ||
        !rename_table[alloc_areg[i]].pending ||
        got_complete_pend[alloc_areg[i]]
      ) & !is_dup_areg;
    end
  endgenerate

  // ---------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------

  logic got_complete_lookup [p_num_lookup_ports][2];
  logic unused_iq_lookup_preg_en [p_num_lookup_ports][2];

  always_comb begin
    for( int j = 0; j < p_num_lookup_ports; j++ ) begin: UNUSED_IQ_lookup_preg_en_OUTER
      for( int k = 0; k < 2; k++ ) begin: UNUSED_IQ_lookup_preg_en_INNER
        unused_iq_lookup_preg_en[j][k] = lookup_preg_en[j][k];
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
          if( complete_preg[j] == lookup_preg[k][l] ) 
            got_complete_lookup[k][l] = 1'b1;
        end
      end
    end
  end
  
  logic found_alloc;
  always_comb begin
    for( int k = 0; k < p_num_lookup_ports; k++ ) begin: LOOKUP_SET_PENDING_OUTER
      for( int l = 0; l < 2; l++ ) begin: LOOKUP_SET_PENDING_INNER
        if( lookup_preg[k][l] == '0 ) begin
          lookup_pending[k][l] = 0;
          found_alloc = 1'b0;
        end else if( got_complete_lookup[k][l] ) begin
          lookup_pending[k][l] = 1'b0; // Bypass
          found_alloc = 1'b0;
        end else begin
          // Check if preg was just allocated this cycle
          // (uses alloc_try, not alloc_val, to break comb loop through dispatch_go)
          found_alloc = 1'b0;
          for ( int m = 0; m < p_num_fe_lanes; m++ ) begin: LOOKUP_ALLOC_FWD
            if( alloc_try[m] && alloc_areg[m] != 0 &&
                lookup_preg[k][l] == alloc_preg[m] )
              found_alloc = 1'b1;
          end

          if( found_alloc )
            lookup_pending[k][l] = 1'b1;
          else begin
            lookup_pending[k][l] = '0;
            for ( int m = 1; m < 32; m++ ) begin: LOOKUP_PENDING_SEARCH
              if( lookup_preg[k][l] == rename_table[m].preg )
                lookup_pending[k][l] = rename_table[m].pending;
            end
          end
        end
      end
    end
  end
  
  always_comb begin
    for( int k = 0; k < p_num_fe_lanes; k++ ) begin
      for( int l = 0; l < 2; l++ ) begin: LOOKUP_PREG_FOR_AREG
        if( lookup_new_inst_areg[k][l] == '0 ) begin
          lookup_new_inst_preg[k][l] = '0;

        // Check if previous lanes have renamed this areg, use that for the preg
        // if so, use lane closest to this lane
        end else begin
          lookup_new_inst_preg[k][l] = 
            rename_table[lookup_new_inst_areg[k][l]].preg;
          for( int m = 0; m < k; m++ ) begin
            if( alloc_try[m] && 
                alloc_areg[m] == lookup_new_inst_areg[k][l]) begin
              lookup_new_inst_preg[k][l] = alloc_preg[m];
            end
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------------
  // Not pending on complete
  // ---------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin: COMPLETE_BYPASS_OUT
      assign complete_val[i]  = complete[i].val;
      assign complete_preg[i] = complete[i].preg;
    end
  endgenerate

  // ---------------------------------------------------------------------
  // Free on commit
  // ---------------------------------------------------------------------

  generate
    for( i = 0; i < p_num_be_lanes; i++ ) begin: COMMIT_FREE_OUT
      assign free_val[i]   = commit[i].val;
      assign free_ppreg[i] = commit[i].ppreg;
    end
  endgenerate

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
    test_trace = $sformatf("%x > %x (%x)", alloc_areg[0], alloc_preg[0], alloc_ppreg[0]);
    alloc_len  = test_trace.len();

    test_trace = $sformatf("%x > %x", lookup_new_inst_areg[0][0], lookup_new_inst_preg[0][0]);
    lookup_len = test_trace.len();

    test_trace   = $sformatf("%x", complete_preg[0]);
    complete_len = test_trace.len();

    test_trace = $sformatf("%x", free_ppreg[0]);
    free_len   = test_trace.len();
  end

  function string trace( int trace_level );
    trace = "[";
    for( int i = 0; i < p_num_fe_lanes; i++ ) begin
      if( i != 0 )
        trace = {trace, ", "};
      if( alloc_try[i] & alloc_rdy[i] ) begin
        if( trace_level > 0 )
          trace = {trace, $sformatf("%x > %x (%x)", alloc_areg[i], alloc_preg[i], alloc_ppreg[i])};
        else
          trace = {trace, $sformatf("%x", alloc_areg[i])};
      end
      else begin
        if( trace_level > 0 )
          trace = {trace, {(alloc_len){" "}}};
        else
          trace = {trace, {(2){" "}}};
      end
    end

    trace = {trace, "] ["};

    for( int j = 0; j < p_num_fe_lanes; j++ ) begin
      for( int k = 0; k < 2; k++ ) begin
        if( j != 0 || k != 0 )
          trace = {trace, ", "};
        if( lookup_new_inst_en[j][k] ) begin
          if( trace_level > 0 )
            trace = {trace, $sformatf("%x > %x", lookup_new_inst_areg[j][k], lookup_new_inst_preg[j][k])};
          else
            trace = {trace, $sformatf("%x", lookup_new_inst_areg[j][k])};
        end
        else begin
          if( trace_level > 0 )
            trace = {trace, {(lookup_len){" "}}};
          else
            trace = {trace, {(2){" "}}};
        end
      end
    end

    trace = {trace, "] ["};

    for( int i = 0; i < p_num_be_lanes; i++ ) begin
      if( complete_val[i] )
        trace = {trace, $sformatf("%x ", complete_preg[i])};
      else
        trace = {trace, {(complete_len){" "}}};
    end

    for( int i = 0; i < p_num_be_lanes; i++ ) begin
      if( free_val[i] )
        trace = {trace, $sformatf("%x ", free_ppreg[i])};
      else
        trace = {trace, {(free_len){" "}}};
    end

    trace = {trace, "]"};
  endfunction
`endif

endmodule

`endif // HW_DECODE_SSRENAMETABLEL3_V
