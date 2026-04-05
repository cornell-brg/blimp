//========================================================================
// IssueQueueOOO.v
//========================================================================
// An out-of-order issue queue that dequeues the oldest ready instruction.
// Supports bypassing from input to output when the queue is empty, as
// well as wake-up logic to mark instructions as ready.
//
// This module is a drop-in replacement for IssueQueueInOrder with the
// addition of an oldest_seq_num input for wrap-around-safe age
// comparison.  The key difference is that dequeue selection picks the
// oldest entry whose sources are both ready, rather than blocking on
// the in-order head.
//
// Age comparison uses the same XOR-based wrap-around-safe logic as the
// AgePE in ISLIPCore, referencing the external oldest_seq_num from
// SSSeqAge.
//
// Source operand pending status is provided at insert time and tracked
// internally.  The queue monitors completion notifications to clear
// pending bits, removing the need for rename-table lookups at dequeue.
//
// The message struct (t_msg) must contain .pc, .seq_num, .uop, .src_preg0,
// .src_preg1, .src_pending0, .src_pending1, .waddr, .imm, .op2_sel,
// .op3_sel, .alloc_preg, .alloc_ppreg.

`ifndef HW_DECODE_ISSUEQUEUEOOO_V
`define HW_DECODE_ISSUEQUEUEOOO_V

