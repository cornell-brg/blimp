//========================================================================
// IssueQueueInOrder.v
//========================================================================
// An in-order circular issue queue that only dequeues instructions in program
// order. Supports bypassing from the input to the output if possible, as well
// as wake-up logic to mark instructions as ready.
//
// Source operand pending status is provided at insert time and tracked
// internally.  The queue monitors completion notifications to clear
// pending bits, removing the need for rename-table lookups at dequeue.
//
// The message struct (t_msg) must contain .pc, .seq_num, .uop, .src_preg0,
// .src_preg1, .src_pending0, .src_pending1, .waddr, .imm, .op2_sel,
// .op3_sel, .alloc_preg, .alloc_ppreg.

`ifndef HW_DECODE_ISSUEQUEUEINORDER_V
`define HW_DECODE_ISSUEQUEUEINORDER_V

`include "defs/ISA.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"

module IssueQueueInOrder #(
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
  output logic                     ins_ack,
  output logic [p_entry_bits:0]    avail_slots,

  //----------------------------------------------------------------------
  // Dequeue
  //----------------------------------------------------------------------

  D__XIntf.D_intf Ex,

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
    if( !p_bypass ) begin

      // Adapter signals for Ex interface
      logic deq_val;
      logic deq_rdy;
      assign deq_val = Ex.rdy;
      assign Ex.val = deq_rdy;

      //----------------------------------------------------------------------
      // Entries
      //----------------------------------------------------------------------

      t_msg entries [p_depth];
      logic src_pending [p_depth][2];

      logic [p_entry_bits:0] deq_ptr;
      logic [p_entry_bits:0] ins_ptr;

      //----------------------------------------------------------------------
      // Insert
      //----------------------------------------------------------------------
      logic empty;
      logic bypass;

      // Set status signals
      assign empty       = ( ins_ptr == deq_ptr );
      assign avail_slots = p_depth - ( ins_ptr - deq_ptr );
      assign ins_rdy     = ( avail_slots != '0 );
      assign ins_ack     = ins_try & ins_rdy;

      // Insert entry
      always_ff @( posedge clk ) begin
        if( rst ) begin
          entries <= '{default: 'x};
        end else begin
          if( ins_try & (!bypass | !both_src_ready) ) begin
            entries[ins_ptr[p_entry_bits-1:0]] <= ins_msg;
          end
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
                if( complete_preg[k] == entries[j].src_preg0 )
                  src_pending[j][0] <= 1'b0;
                if( complete_preg[k] == entries[j].src_preg1 )
                  src_pending[j][1] <= 1'b0;
              end
            end
          end

          // Insert: set pending from message (overwrites wake-up for this slot)
          if( ins_try & (!bypass | !both_src_ready) ) begin
            src_pending[ins_ptr[p_entry_bits-1:0]][0] <= ins_msg.src_pending0;
            src_pending[ins_ptr[p_entry_bits-1:0]][1] <= ins_msg.src_pending1;
          end
        end
      end

      // update ins_ptr
      always_ff @( posedge clk ) begin
        if( rst )
          ins_ptr <= '0;
        else if( ins_try & (!bypass | !both_src_ready) )
          ins_ptr <= ins_ptr + 1;
      end

      //----------------------------------------------------------------------
      // Bypass
      //----------------------------------------------------------------------

      assign bypass = ins_try & deq_val & empty;

      //----------------------------------------------------------------------
      // Dequeue
      //----------------------------------------------------------------------

      // Select between bypass (incoming msg) and queued entry
      t_msg deq_msg;
      assign deq_msg = empty ? ins_msg : entries[deq_ptr[p_entry_bits-1:0]];

      // Set register file read addresses from dequeuing entry's source pregs
      assign rf_raddr[0] = deq_msg.src_preg0;
      assign rf_raddr[1] = deq_msg.src_preg1;

      // Source readiness: check stored pending bits (or insert-time pending
      // for bypass), with same-cycle completion bypass.
      logic deq_pending [2];
      always_comb begin
        if( empty ) begin
          // Bypass path: use insert-time pending from message
          deq_pending[0] = ins_msg.src_pending0;
          deq_pending[1] = ins_msg.src_pending1;
        end else begin
          deq_pending[0] = src_pending[deq_ptr[p_entry_bits-1:0]][0];
          deq_pending[1] = src_pending[deq_ptr[p_entry_bits-1:0]][1];
        end

        // Same-cycle completion bypass
        for( int k = 0; k < p_num_be_lanes; k++ ) begin
          if( complete_val[k] ) begin
            if( complete_preg[k] == deq_msg.src_preg0 )
              deq_pending[0] = 1'b0;
            if( complete_preg[k] == deq_msg.src_preg1 )
              deq_pending[1] = 1'b0;
          end
        end
      end

      logic both_src_ready;
      assign both_src_ready = !deq_pending[0] & !deq_pending[1];
      assign deq_rdy = ( !empty | ins_try ) & both_src_ready;

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

      // Update deq_ptr
      always_ff @( posedge clk ) begin
        if( rst )
          deq_ptr <= '0;
        else if( deq_val & deq_rdy & !bypass )
          deq_ptr <= deq_ptr + 1;
      end
    end else begin

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
      assign ins_ack = Ex.val & Ex.rdy;
    end
  endgenerate

endmodule

`endif // HW_DECODE_ISSUEQUEUEINORDER_V
