module PB_release(clk, rst_n, PB, released);

input clk, rst_n, PB;
output released;
reg PB_meta, PB_sync, PB_prev;

// 2 flops to synchronize; extra to store prev value
// starts in released state
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) begin
    PB_meta <= 1'b1;
    PB_sync <= 1'b1;
    PB_prev <= 1'b1;
  end else begin
    PB_meta <= PB;
    PB_sync <= PB_meta;
    PB_prev <= PB_sync;
  end

assign released = PB_sync & ~PB_prev;

endmodule
