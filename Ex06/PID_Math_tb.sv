`timescale 1ns/1ps

module PID_Math_tb();

reg signed [15:0] ptch, ptch_rt;
reg signed [17:0] integrator;
wire signed [11:0] PID_cntrl;

integer i;
integer pitch_value, rate_value, integral_value;
integer expected;

/////// Instantiate DUT /////////
PID_Math iDUT(.ptch(ptch), .ptch_rt(ptch_rt),
              .integrator(integrator), .PID_cntrl(PID_cntrl));

initial begin

  for (i = 0; i < 524; i = i + 1) begin
    if (i < 512) begin
      ptch = -256 + i;

      // 4 ramp segments between -16384 and 16383
      if ((i / 128) % 2 == 0)
        integrator = -16384 + (i % 128) * 32767 / 127;
      else
        integrator = 16383 - (i % 128) * 32767 / 127;

      // 8 ramp segments between -4096 and 4095
      if ((i / 64) % 2 == 0)
        ptch_rt = 4095 - (i % 64) * 8191 / 63;
      else
        ptch_rt = -4096 + (i % 64) * 8191 / 63;
    end else begin
      ptch = 0;
      ptch_rt = 0;
      integrator = 0;
      case (i)
        512: ptch = 0;
        513: ptch = 32767;
        514: ptch = -32768;
        // combine terms to get saturation
        515: begin ptch = 512; integrator = -131072; ptch_rt = 32767; end
        516: begin ptch = -513; integrator = 131071; ptch_rt = -32768; end
        517: integrator = 131071;
        518: integrator = -131072;
        519: ptch_rt = 32767;
        520: ptch_rt = -32768;
        521: integrator = -1;
        522: ptch_rt = -1;
        523: begin ptch = -1; integrator = 63; ptch_rt = 63; end
      endcase
    end

    // caluclation of expected value
    pitch_value = ptch;
    if (pitch_value > 511)
      pitch_value = 511;
    else if (pitch_value < -512)
      pitch_value = -512;

    integral_value = integrator;
    rate_value = ptch_rt;
    // Drop 6 low bits
    if (integral_value < 0)
      integral_value = integral_value - 63;
    if (rate_value < 0)
      rate_value = rate_value - 63;
    expected = pitch_value * 9 + integral_value / 64 - rate_value / 64;
    if (expected > 2047)
      expected = 2047;
    else if (expected < -2048)
      expected = -2048;

    #10;
    // Cchecking pitch saturation
    if (iDUT.ptch_err_sat !== pitch_value[9:0]) begin
      $display("ERROR: ptch=%0d: saturated pitch=%0d, expected %0d",
               ptch, iDUT.ptch_err_sat, pitch_value);
      $stop();
    end
    if (PID_cntrl !== expected[11:0]) begin
      $display("ERROR: ptch=%0d integrator=%0d ptch_rt=%0d: got %0d, expected %0d",
               ptch, integrator, ptch_rt, PID_cntrl, expected);
      $stop();
    end
  end

  $display("All 524 tests passed!");
  $finish();
end

endmodule
