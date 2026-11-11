module up_dwn_cnt4(clk, rst_n, en, dwn, cnt);

input clk, rst_n, en, dwn;
output reg [3:0] cnt;

// The supplied wrapper controls direction at the upper and lower limits.
// wrapper controls dir at up and low limit
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    cnt <= 4'd0;
  else if (en) begin
    if (dwn)
      cnt <= cnt - 4'd1;
    else
      cnt <= cnt + 4'd1;
  end

endmodule
