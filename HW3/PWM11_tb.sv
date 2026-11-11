`timescale 1ns/1ps

module PWM11_tb();

reg clk, rst_n;
reg [10:0] duty;
wire PWM1, PWM2, PWM_synch, ovr_I_blank;
integer test, cycle, count, high1, high2, expected_high1, expected_high2;
reg expected1, expected2, expected_blank;

PWM11 iDUT(.clk(clk), .rst_n(rst_n), .duty(duty), .PWM1(PWM1),
            .PWM2(PWM2), .PWM_synch(PWM_synch), .ovr_I_blank(ovr_I_blank));

initial clk = 0;
always #10 clk = ~clk; // 50 MHz

initial begin
  $dumpfile("PWM11.vcd");
  $dumpvars(0, PWM11_tb);
  rst_n = 1;
  duty = 0;
  #2; rst_n = 0;
  #1;
  if ({PWM1, PWM2, PWM_synch, ovr_I_blank} !== 4'b0010) begin
    $display("ERROR: incorrect asynchronous reset");
    $stop();
  end
  @(negedge clk);
  rst_n = 1;

  // 2 full periods for every duty
  for (test = 0; test < 11; test = test + 1) begin
    case (test)
      0: duty = 11'h000;
      1: duty = 11'h001;
      2: duty = 11'h03f;
      3: duty = 11'h040;
      4: duty = 11'h041;
      5: duty = 11'h200;
      6: duty = 11'h400;
      7: duty = 11'h600;
      8: duty = 11'h7bf;
      9: duty = 11'h7c0;
      10: duty = 11'h7ff;
    endcase
    // start at falling edge with cnt=0
    high1 = 0;
    high2 = 0;
    for (cycle = 0; cycle < 4096; cycle = cycle + 1) begin
      count = cycle % 2048;
      expected1 = (count >= 64) && (count < duty);
      expected2 = (count >= duty + 64) && (count < 2047);
      @(posedge clk);
      #1;
      count = (count + 1) % 2048;
      expected_blank = ((count > 64) && (count < 192)) ||
                        ((count > duty + 64) && (count < duty + 192));
      if ((PWM1 !== expected1) || (PWM2 !== expected2) ||
          (PWM_synch !== (count == 0)) || (ovr_I_blank !== expected_blank)) begin
        $display("ERROR: duty=%h cycle=%0d: PWM1=%b PWM2=%b synch=%b blank=%b",
                  duty, cycle, PWM1, PWM2, PWM_synch, ovr_I_blank);
        $stop();
      end
      if (PWM1 && PWM2) begin
        $display("ERROR: PWM outputs overlap");
        $stop();
      end
      high1 = high1 + PWM1;
      high2 = high2 + PWM2;
      @(negedge clk);
      #1;
      if ((PWM1 !== expected1) || (PWM2 !== expected2)) begin
        $display("ERROR: PWM output changed between rising edges");
        $stop();
      end
    end
    expected_high1 = 0;
    expected_high2 = 0;
    if (duty > 64)
      expected_high1 = 2 * (duty - 64);
    if (duty < 1983)
      expected_high2 = 2 * (1983 - duty);
    if ((high1 != expected_high1) || (high2 != expected_high2)) begin
      $display("ERROR: incorrect pulse widths for duty=%h", duty);
      $stop();
    end
    $display("PASS: duty=0x%h, high clocks/period: PWM1=%0d PWM2=%0d",
             duty, high1 / 2, high2 / 2);
  end

  // assert reset in middle, away from clock edge
  repeat (100) @(posedge clk);
  #3; rst_n = 0;
  #1;
  if ({PWM1, PWM2, PWM_synch, ovr_I_blank} !== 4'b0010) begin
    $display("ERROR: reset did not immediately clear active PWM");
    $stop();
  end
  $display("All 11 PWM duty tests passed (45056 clock checks)!");
  $finish();
end

endmodule
