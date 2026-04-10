//========================================================================
// SSSeqAge.v
//========================================================================
// A module for monitoring the in-flight instructions, to compare ages between
// sequence numbers. Determines the oldest instruction on the commit interface
// when updating

`ifndef HW_UTIL_SSSEQAGE_V
`define HW_UTIL_SSSEQAGE_V

`include "intf/CommitNotif.v"

module SSSeqAge #(
  parameter p_num_be_lanes   = 2,
  parameter p_seq_num_bits   = 5, 
  parameter p_num_phys_regs  = 36,
  parameter p_phys_addr_bits = $clog2(p_num_phys_regs)
) (
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // Oldest sequence number
  //----------------------------------------------------------------------

  output logic [p_seq_num_bits-1:0] oldest_seq_num,

  //----------------------------------------------------------------------
  // Commit Interface
  //----------------------------------------------------------------------

  CommitNotif.sub commit [p_num_be_lanes]
);

  logic                 [31:0] commit_pc      [p_num_be_lanes-1:0];
  logic   [p_seq_num_bits-1:0] commit_seq_num [p_num_be_lanes-1:0];
  logic                  [4:0] commit_waddr   [p_num_be_lanes-1:0];
  logic                 [31:0] commit_wdata   [p_num_be_lanes-1:0];
  logic                        commit_wen     [p_num_be_lanes-1:0];
  logic [p_phys_addr_bits-1:0] commit_ppreg   [p_num_be_lanes-1:0];
  logic                        commit_val     [p_num_be_lanes-1:0];
  logic [p_num_be_lanes-1:0]   commit_val_packed;

  genvar i;
  for( i = 0; i < p_num_be_lanes; i = i + 1 ) begin: UNPACK_FROM_INTF
    assign commit_pc[i]         = commit[i].pc;
    assign commit_seq_num[i]    = commit[i].seq_num;
    assign commit_waddr[i]      = commit[i].waddr;
    assign commit_wdata[i]      = commit[i].wdata;
    assign commit_wen[i]        = commit[i].wen;
    assign commit_ppreg[i]      = commit[i].ppreg;
    assign commit_val[i]        = commit[i].val;
    assign commit_val_packed[i] = commit[i].val;
  end

  // Keep track of the oldest in-flight sequence number
  logic [p_seq_num_bits-1:0] youngest_commit_seq_num;
  logic                      any_commit;
  assign any_commit = |commit_val_packed;

  always_ff @( posedge clk ) begin
    if( rst )
      oldest_seq_num <= '0;
    else if( any_commit )
      oldest_seq_num <= youngest_commit_seq_num + 1;
  end

  // Find youngest sequence number among commits, which will be the next oldest
  // after these commit (plus one)
  always_comb begin
    youngest_commit_seq_num = oldest_seq_num;
    for( int j = 1; j < p_num_be_lanes; j++ ) begin
      // if( commit_val[j] && is_older(youngest_commit_seq_num, commit_seq_num[j]) )
      if( commit_val[j] && (youngest_commit_seq_num < commit_seq_num[j] ^ (youngest_commit_seq_num < oldest_seq_num) ^ (commit_seq_num[j] < oldest_seq_num) ) )
        youngest_commit_seq_num = commit_seq_num[j];
    end
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

  logic [31:0] unused_commit_pc    [p_num_be_lanes];
  logic  [4:0] unused_commit_waddr [p_num_be_lanes];
  logic [31:0] unused_commit_wdata [p_num_be_lanes];
  logic        unused_commit_wen   [p_num_be_lanes];
  logic        unused_commit_val   [p_num_be_lanes];

  for( i = 0; i < p_num_be_lanes; i++ ) begin
    assign unused_commit_pc[i]    = commit[i].pc;
    assign unused_commit_waddr[i] = commit[i].waddr;
    assign unused_commit_wdata[i] = commit[i].wdata;
    assign unused_commit_wen[i]   = commit[i].wen;
    assign unused_commit_val[i]   = commit[i].val;
  end

endmodule

`endif // HW_UTIL_SEQAGE_V
