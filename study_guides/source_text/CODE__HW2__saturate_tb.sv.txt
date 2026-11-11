`timescale 1ns/1ps

module saturate_tb();

reg [15:0] unsigned_err;
wire [9:0] unsigned_err_sat;
reg signed [15:0] signed_err;
wire signed [9:0] signed_err_sat;
reg signed [9:0] signed_D_diff;
wire signed [6:0] signed_D_diff_sat;

integer i;
integer expected;

/////// Instantiate DUT /////////
saturate iDUT(.unsigned_err(unsigned_err), .unsigned_err_sat(unsigned_err_sat),
              .signed_err(signed_err), .signed_err_sat(signed_err_sat),
              .signed_D_diff(signed_D_diff), .signed_D_diff_sat(signed_D_diff_sat));

initial begin
  unsigned_err = 0;
  signed_err = 0;
  signed_D_diff = 0;

  // try every unsigned input
  for (i = 0; i < 65536; i = i + 1) begin
    unsigned_err = i;
    if (i > 1023)
      expected = 1023;
    else
      expected = i;
    #1; // allow output to settle
    if (unsigned_err_sat !== expected[9:0]) begin
      $display("ERROR: unsigned_err=%0d: got %0d, expected %0d",
               unsigned_err, unsigned_err_sat, expected);
      $stop();
    end
  end

  // try every signed error
  for (i = -32768; i < 32768; i = i + 1) begin
    signed_err = i;
    if (i > 511)
      expected = 511;
    else if (i < -512)
      expected = -512;
    else
      expected = i;
    #1;
    if (signed_err_sat !== expected[9:0]) begin
      $display("ERROR: signed_err=%0d: got %0d, expected %0d",
               signed_err, signed_err_sat, expected);
      $stop();
    end
  end

  // try every derivative input
  for (i = -512; i < 512; i = i + 1) begin
    signed_D_diff = i;
    if (i > 63)
      expected = 63;
    else if (i < -64)
      expected = -64;
    else
      expected = i;
    #1;
    if (signed_D_diff_sat !== expected[6:0]) begin
      $display("ERROR: signed_D_diff=%0d: got %0d, expected %0d",
               signed_D_diff, signed_D_diff_sat, expected);
      $stop();
    end
  end

  $display("tests passed!");
  $finish();
end

endmodule
