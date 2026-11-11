module rst_synch(RST_n, clk, rst_n);

input RST_n, clk;
output reg rst_n;
reg rst_ff;

// assert now, release after 2 neg edge
always_ff @(negedge clk or negedge RST_n)
  if (!RST_n) begin
    rst_ff <= 1'b0;
    rst_n <= 1'b0;
  end else begin
    rst_ff <= 1'b1;
    rst_n <= rst_ff;
  end

endmodule
