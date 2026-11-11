`timescale 1ns/1ps

module steer_en_SM_extra_tb();
reg clk, rst_n, tmr_full, sum_gt_min, sum_lt_min, diff_gt_1_4, diff_gt_15_16;
wire clr_tmr, en_steer, rider_off;
integer tests;

steer_en_SM iDUT(.clk(clk), .rst_n(rst_n), .tmr_full(tmr_full),
  .sum_gt_min(sum_gt_min), .sum_lt_min(sum_lt_min), .diff_gt_1_4(diff_gt_1_4),
  .diff_gt_15_16(diff_gt_15_16), .clr_tmr(clr_tmr), .en_steer(en_steer), .rider_off(rider_off));

initial clk = 0;
always #10 clk = ~clk;

task check;
  input [1:0] expected_state;
  input [2:0] expected_outputs; // {clr_tmr, en_steer, rider_off}
  begin
    #1;
    if ((iDUT.state !== expected_state) ||
        ({clr_tmr, en_steer, rider_off} !== expected_outputs)) begin
      $display("ERROR: check %0d state=%b outputs=%b, expected %b %b",
        tests, iDUT.state, {clr_tmr,en_steer,rider_off}, expected_state, expected_outputs);
      $stop();
    end
    tests = tests + 1;
  end
endtask

initial begin
  tests = 0;
  rst_n = 1; tmr_full = 0; sum_gt_min = 0; sum_lt_min = 0;
  diff_gt_1_4 = 0; diff_gt_15_16 = 0;
  #2; rst_n = 0;
  check(0, 3'b101);
  @(negedge clk); rst_n = 1;
  @(posedge clk); check(0, 3'b101); // Hysteresis region cannot admit a rider.
  @(negedge clk); sum_gt_min = 1;
  @(posedge clk); check(1, 3'b000);
  @(negedge clk); sum_gt_min = 0;
  @(posedge clk); check(1, 3'b000); // But it can retain a known rider.
  @(negedge clk); diff_gt_1_4 = 1; tmr_full = 1;
  check(1, 3'b100);
  @(posedge clk); check(1, 3'b100); // Imbalance wins over timer expiration.
  @(negedge clk); diff_gt_1_4 = 0; tmr_full = 0;
  @(posedge clk); check(1, 3'b000);
  @(negedge clk); tmr_full = 1;
  @(posedge clk); check(2, 3'b010);
  @(negedge clk); diff_gt_1_4 = 1;
  @(posedge clk); check(2, 3'b010); // Mild imbalance does not disable steering.

  // The supplied testbench does not exercise a rider knocked off here.
  @(negedge clk); sum_lt_min = 1; diff_gt_15_16 = 1;
  check(2, 3'b101); // Immediately flag rider off and remove steering.
  @(posedge clk); check(0, 3'b101); // Knocked off wins over stepping off.
  @(negedge clk); sum_lt_min = 0; sum_gt_min = 1;
  diff_gt_1_4 = 0; diff_gt_15_16 = 0; tmr_full = 0;
  @(posedge clk); check(1, 3'b000);
  @(negedge clk); tmr_full = 1;
  @(posedge clk); check(2, 3'b010);
  @(negedge clk); diff_gt_15_16 = 1; diff_gt_1_4 = 1;
  check(2, 3'b100); // Stepping off clears timer, but rider is still on.
  @(posedge clk); check(1, 3'b100);
  @(negedge clk); tmr_full = 0; diff_gt_15_16 = 0; diff_gt_1_4 = 0;
  @(posedge clk); check(1, 3'b000); // Must wait again, not reuse old expiry.
  @(negedge clk); sum_lt_min = 1; sum_gt_min = 0;
  check(1, 3'b101);
  @(posedge clk); check(0, 3'b101);

  // Assert asynchronous reset while steering is enabled.
  @(negedge clk); sum_lt_min = 0; sum_gt_min = 1;
  @(posedge clk); check(1, 3'b000);
  @(negedge clk); tmr_full = 1;
  @(posedge clk); check(2, 3'b010);
  #2; rst_n = 0;
  check(0, 3'b101);
  $display("Pranav Krovi (pkrovi): all %0d additional steering checks passed!", tests);
  $finish();
end
endmodule
