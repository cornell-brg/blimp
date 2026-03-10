//========================================================================
// DIUSquashPub.v
//========================================================================
// Squash publisher for the decode-issue unit.
//
// When the oldest control instruction is a JAL/JALR (not a branch),
// computes its jump target and publishes a registered squash
// notification.  Also exposes a combinational squash-valid signal for
// use as a same-cycle FIFO reset.

`ifndef HW_DECODEISSUE_DIUSQUASHPUB_V
`define HW_DECODEISSUE_DIUSQUASHPUB_V

`include "intf/SquashNotif.v"

module DIUSquashPub #(
  parameter type t_ctrl_info    = logic,
  parameter      p_seq_num_bits = 5
) (
  input logic clk,
  input logic rst,

  // Oldest control instruction info (bundled struct)
  input t_ctrl_info oldest_ctrl_inst,

  // Signals not in the struct (depend on external state)
  input logic [31:0] oldest_ctrl_inst_jump_base,
  input logic        oldest_ctrl_inst_dispatch_go,

  // Squash notification
  SquashNotif.pub squash_pub,

  // Combinational squash-valid for same-cycle use (e.g. FIFO reset)
  output logic squash_pub_val_comb
);

  //----------------------------------------------------------------------
  // Jump target computation
  //----------------------------------------------------------------------

  logic [31:0] jump_target;

  always_comb begin
    if( !oldest_ctrl_inst.is_brx ) begin
      case( oldest_ctrl_inst.jal )
        2'd1:    jump_target = oldest_ctrl_inst.pc
                              + oldest_ctrl_inst.imm;
        2'd2:    jump_target = (oldest_ctrl_inst_jump_base
                              + oldest_ctrl_inst.imm)
                              & 32'hFFFFFFFE;
        default: jump_target = '0;
      endcase
    end else begin
      jump_target = '0;
    end
  end

  //----------------------------------------------------------------------
  // Combinational squash valid
  //----------------------------------------------------------------------

  assign squash_pub_val_comb = oldest_ctrl_inst.found  &&
                               !oldest_ctrl_inst.is_brx &&
                               oldest_ctrl_inst_dispatch_go;

  //----------------------------------------------------------------------
  // Registered squash notification
  //----------------------------------------------------------------------

  always_ff @( posedge clk ) begin
    if( rst ) begin
      squash_pub.val     <= 1'b0;
      squash_pub.target  <= '0;
      squash_pub.seq_num <= '0;
    end else begin
      squash_pub.val     <= squash_pub_val_comb;
      squash_pub.target  <= jump_target;
      squash_pub.seq_num <= oldest_ctrl_inst.seq_num;
    end
  end

endmodule

`endif // HW_DECODEISSUE_DIUSQUASHPUB_V
