`include "hw/common/MRRArb.v"

module tb_mrrarb;

  localparam int P_WIDTH = 4;
  localparam int P_MAX_M = 4;
  localparam int MW      = $clog2(P_MAX_M);

  logic                  clk;
  logic                  rst;
  logic                  en;
  logic [MW-1:0]          m;
  logic [P_WIDTH-1:0]     req;
  logic [P_WIDTH-1:0]     gnt;

  // DUT
  MRRArb #(
    .p_width(P_WIDTH),
    .p_max_m(P_MAX_M)
  ) dut (
    .clk(clk),
    .rst(rst),
    .en(en),
    .m(m),
    .req(req),
    .gnt(gnt)
  );

  // Clock
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Waves (portable VCD)
  initial begin
    $dumpfile("tb_mrrarb.vcd");
    $dumpvars(0, dut);
  end

  task automatic show(string tag);
    $display("[%0t] %s  rst=%0b en=%0b m=%0d  req=%b  gnt=%b  head_ptr=%b  next_head_ptr=%b",
             $time, tag, rst, en, m, req, gnt, dut.head_ptr, dut.next_head_ptr);
  endtask

  task automatic step(input logic [MW-1:0] m_i, input logic [P_WIDTH-1:0] req_i, string tag);
    begin
      m   = m_i;
      req = req_i;
      @(negedge clk); // setup before posedge
      show({tag, " (pre)"});
      @(posedge clk); // state updates here
      #1;
      show({tag, " (post)"});
    end
  endtask

  initial begin
    // init
    rst = 1'b1;
    en  = 1'b1;
    m   = '0;
    req = '0;

    // reset for a couple cycles
    repeat (2) @(posedge clk);
    #1; show("after reset cycles");
    rst = 1'b0;

    // ----------------------------
    // Basic directed scenarios
    // ----------------------------

    // Single requester
    step(1, 4'b0001, "single req bit0");
    step(1, 4'b0001, "single req bit0 (again)");
    step(1, 4'b1000, "single req bit3");

    // Multiple requesters, m=1 (classic RR behavior)
    step(1, 4'b1111, "all req, m=1");
    step(1, 4'b1111, "all req, m=1");
    step(1, 4'b1111, "all req, m=1");
    step(1, 4'b1111, "all req, m=1");

    // Multiple requesters, m=2
    step(2, 4'b1111, "all req, m=2");
    step(2, 4'b1111, "all req, m=2");
    step(2, 4'b1111, "all req, m=2");

    // Sparse req patterns, m=2
    step(2, 4'b1010, "req=1010, m=2");
    step(2, 4'b1010, "req=1010, m=2 (again)");
    step(2, 4'b0101, "req=0101, m=2");

    // m=0 edge case (should grant nothing, pointer should recycle)
    step(0, 4'b1111, "m=0, req=1111");
    step(0, 4'b0110, "m=0, req=0110");

    // Change m dynamically
    step(1, 4'b1111, "m=1, all req");
    step(3, 4'b1111, "m=3, all req");
    step(2, 4'b1111, "m=2, all req");
    step(1, 4'b1111, "m=1, all req");

    // ----------------------------
    // Small sweep (optional): all req patterns for a fixed m
    // ----------------------------
    m = 2;
    for (int rv = 0; rv < (1<<P_WIDTH); rv++) begin
      step(2, rv[P_WIDTH-1:0], $sformatf("sweep m=2 req=0x%0h", rv));
    end

    $display("\nDone.");
    $finish;
  end

endmodule
