//========================================================================
// SeqAge.v
//========================================================================
// A module for monitoring the in-flight instructions, to compare ages
// between sequence numbers

`ifndef HW_UTIL_SEQAGE_V
`define HW_UTIL_SEQAGE_V

`include "intf/CommitNotif.v"

module SeqAge #(
  parameter p_seq_num_bits = 5
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Commit Interface
  //----------------------------------------------------------------------

  CommitNotif.sub commit
);

  // Keep track of the oldest in-flight sequence number
  logic [p_seq_num_bits-1:0] oldest_seq_num;

  always_ff @( posedge clk ) begin
    if( rst )
      oldest_seq_num <= '0;
    else if( commit.val )
      oldest_seq_num <= commit.seq_num + 1;
  end

  //----------------------------------------------------------------------
  // is_older
  //----------------------------------------------------------------------
  // Evaluates whether seq_num_0 is older than seq_num_1
  //
  // Inspiration: SonicBoom
  // https://github.com/riscv-boom/riscv-boom/blob/7184be9db9d48bd01689cf9dd429a4ac32b21105/src/main/scala/v3/util/util.scala#L363
  //
  // if (
  //   seq_num_0 < oldest_seq_num &
  //   seq_num_1 < oldest_seq_num
  // )
  //   // Both less than oldest number - compare directly
  //   return ( seq_num_0 < seq_num_1 );
  //
  // else if (
  //   !( seq_num_0 < oldest_seq_num ) &
  //   !( seq_num_1 < oldest_seq_num )
  // )
  //   // Both greater than oldest number - compare directly
  //   return ( seq_num_0 < seq_num_1 );
  //
  // else
  //   // Oldest number is in-between -> wraparound
  //   return !( seq_num_0 < seq_num_1 );

  function automatic logic is_older(
    input [p_seq_num_bits-1:0] seq_num_0,
    input [p_seq_num_bits-1:0] seq_num_1
  );
    return ( seq_num_0 < seq_num_1      ) ^ 
           ( seq_num_0 < oldest_seq_num ) ^
           ( seq_num_1 < oldest_seq_num );
  endfunction

  //----------------------------------------------------------------------
  // Unused signals
  //----------------------------------------------------------------------
  // Include those that are used by SeqAge

  logic [31:0] unused_commit_pc;
  logic  [4:0] unused_commit_waddr;
  logic [31:0] unused_commit_wdata;
  logic        unused_commit_wen;
  logic        unused_commit_val;

  assign unused_commit_pc    = commit.pc;
  assign unused_commit_waddr = commit.waddr;
  assign unused_commit_wdata = commit.wdata;
  assign unused_commit_wen   = commit.wen;
  assign unused_commit_val   = commit.val;

endmodule

`endif // HW_UTIL_SEQAGE_V
