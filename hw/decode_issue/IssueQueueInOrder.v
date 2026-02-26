//========================================================================
// IssueQueueInOrder.v
//========================================================================
// An in-order circular issue queue that only dequeues instructions in program
// order. Supports bypassing from the input to the output if possible, as well
// as wake-up logic to mark instructions as ready.

`ifndef HW_DECODE_ISSUEQUEUEINORDER_V
`define HW_DECODE_ISSUEQUEUEINORDER_V

`include "defs/ISA.v"
`include "intf/D__XIntf.v"
`include "intf/CompleteNotif.v"

module IssueQueueInOrder #(
  parameter p_depth        = 8,
  parameter p_num_regs     = 36,
  parameter p_seq_num_bits = 5,
  parameter p_num_be_lanes = 2,
  parameter p_addr_bits    = $clog2( p_num_regs ),
  parameter p_entry_bits   = p_depth > 1 ? $clog2(p_depth) : 1,
  parameter p_bypass       = 0
)(
  input logic clk,
  input logic rst,

  //----------------------------------------------------------------------
  // Insert
  //----------------------------------------------------------------------

  input  logic [31:0]               ins_msg_pc,
  input  logic [p_addr_bits-1:0]    ins_msg_preg [2],
  input  rv_uop                     ins_msg_decoder_uop,
  input  logic [4:0]                ins_msg_decoder_waddr,
  input  logic [31:0]               ins_msg_imm,
  input  logic                      ins_msg_decoder_op2_sel,
  input  logic                      ins_msg_decoder_op3_sel,
  input  logic [p_seq_num_bits-1:0] ins_msg_seq_num,
  input  logic [p_addr_bits-1:0]    ins_msg_alloc_preg,
  input  logic [p_addr_bits-1:0]    ins_msg_alloc_ppreg,
  input  logic                      ins_en,
  output logic                      ins_rdy,
  output logic [p_entry_bits:0]     avail_slots,

  //----------------------------------------------------------------------
  // Dequeue
  //----------------------------------------------------------------------

  D__XIntf.D_intf Ex,

  //----------------------------------------------------------------------
  // Rename Table Access
  //----------------------------------------------------------------------

  output logic [p_addr_bits-1:0] rt_lookup_preg    [2],
  input  logic                   rt_lookup_pending [2],
  output logic                   rt_lookup_en      [2],

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

  logic                   complete_val  [p_num_be_lanes];
  logic                   complete_wen  [p_num_be_lanes];
  logic [p_addr_bits-1:0] complete_preg [p_num_be_lanes];

  // Extract complete signals
  generate
    for( genvar i = 0; i < p_num_be_lanes; i++ ) begin: COMPLETE_SIGNALS_EXTRACT_GEN
      assign complete_val[i]  = complete[i].val;
      assign complete_wen[i]  = complete[i].wen;
      assign complete_preg[i] = complete[i].preg;
    end
  endgenerate

  generate
    if( !p_bypass ) begin

      // Adapter signals for Ex interface
      logic deq_en;
      logic deq_rdy;
      assign deq_en = Ex.rdy;
      assign Ex.val = deq_rdy;

      //----------------------------------------------------------------------
      // Entries
      //----------------------------------------------------------------------

      typedef struct packed {
        logic [31:0]               pc;
        logic [p_addr_bits-1:0]    preg0;
        logic [p_addr_bits-1:0]    preg1;
        rv_uop                     decoder_uop;
        logic [4:0]                decoder_waddr;
        logic [31:0]               imm;
        logic                      decoder_op2_sel;
        logic                      decoder_op3_sel;
        logic [p_seq_num_bits-1:0] seq_num;
        logic [p_addr_bits-1:0]    alloc_preg;
        logic [p_addr_bits-1:0]    alloc_ppreg;
      } t_ins_msg;

      t_ins_msg entries [p_depth];

      logic [p_entry_bits:0] deq_ptr;
      logic [p_entry_bits:0] ins_ptr;

      //----------------------------------------------------------------------
      // Insert
      //----------------------------------------------------------------------
      logic full, empty;
      logic bypass;

      // Set status signals
      assign full        = ( (ins_ptr[p_entry_bits-1] != deq_ptr[p_entry_bits-1]) &&
                            (ins_ptr[p_entry_bits-2:0] == deq_ptr[p_entry_bits-2:0]) );
      assign empty       = ( ins_ptr == deq_ptr );
      assign ins_rdy     = !full;
      assign avail_slots = p_depth - ( ins_ptr - deq_ptr );

      // Insert entry
      always_ff @( posedge clk ) begin
        if( rst ) begin
          entries <= '{default: 'x};
        end else begin
          if( ins_en & (!bypass | !both_src_ready) ) begin
            entries[ins_ptr[p_entry_bits-1:0]] <= '{
              decoder_uop     : ins_msg_decoder_uop,      
              preg0           : ins_msg_preg[0],
              preg1           : ins_msg_preg[1],
              decoder_waddr   : ins_msg_decoder_waddr,
              imm             : ins_msg_imm,
              decoder_op2_sel : ins_msg_decoder_op2_sel,
              decoder_op3_sel : ins_msg_decoder_op3_sel,
              alloc_preg      : ins_msg_alloc_preg,
              alloc_ppreg     : ins_msg_alloc_ppreg,
              pc              : ins_msg_pc,
              seq_num         : ins_msg_seq_num
            };
          end
        end
      end

      // update ins_ptr
      always_ff @( posedge clk ) begin
        if( rst )
          ins_ptr <= '0;
        else if( ins_en & (!bypass | !both_src_ready) )
          ins_ptr <= ins_ptr + 1;
      end

      //----------------------------------------------------------------------
      // Bypass
      //----------------------------------------------------------------------
      logic can_bypass;

      assign can_bypass = ( ins_ptr == deq_ptr );
      assign bypass = ins_en & deq_en & can_bypass;

      //----------------------------------------------------------------------
      // Dequeue
      //----------------------------------------------------------------------
      logic op2_sel;
      assign op2_sel = can_bypass ? ins_msg_decoder_op2_sel : 
                        entries[deq_ptr[p_entry_bits-1:0]].decoder_op2_sel;

      logic op3_sel;
      assign op3_sel = can_bypass ? ins_msg_decoder_op3_sel :
                        entries[deq_ptr[p_entry_bits-1:0]].decoder_op3_sel;

      // Lookup entry in rename table to see if src operands ready, set register
      // file read addresses to get the data
      assign rt_lookup_en[0]   = can_bypass | !empty;
      assign rt_lookup_en[1]   = (can_bypass | !empty);
      assign rt_lookup_preg[0] = can_bypass ? ins_msg_preg[0] : entries[deq_ptr[p_entry_bits-1:0]].preg0;
      assign rt_lookup_preg[1] = can_bypass ? ins_msg_preg[1] : entries[deq_ptr[p_entry_bits-1:0]].preg1;
      assign rf_raddr[0]       = rt_lookup_preg[0];
      assign rf_raddr[1]       = rt_lookup_preg[1];

      // Can deq if not empty or can bypass, and both src regs are ready (either
      // ready as indicated in rename table or just completed on this cycle)
      logic both_src_ready;
      assign both_src_ready = ( !rt_lookup_pending[0] ) & ( !rt_lookup_pending[1] );
      assign deq_rdy = ( !empty | (can_bypass & ins_en) ) & both_src_ready;

      // Output deq fields
      always_comb begin
        Ex.op1                = rf_rdata[0];
        if( can_bypass ) begin
          Ex.pc               = ins_msg_pc;
          Ex.op2              = op2_sel ? ins_msg_imm : rf_rdata[1];
          Ex.uop              = ins_msg_decoder_uop;
          Ex.waddr            = ins_msg_decoder_waddr;
          Ex.seq_num          = ins_msg_seq_num;
          Ex.preg             = ins_msg_alloc_preg;
          Ex.ppreg            = ins_msg_alloc_ppreg;
          if (op3_sel)
            Ex.op3.branch_imm = ins_msg_imm;
          else
            Ex.op3.mem_data   = rf_rdata[1];
        end else begin
          Ex.pc               = entries[deq_ptr[p_entry_bits-1:0]].pc;
          Ex.op2              = entries[deq_ptr[p_entry_bits-1:0]].decoder_op2_sel ? 
                                  entries[deq_ptr[p_entry_bits-1:0]].imm : rf_rdata[1];
          Ex.uop              = entries[deq_ptr[p_entry_bits-1:0]].decoder_uop;
          Ex.waddr            = entries[deq_ptr[p_entry_bits-1:0]].decoder_waddr;
          Ex.seq_num          = entries[deq_ptr[p_entry_bits-1:0]].seq_num;
          Ex.preg             = entries[deq_ptr[p_entry_bits-1:0]].alloc_preg;
          Ex.ppreg            = entries[deq_ptr[p_entry_bits-1:0]].alloc_ppreg;
          if (op3_sel)
            Ex.op3.branch_imm = entries[deq_ptr[p_entry_bits-1:0]].imm;
          else
            Ex.op3.mem_data   = rf_rdata[1];
        end
      end

      // Update deq_ptr
      always_ff @( posedge clk ) begin
        if( rst )
          deq_ptr <= '0;
        else if( deq_en & deq_rdy & !bypass )
          deq_ptr <= deq_ptr + 1;
      end
    end else begin

      // Insert outputs
      assign avail_slots = '1;

      // Dequeue outputs
      assign Ex.pc               = ins_msg_pc;
      assign Ex.op1              = rf_rdata[0];
      assign Ex.op2              = ins_msg_decoder_op2_sel ? 
                                    ins_msg_imm : rf_rdata[1];
      assign Ex.uop              = ins_msg_decoder_uop;
      assign Ex.waddr            = ins_msg_decoder_waddr;
      assign Ex.seq_num          = ins_msg_seq_num;
      assign Ex.preg             = ins_msg_alloc_preg;
      assign Ex.ppreg            = ins_msg_alloc_ppreg;
      always_comb begin
        if (ins_msg_decoder_op3_sel)
          Ex.op3.branch_imm = ins_msg_imm;
        else
          Ex.op3.mem_data   = rf_rdata[1];
      end

      // Lookup entry in rename table to see if src operands ready, set register
      // file read addresses to get the data
      assign rt_lookup_en[0]   = ins_en;
      assign rt_lookup_en[1]   = ins_en;
      assign rt_lookup_preg[0] = ins_msg_preg[0];
      assign rt_lookup_preg[1] = ins_msg_preg[1];
      assign rf_raddr[0]       = rt_lookup_preg[0];
      assign rf_raddr[1]       = rt_lookup_preg[1];

      assign Ex.val  = ins_en;
      assign ins_rdy = Ex.rdy;
    end
  endgenerate

  

endmodule

`endif // HW_DECODE_ISSUEQUEUEINORDER_V
