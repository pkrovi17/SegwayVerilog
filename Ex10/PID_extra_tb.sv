`timescale 1ns/1ps

module PID_extra_tb();

reg clk, rst_n, vld, pwr_up, rider_off;
reg signed [15:0] ptch, ptch_rt;
wire signed [11:0] PID_cntrl;
wire [7:0] ss_tmr;
integer expected_int, expected_timer, error_value, next_int;
integer integral_value, rate_value, expected_pid, tests;

PID iDUT(.clk(clk), .rst_n(rst_n), .vld(vld), .ptch(ptch), .ptch_rt(ptch_rt),
          .pwr_up(pwr_up), .rider_off(rider_off), .PID_cntrl(PID_cntrl), .ss_tmr(ss_tmr));

initial clk = 0;
always #10 clk = ~clk;

// Integer reference checks both the internal state and final outputs.
task check_cycle;
  begin
    error_value = ptch;
    if (error_value > 511)
      error_value = 511;
    else if (error_value < -512)
      error_value = -512;
    next_int = expected_int + error_value;
    if (rider_off)
      expected_int = 0;
    else if (vld && (next_int >= -131072) && (next_int <= 131071))
      expected_int = next_int;

    if (!pwr_up)
      expected_timer = 0;
    else if (expected_timer < 133693440)
      expected_timer = expected_timer + 1;

    integral_value = expected_int;
    rate_value = ptch_rt;
    // Match arithmetic right-shift rounding for negative fractions.
    if (integral_value < 0)
      integral_value = integral_value - 63;
    if (rate_value < 0)
      rate_value = rate_value - 63;
    expected_pid = 9 * error_value + integral_value / 64 - rate_value / 64;
    if (expected_pid > 2047)
      expected_pid = 2047;
    else if (expected_pid < -2048)
      expected_pid = -2048;

    @(posedge clk); #1;
    if ((iDUT.integrator !== expected_int[17:0]) ||
        (iDUT.long_tmr !== expected_timer[26:0]) ||
        (ss_tmr !== expected_timer[26:19]) || (PID_cntrl !== expected_pid[11:0])) begin
      $display("ERROR: check %0d: integrator=%0d expected=%0d timer=%0d expected=%0d",
               tests, iDUT.integrator, expected_int, iDUT.long_tmr, expected_timer);
      $display("PID=%0d expected=%0d ss_tmr=%h", PID_cntrl, expected_pid, ss_tmr);
      $stop();
    end
    tests = tests + 1;
    @(negedge clk); #1;
  end
endtask

initial begin
  tests = 0;
  expected_int = 0;
  expected_timer = 0;
  rst_n = 1;
  vld = 0;
  pwr_up = 0;
  rider_off = 0;
  ptch = 0;
  ptch_rt = 0;
  #2; rst_n = 0;
  #1;
  if ((iDUT.integrator !== 18'd0) || (iDUT.long_tmr !== 27'd0)) begin
    $display("ERROR: asynchronous reset failed");
    $stop();
  end
  @(negedge clk); #1; rst_n = 1;
  check_cycle;

  ptch = 2; check_cycle; // P term remains active even with vld low.
  vld = 1;
  ptch = 32767;
  repeat (260) check_cycle; // Saturated pitch, positive integrator overflow.
  ptch = -1; check_cycle; // Integrator must recover when error reverses.
  vld = 0;
  ptch = 100;
  repeat (3) check_cycle; // Hold with no valid input.
  rider_off = 1; check_cycle; // Clear even with vld low.
  rider_off = 0;
  vld = 1;
  ptch = -32768;
  repeat (260) check_cycle; // Negative overflow must hold, not wrap.
  ptch = 1; check_cycle;
  rider_off = 1; check_cycle; // Clear takes priority over valid input.
  rider_off = 0;
  vld = 0;
  ptch = 0;
  ptch_rt = -1; check_cycle;
  ptch_rt = -32768; check_cycle;
  ptch_rt = 32767; check_cycle;

  pwr_up = 1;
  repeat (3) check_cycle;
  // Seed the timer near boundaries to avoid simulating 134 million clocks.
  // These assignments are testbench-only; the DUT always counts by one.
  iDUT.long_tmr = 27'd524287;
  expected_timer = 524287;
  check_cycle; // Upper byte changes from 0 to 1.
  iDUT.long_tmr = 27'd133693439;
  expected_timer = 133693439;
  repeat (4) check_cycle; // Reach 0xFF, then hold the entire timer.
  pwr_up = 0; check_cycle; // Power off resets the timer.
  pwr_up = 1; check_cycle; // Power on starts a fresh ramp.

  // Reset active state without waiting for a clock edge.
  vld = 1;
  ptch = 100;
  check_cycle;
  #2; rst_n = 0;
  #1;
  if ((iDUT.integrator !== 18'd0) || (iDUT.long_tmr !== 27'd0) || (ss_tmr !== 8'd0)) begin
    $display("ERROR: reset failed while running");
    $stop();
  end
  $display("Pranav Krovi: all %0d additional PID checks passed!", tests);
  $finish();
end

endmodule
