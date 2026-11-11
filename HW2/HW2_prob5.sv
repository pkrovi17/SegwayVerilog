// 1. The latch code is not correct. The always @(clk) statement only runs
// when clk changes. The latch must follow changes in d when the clk is high
// in addition to the clk changes. To fix, we huse @(*) with if (clk) q<= d.
// (or always_latch) so that changes in both inputs are considered when evaluating.

// 2. D flip-flop with active high synchronous reset
module dff_sync_reset(d, clk, rst, q);

input d, clk, rst;
output reg q;

always_ff @(posedge clk)
  if (rst)
    q <= 1'b0;
  else
    q <= d;

endmodule

// 3. D flip-flop, active low asynchronous reset + active high enable.
module dff_async_reset_enable(d, clk, rst_n, en, q);

input d, clk, rst_n, en;
output reg q;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    q <= 1'b0;
  else if (en)
    q <= d;
// otherwise hold q reset is priority.

endmodule

// 4. SR flip-flop, active high synchronous S, R, and active low asynchronous reset rst_n.
module sr_ff(S, R, clk, rst_n, q);

input S, R, clk, rst_n;
output reg q;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    q <= 1'b0;
  else if (R)
    q <= 1'b0;
  else if (S)
    q <= 1'b1;
// otherwise hold q, R is winning when S and R are both high.

endmodule

// 5. No, always_ff does not guarantee that a flip-flop is inferred.
// It describes code in sequence and limits processes inside to one event
// control. It has no more blocking timing controls. Variables here
// cannot be written by other processes.
// The event control and assignments still describe a flip-flop. We can do this
// by using a clock edge, optional reset edges, and nonblocking
// assignments. always_ff does not insert a clock edge automaticaally.
// Synthesis programs can flag bad uses, and can optimize
// unused or constant states instead of producing a flip-flop.