`include "defs/ISA.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"

module IssueQueueOOO #(
  parameter type t_msg       = logic,
  parameter p_depth          = 8,
  parameter p_num_regs       = 36,
  parameter p_seq_num_bits   = 5,
  parameter p_num_be_lanes   = 2,
  parameter p_addr_bits      = $clog2( p_num_regs ),
  parameter p_entry_bits     = p_depth > 1 ? $clog2(p_depth) : 1,
  parameter p_bypass         = 0
)(
  input logic clk,
  input logic rst,

  //----------------------------------------------------------------------
  // Insert
  //----------------------------------------------------------------------

  input  t_msg                     ins_msg,
  input  logic                     ins_try,
  output logic                     ins_rdy,
  output logic [p_entry_bits:0]    avail_slots,

  //----------------------------------------------------------------------
  // Dequeue
  //----------------------------------------------------------------------

  D__XIntf.D_intf Ex,

  //----------------------------------------------------------------------
  // Age comparison
  //----------------------------------------------------------------------

  input  logic [p_seq_num_bits-1:0] oldest_seq_num,

  //----------------------------------------------------------------------
  // Register File Access
  //----------------------------------------------------------------------

  output logic [p_addr_bits-1:0]  rf_raddr [2],
  input  logic [31:0]             rf_rdata [2],

  // ---------------------------------------------------------------------
  // Complete
  // ---------------------------------------------------------------------

  CompleteNotif.sub complete [p_num_be_lanes]
);

  // Extract interface signals for runtime indexing (Verilator limitation).
  logic                   complete_val  [p_num_be_lanes];
  logic [p_addr_bits-1:0] complete_preg [p_num_be_lanes];

  genvar g;
  generate
    for( g = 0; g < p_num_be_lanes; g++ ) begin: COMPLETE_EXTRACT
      assign complete_val[g]  = complete[g].val;
      assign complete_preg[g] = complete[g].preg;
    end
  endgenerate

  generate
    if( !p_bypass ) begin : NO_BYPASS

      // Adapter signals for Ex interface
      logic deq_val;
      logic deq_rdy;
      assign deq_val = Ex.rdy;
      assign Ex.val = deq_rdy;

      //------------------------------------------------------------------
      // Entry storage
      //------------------------------------------------------------------

      t_msg entries       [p_depth];
      logic entry_valid   [p_depth];
      logic src_pending   [p_depth][2];

      // Extract fields for runtime indexing (Verilator limitation).
      logic [p_addr_bits-1:0]    entry_src_preg0 [p_depth];
      logic [p_addr_bits-1:0]    entry_src_preg1 [p_depth];
      logic [p_seq_num_bits-1:0] entry_seq_num   [p_depth];

      for( g = 0; g < p_depth; g++ ) begin: ENTRY_EXTRACT
        assign entry_src_preg0[g] = entries[g].src_preg0;
        assign entry_src_preg1[g] = entries[g].src_preg1;
        assign entry_seq_num[g]   = entries[g].seq_num;
      end

      //------------------------------------------------------------------
      // Status
      //------------------------------------------------------------------

      logic                  empty;
      logic [p_entry_bits:0] num_valid;

      always_comb begin
        num_valid = '0;
        for( int j = 0; j < p_depth; j++ )
          if( entry_valid[j] ) num_valid = num_valid + 1;
      end

      assign empty       = ( num_valid == '0 );
      assign avail_slots = p_depth[p_entry_bits:0] - num_valid;
      assign ins_rdy     = ( num_valid != p_depth[p_entry_bits:0] );

      //------------------------------------------------------------------
      // Free slot selection (for insertion)
      //------------------------------------------------------------------

      logic [p_entry_bits-1:0] free_idx;
      logic                    free_found;

      always_comb begin
        free_found = 1'b0;
        free_idx   = '0;
        for( int j = 0; j < p_depth; j++ ) begin
          if( !free_found && !entry_valid[j] ) begin
            free_found = 1'b1;
            free_idx   = j[p_entry_bits-1:0];
          end
        end
      end

      //------------------------------------------------------------------
      // Bypass
      //------------------------------------------------------------------

      logic bypass;
      logic both_src_ready;
      assign bypass = ins_try & deq_val & empty;

      //------------------------------------------------------------------
      // Insert
      //------------------------------------------------------------------
      logic [p_entry_bits-1:0]  sel_idx;
      logic                     sel_found;

      logic ins_go;
      assign ins_go = ins_try & ins_rdy & ( !bypass | !both_src_ready );

      // Store entry
      always_ff @( posedge clk ) begin
        if( rst )
          entries <= '{default: '0};
        else if( ins_go )
          entries[free_idx] <= ins_msg;
      end

      // Entry valid management
      always_ff @( posedge clk ) begin
        if( rst ) begin
          for( int j = 0; j < p_depth; j++ )
            entry_valid[j] <= 1'b0;
        end else begin
          if( ins_go )
            entry_valid[free_idx] <= 1'b1;
          if( deq_val & deq_rdy & sel_found & !empty )
            entry_valid[sel_idx] <= 1'b0;
        end
      end

      // Insert and wake-up pending bits
      always_ff @( posedge clk ) begin
        if( rst ) begin
          for( int j = 0; j < p_depth; j++ ) begin
            src_pending[j][0] <= 1'b0;
            src_pending[j][1] <= 1'b0;
          end
        end else begin
          // Wake up: clear pending on completion match
          for( int j = 0; j < p_depth; j++ ) begin
            for( int k = 0; k < p_num_be_lanes; k++ ) begin
              if( complete_val[k] ) begin
                if( complete_preg[k] == entry_src_preg0[j] )
                  src_pending[j][0] <= 1'b0;
                if( complete_preg[k] == entry_src_preg1[j] )
                  src_pending[j][1] <= 1'b0;
              end
            end
          end

          // Insert: set pending from message (overwrites wake-up for this slot)
          if( ins_go ) begin
            src_pending[free_idx][0] <= ins_msg.src_pending0;
            src_pending[free_idx][1] <= ins_msg.src_pending1;
          end
        end
      end

      //------------------------------------------------------------------
      // OOO dequeue selection
      //------------------------------------------------------------------
      // Compute per-entry readiness with same-cycle completion bypass,
      // then select the oldest ready entry using XOR-based wrap-around-
      // safe age comparison (same logic as AgePE in ISLIPCore).

      logic entry_ready [p_depth];

      always_comb begin
        for( int j = 0; j < p_depth; j++ ) begin
          automatic logic p0, p1;
          p0 = src_pending[j][0];
          p1 = src_pending[j][1];
          for( int k = 0; k < p_num_be_lanes; k++ ) begin
            if( complete_val[k] ) begin
              if( complete_preg[k] == entry_src_preg0[j] ) p0 = 1'b0;
              if( complete_preg[k] == entry_src_preg1[j] ) p1 = 1'b0;
            end
          end
          entry_ready[j] = entry_valid[j] & !p0 & !p1;
        end
      end

      // Select oldest ready entry using XOR-based wrap-around-safe
      // comparison.  For each pair of ready entries (i, j), entry j is
      // older than entry i when:
      //
      //   older = (seq[j] < seq[i]) ^ (seq[j] < oldest) ^ (seq[i] < oldest)
      //
      // An entry is the oldest ready if no other ready entry is older.
      logic [p_depth-1:0]       is_oldest;

      always_comb begin
        for( int i = 0; i < p_depth; i++ ) begin
          is_oldest[i] = entry_ready[i];
          if( entry_ready[i] ) begin
            for( int j = 0; j < p_depth; j++ ) begin
              if( entry_ready[j] && (i != j) ) begin
                // Check if entry j is older than entry i
                if( ( entry_seq_num[j] < entry_seq_num[i]  ) ^
                    ( entry_seq_num[j] < oldest_seq_num ) ^
                    ( entry_seq_num[i] < oldest_seq_num ) ) begin
                  is_oldest[i] = 1'b0;
                end
              end
            end
          end
        end
      end

      // Priority-encode is_oldest to get sel_idx
      always_comb begin
        sel_found = 1'b0;
        sel_idx   = '0;
        for( int j = 0; j < p_depth; j++ ) begin
          if( !sel_found && is_oldest[j] ) begin
            sel_found = 1'b1;
            sel_idx   = j[p_entry_bits-1:0];
          end
        end
      end

      //------------------------------------------------------------------
      // Dequeue
      //------------------------------------------------------------------

      // Select between bypass (incoming msg) and queued entry
      t_msg deq_msg;
      assign deq_msg = empty ? ins_msg : entries[sel_idx];

      // Set register file read addresses from dequeuing entry's source pregs
      assign rf_raddr[0] = deq_msg.src_preg0;
      assign rf_raddr[1] = deq_msg.src_preg1;

      // Source readiness for bypass path (when queue is empty)
      logic deq_pending [2];
      always_comb begin
        deq_pending[0] = ins_msg.src_pending0;
        deq_pending[1] = ins_msg.src_pending1;

        // Same-cycle completion bypass
        for( int k = 0; k < p_num_be_lanes; k++ ) begin
          if( complete_val[k] ) begin
            if( complete_preg[k] == ins_msg.src_preg0 )
              deq_pending[0] = 1'b0;
            if( complete_preg[k] == ins_msg.src_preg1 )
              deq_pending[1] = 1'b0;
          end
        end
      end

      assign both_src_ready = !deq_pending[0] & !deq_pending[1];

      // deq_rdy: when empty, bypass if incoming instruction is ready;
      //          when not empty, issue if an OOO-selected entry is ready.
      assign deq_rdy = empty ? ( ins_try & both_src_ready ) : sel_found;

      // Output deq fields
      always_comb begin
        Ex.op1     = rf_rdata[0];
        Ex.pc      = deq_msg.pc;
        Ex.op2     = deq_msg.op2_sel ? deq_msg.imm : rf_rdata[1];
        Ex.uop     = rv_uop'(deq_msg.uop);
        Ex.waddr   = deq_msg.waddr;
        Ex.seq_num = deq_msg.seq_num;
        Ex.preg    = deq_msg.alloc_preg;
        Ex.ppreg   = deq_msg.alloc_ppreg;
        if (deq_msg.op3_sel)
          Ex.op3.branch_imm = deq_msg.imm;
        else
          Ex.op3.mem_data   = rf_rdata[1];
      end

    end else begin : BYPASS

      //------------------------------------------------------------------
      // Full bypass mode (p_bypass = 1)
      //------------------------------------------------------------------

      // Insert outputs
      assign avail_slots = '1;

      // Set register file read addresses
      assign rf_raddr[0] = ins_msg.src_preg0;
      assign rf_raddr[1] = ins_msg.src_preg1;

      // Dequeue outputs
      assign Ex.pc               = ins_msg.pc;
      assign Ex.op1              = rf_rdata[0];
      assign Ex.op2              = ins_msg.op2_sel ?
                                    ins_msg.imm : rf_rdata[1];
      assign Ex.uop              = rv_uop'(ins_msg.uop);
      assign Ex.waddr            = ins_msg.waddr;
      assign Ex.seq_num          = ins_msg.seq_num;
      assign Ex.preg             = ins_msg.alloc_preg;
      assign Ex.ppreg            = ins_msg.alloc_ppreg;
      always_comb begin
        if (ins_msg.op3_sel)
          Ex.op3.branch_imm = ins_msg.imm;
        else
          Ex.op3.mem_data   = rf_rdata[1];
      end

      // Source readiness with same-cycle completion bypass
      logic deq_pending [2];
      always_comb begin
        deq_pending[0] = ins_msg.src_pending0;
        deq_pending[1] = ins_msg.src_pending1;

        for( int k = 0; k < p_num_be_lanes; k++ ) begin
          if( complete_val[k] ) begin
            if( complete_preg[k] == ins_msg.src_preg0 )
              deq_pending[0] = 1'b0;
            if( complete_preg[k] == ins_msg.src_preg1 )
              deq_pending[1] = 1'b0;
          end
        end
      end

      logic both_src_ready;
      assign both_src_ready = !deq_pending[0] & !deq_pending[1];

      assign Ex.val  = ins_try & both_src_ready;
      assign ins_rdy = Ex.rdy;
    end
  endgenerate

endmodule

`endif // HW_DECODE_ISSUEQUEUEOOO_V
