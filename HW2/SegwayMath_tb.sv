`timescale 1ns/1ps

module SegwayMath_tb();

reg signed [11:0] PID_cntrl;
reg [7:0] ss_tmr;
reg [11:0] steer_pot;
reg en_steer, pwr_up;
wire signed [11:0] lft_spd, rght_spd;
wire too_fast;
integer i, tests;
integer base, steering, expected_lft, expected_rght;
reg expected_fast;

SegwayMath iDUT(.PID_cntrl(PID_cntrl), .ss_tmr(ss_tmr), .steer_pot(steer_pot),
                .en_steer(en_steer), .pwr_up(pwr_up),
                .lft_spd(lft_spd), .rght_spd(rght_spd), .too_fast(too_fast));

// outputs against expected values
task check_outputs;
  begin
    base = PID_cntrl;
    base = base * ss_tmr;
    // Mmatch low bits of the product to the sign bit, then divide by 256
    if (base < 0)
      base = base - 255;
    base = base / 256;

    steering = steer_pot;
    if (steering < 512)
      steering = 512;
    else if (steering > 3584)
      steering = 3584;
    steering = (steering - 2047) * 3;
    if (steering < 0)
      steering = steering - 15;
    steering = steering / 16;
    if (!en_steer)
      steering = 0;
    // compute expected left and right speeds, including dead-band shaping
    expected_lft = base + steering;
    expected_rght = base - steering;
    if ((expected_lft > -42) && (expected_lft < 42))
      expected_lft = expected_lft * 4;
    else if (expected_lft < 0)
      expected_lft = expected_lft - 168;
    else
      expected_lft = expected_lft + 168;
    if ((expected_rght > -42) && (expected_rght < 42))
      expected_rght = expected_rght * 4;
    else if (expected_rght < 0)
      expected_rght = expected_rght - 168;
    else
      expected_rght = expected_rght + 168;
    // if power is off, both speeds should be zero
    if (!pwr_up) begin
      expected_lft = 0;
      expected_rght = 0;
    end
    if (expected_lft > 2047)
      expected_lft = 2047;
    else if (expected_lft < -2048)
      expected_lft = -2048;
    if (expected_rght > 2047)
      expected_rght = 2047;
    else if (expected_rght < -2048)
      expected_rght = -2048;
    expected_fast = (expected_lft > 1536) || (expected_rght > 1536);
    // wait for outputs to settle, then check against expected values
    #10;
    if ((lft_spd !== expected_lft[11:0]) ||
        (rght_spd !== expected_rght[11:0]) || (too_fast !== expected_fast)) begin
      $display("ERROR: PID=%0d ss_tmr=%0d steer_pot=%0d en_steer=%b pwr_up=%b",
               PID_cntrl, ss_tmr, steer_pot, en_steer, pwr_up);
      $display("got left=%0d right=%0d too_fast=%b; expected %0d %0d %b",
               lft_spd, rght_spd, too_fast, expected_lft, expected_rght, expected_fast);
      $stop();
    end
    tests = tests + 1;
  end
endtask

initial begin
  tests = 0;
  // pdf test 1 soft start + followed by decreasing PID
  en_steer = 0;
  pwr_up = 1;
  steer_pot = 12'h7ff;
  PID_cntrl = 12'h5ff;
  for (i = 0; i < 256; i = i + 1) begin
    ss_tmr = i;
    check_outputs;
  end
  for (i = 1535; i >= -512; i = i - 1) begin
    PID_cntrl = i;
    check_outputs;
  end

  // pdf test 2 sweep steering while PID falls + turn power off.
  en_steer = 1;
  ss_tmr = 8'hff;
  for (i = 0; i < 2048; i = i + 1) begin
    PID_cntrl = 1023 - i;
    steer_pot = 2 * i;
    check_outputs;
  end
  pwr_up = 0;
  check_outputs;

  // extra check both steering limits over the full signed PID range
  // checking  saturation, dead-band edges, and speed warning
  pwr_up = 1;
  for (i = -2048; i < 2048; i = i + 1) begin
    PID_cntrl = i;
    steer_pot = 0;
    check_outputs;
    steer_pot = 4095;
    check_outputs;
  end

  $display("All %0d tests passed!", tests);
  $finish();
end

endmodule
